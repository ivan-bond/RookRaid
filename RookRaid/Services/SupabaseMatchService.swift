import Foundation
import Supabase

/// Fehler der Gegnersuche (Server-Meldungen aus `find_match` / `start_bot_match`).
enum MatchmakingError: Error, Equatable {
    case rulesOutdated
    case deckIncomplete
    case badTimeControl
    case noAccount
    case offline
    case server

    init(_ error: Error) {
        if let e = error as? MatchmakingError { self = e; return }
        let message = (error as? PostgrestError)?.message ?? error.localizedDescription
        switch message {
        case "rules_outdated": self = .rulesOutdated
        case "deck_incomplete", "unknown_card", "unknown_ultimate": self = .deckIncomplete
        case "bad_time_control": self = .badTimeControl
        case "no_account": self = .noAccount
        default: self = (error as? URLError) != nil ? .offline : .server
        }
    }

    var message: String {
        switch self {
        case .rulesOutdated: return L("Bitte aktualisiere Rook Raid, um online zu spielen.")
        case .deckIncomplete: return L("Dein Deck braucht 4 verschiedene Karten.")
        case .badTimeControl: return L("Online gilt nur 5 | 0.")
        case .noAccount: return L("Zuerst brauchst du ein Online-Konto.")
        case .offline: return L("Keine Verbindung zum Server.")
        case .server: return L("Der Server hat nicht geantwortet. Bitte versuche es später noch einmal.")
        }
    }
}

/// Gegnersuche gegen den Server (Anleitung Schritt 8): alle 2 s `find_match`, nach 10 s Bot-Ersatz.
final class SupabaseMatchService: MatchService {
    private let client: SupabaseClient
    private var cancelled = false
    init(client: SupabaseClient) { self.client = client }

    func findMatch(_ request: MatchRequest) async throws -> MatchFound {
        cancelled = false
        struct Find: Encodable {
            let p_rules_version: Int
            let p_time_control: String
            let p_deck: [String]
            let p_ultimate: String
            let p_card: PlayerCard
        }
        let params = Find(p_rules_version: request.rulesVersion, p_time_control: request.timeControl,
                          p_deck: request.deck, p_ultimate: request.ultimate, p_card: request.player)
        let start = Date()
        do {
            while Date().timeIntervalSince(start) < OnlineConfig.matchmakingTimeout {
                try Task.checkCancellation()
                if cancelled { throw CancellationError() }
                let id: UUID? = try await client.rpc(OnlineConfig.Endpoint.findMatch, params: params).execute().value
                if let id { return try await humanMatch(id) }
                try await Task.sleep(nanoseconds: UInt64(OnlineConfig.matchmakingPoll * 1_000_000_000))
            }
            return try await botMatch(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MatchmakingError(error)
        }
    }

    func cancel() {
        cancelled = true
        Task { try? await client.rpc(OnlineConfig.Endpoint.cancelMatchmaking).execute() }
    }

    private func humanMatch(_ id: UUID) async throws -> MatchFound {
        struct Row: Decodable {
            let white: UUID?
            let black: UUID?
            let whiteCard: PlayerCard
            let blackCard: PlayerCard
            enum CodingKeys: String, CodingKey {
                case white, black
                case whiteCard = "white_card", blackCard = "black_card"
            }
        }
        let row: Row = try await client.from("matches").select("white,black,white_card,black_card")
            .eq("id", value: id).single().execute().value
        let uid = client.auth.currentUser?.id
        let youAreWhite = row.white == uid
        let opponent = youAreWhite ? row.blackCard : row.whiteCard
        return MatchFound(kind: .human, opponent: opponent, botLevel: nil, youAreWhite: youAreWhite, matchId: id)
    }

    private func botMatch(_ request: MatchRequest) async throws -> MatchFound {
        let trophies = request.player.trophies
        let level = BotLevel.forTrophies(trophies)
        let botCard = BotCards.card(for: level, near: trophies)
        let humanWhite = Bool.random()
        struct Start: Encodable {
            let p_rules_version: Int
            let p_time_control: String
            let p_deck: [String]
            let p_ultimate: String
            let p_card: PlayerCard
            let p_bot_card: PlayerCard
            let p_bot_deck: [String]
            let p_bot_ultimate: String
            let p_human_white: Bool
        }
        struct Reply: Decodable {
            let matchId: UUID
            let isBot: Bool
            let botLevel: String?
            let humanWhite: Bool
            enum CodingKeys: String, CodingKey {
                case matchId = "match_id", isBot = "is_bot", botLevel = "bot_level", humanWhite = "human_white"
            }
        }
        let params = Start(p_rules_version: request.rulesVersion, p_time_control: request.timeControl,
                           p_deck: request.deck, p_ultimate: request.ultimate, p_card: request.player,
                           p_bot_card: botCard, p_bot_deck: level.deck.map(\.rawValue),
                           p_bot_ultimate: level.ultimate.rawValue, p_human_white: humanWhite)
        let rows: [Reply] = try await client.rpc(OnlineConfig.Endpoint.startBotMatch, params: params).execute().value
        guard let reply = rows.first else { throw MatchmakingError.server }
        if !reply.isBot {
            return try await humanMatch(reply.matchId)
        }
        let resolved = reply.botLevel.flatMap(BotLevel.init(rawValue:)) ?? level
        return MatchFound(kind: .bot, opponent: botCard, botLevel: resolved,
                          youAreWhite: reply.humanWhite, matchId: reply.matchId)
    }
}

/// Bot-Ersatz-Partie am Ende an den Server melden (Edge Function `finish-bot-match`).
final class SupabaseBotMatchReporter: BotMatchReporter {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    func finish(matchId: UUID, actions: [String], outcome: BotMatchOutcome, humanIsWhite: Bool) async throws -> Int {
        struct Body: Encodable { let match_id: UUID; let actions: [String]; let outcome: String }
        struct Reply: Decodable {
            let trophyDeltaWhite: Int?
            let trophyDeltaBlack: Int?
            enum CodingKeys: String, CodingKey {
                case trophyDeltaWhite = "trophy_delta_white"
                case trophyDeltaBlack = "trophy_delta_black"
            }
        }
        let reply: Reply = try await client.functions.invoke(
            OnlineConfig.Endpoint.finishBotMatch,
            options: .init(body: Body(match_id: matchId, actions: actions, outcome: outcome.rawValue))
        )
        // Die Farbe steht schon fest. Ein zweites Lesen der Partie darf eine erfolgreiche Wertung nicht verwerfen.
        return humanIsWhite ? (reply.trophyDeltaWhite ?? 0) : (reply.trophyDeltaBlack ?? 0)
    }
}

/// Lebenszeichen: `match_heartbeat` gibt JSON zurück (`status`, `opponent_silent_s`).
enum OnlineHeartbeat {
    struct Snapshot {
        var status: String
        var opponentSilentSeconds: Int?
    }

    static func snapshot(client: SupabaseClient, matchId: UUID) async -> Snapshot? {
        struct Reply: Decodable {
            let status: String
            let opponentSilentS: Int?
            enum CodingKeys: String, CodingKey {
                case status
                case opponentSilentS = "opponent_silent_s"
            }
        }
        do {
            let response: PostgrestResponse<Void> = try await client.rpc(
                OnlineConfig.Endpoint.heartbeat, params: ["p_match": matchId]
            ).execute()
            let data = response.data
            if let r = try? JSONDecoder().decode(Reply.self, from: data) {
                return Snapshot(status: r.status, opponentSilentSeconds: r.opponentSilentS)
            }
            if let s = try? JSONDecoder().decode(String.self, from: data),
               let inner = s.data(using: .utf8),
               let r = try? JSONDecoder().decode(Reply.self, from: inner) {
                return Snapshot(status: r.status, opponentSilentSeconds: r.opponentSilentS)
            }
            return nil
        } catch {
            return nil
        }
    }
}

/// Offene Bot-Ersatz-Meldung, falls am Ende das Netz weg war – wird beim nächsten Start nachgereicht.
struct PendingBotReport: Codable {
    var matchId: UUID
    var actions: [String]
    var outcome: String
    /// Welche Farbe der Mensch gespielt hat. Ältere Meldungen ohne das Feld gelten als Weiß.
    var humanIsWhite: Bool?
    static let file = "pending_bot_report"
}

enum PendingBotReports {
    static func store(_ report: PendingBotReport) { Storage.saveNow(report, as: PendingBotReport.file) }
    static func load() -> PendingBotReport? { Storage.load(PendingBotReport.self, from: PendingBotReport.file) }
    static func clear() { Storage.delete(PendingBotReport.file) }

    static func retryIfNeeded() {
        guard let report = load(), let client = Backend.client else { return }
        Task { @MainActor in
            do {
                let outcome = BotMatchOutcome(rawValue: report.outcome) ?? .completed
                _ = try await SupabaseBotMatchReporter(client: client)
                    .finish(matchId: report.matchId, actions: report.actions, outcome: outcome,
                            humanIsWhite: report.humanIsWhite ?? true)
                await OnlineAccount.shared.reload()
                if let server = OnlineAccount.shared.progress {
                    let store = ProfileStore.shared
                    if server.trophies > store.profile.trophies { store.profile.trophies = server.trophies }
                    store.profile.bestTrophies = max(store.profile.bestTrophies, server.bestTrophies)
                }
                clear()
            } catch {
                // Partie war schon gewertet (45 s weg) oder Netz immer noch weg – beim nächsten Start nochmal
            }
        }
    }
}

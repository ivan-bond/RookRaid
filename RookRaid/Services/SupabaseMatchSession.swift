import Foundation
import Supabase

/// Partie vom Server laden (Start und Wiederverbinden).
enum OnlineMatches {
    struct FinishState {
        var status: String
        var result: String?
        var winner: PlayerColor?
        var myDelta: Int?
    }

    /// Laufende Partie gegen einen Menschen, falls dieses Konto gerade eine hat.
    static func activeHumanMatch(client: SupabaseClient) async -> UUID? {
        guard let uid = client.auth.currentUser?.id else { return nil }
        struct Row: Decodable {
            let id: UUID
            let isBot: Bool
            enum CodingKeys: String, CodingKey { case id; case isBot = "is_bot" }
        }
        do {
            let rows: [Row] = try await client.from("matches")
                .select("id,is_bot")
                .eq("status", value: "active")
                .or("white.eq.\(uid.uuidString),black.eq.\(uid.uuidString)")
                .order("created_at", ascending: false)
                .limit(1)
                .execute().value
            guard let row = rows.first, !row.isBot else { return nil }
            return row.id
        } catch {
            return nil
        }
    }

    static func load(id: UUID, client: SupabaseClient) async throws -> OnlineMatchInfo {
        struct Setup: Decodable {
            let decks: [String: [String]]
            let ultimates: [String: String]
        }
        struct Row: Decodable {
            let white: UUID?
            let black: UUID?
            let whiteCard: PlayerCard
            let blackCard: PlayerCard
            let isBot: Bool
            let botLevel: String?
            let rulesVersion: Int
            let timeControl: String
            let setup: Setup
            let status: String
            let turn: String
            let clockWhiteMs: Int
            let clockBlackMs: Int
            let clockStartedAt: String
            let lastActionAt: String?
            enum CodingKeys: String, CodingKey {
                case white, black, setup, status, turn
                case whiteCard = "white_card", blackCard = "black_card"
                case isBot = "is_bot", botLevel = "bot_level"
                case rulesVersion = "rules_version", timeControl = "time_control"
                case clockWhiteMs = "clock_white_ms", clockBlackMs = "clock_black_ms"
                case clockStartedAt = "clock_started_at", lastActionAt = "last_action_at"
            }
        }
        struct ActionRow: Decodable { let code: String }
        let row: Row = try await client.from("matches")
            .select("white,black,white_card,black_card,is_bot,bot_level,rules_version,time_control,setup,status,turn,clock_white_ms,clock_black_ms,clock_started_at,last_action_at")
            .eq("id", value: id).single().execute().value
        let actions: [ActionRow] = try await client.from("match_actions").select("code")
            .eq("match_id", value: id).order("ply").execute().value
        let uid = client.auth.currentUser?.id
        let youAreWhite = row.white == uid
        let started = OnlineDate.parse(row.clockStartedAt)
        let last = row.lastActionAt.flatMap(OnlineDate.parse) ?? started
        var white = Double(row.clockWhiteMs) / 1000
        var black = Double(row.clockBlackMs) / 1000
        let beforeStart = started.map { Date() < $0 } ?? false
        if !beforeStart, let last, row.status == "active" {
            let elapsed = max(0, Date().timeIntervalSince(last))
            if row.turn == "black" { black = max(0, black - elapsed) }
            else { white = max(0, white - elapsed) }
        }
        let record = MatchRecord(rulesVersion: row.rulesVersion, decks: row.setup.decks,
                                 ultimates: row.setup.ultimates, actions: actions.map(\.code))
        return OnlineMatchInfo(matchId: id, isBot: row.isBot,
                                botLevel: row.botLevel.flatMap(BotLevel.init(rawValue:)),
                                myColor: youAreWhite ? .white : .black,
                                opponent: youAreWhite ? row.blackCard : row.whiteCard,
                                timeControl: TimeControl(rawValue: row.timeControl) ?? .blitz5,
                                record: record, clockWhite: white, clockBlack: black,
                                showIntro: actions.isEmpty && beforeStart)
    }

    static func finishState(id: UUID, client: SupabaseClient, myColor: PlayerColor) async -> FinishState? {
        struct Row: Decodable {
            let status: String
            let result: String?
            let winnerColor: String?
            let trophyDeltaWhite: Int?
            let trophyDeltaBlack: Int?
            enum CodingKeys: String, CodingKey {
                case status, result
                case winnerColor = "winner_color"
                case trophyDeltaWhite = "trophy_delta_white"
                case trophyDeltaBlack = "trophy_delta_black"
            }
        }
        guard let row = try? await client.from("matches")
            .select("status,result,winner_color,trophy_delta_white,trophy_delta_black")
            .eq("id", value: id).single().execute().value as Row else { return nil }
        let delta = myColor == .white ? row.trophyDeltaWhite : row.trophyDeltaBlack
        return FinishState(status: row.status, result: row.result,
                           winner: row.winnerColor.flatMap(PlayerColor.init(rawValue:)), myDelta: delta)
    }
}

enum OnlineDate {
    static func parse(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}

/// Sitzung einer Online-Partie gegen einen Menschen (Anleitung Schritt 9).
final class SupabaseMatchSession: OnlineMatchSession {
    let info: OnlineMatchInfo
    let events: AsyncStream<OnlineMatchEvent>
    private let continuation: AsyncStream<OnlineMatchEvent>.Continuation
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var closed = false

    init(info: OnlineMatchInfo, client: SupabaseClient) {
        self.info = info
        self.client = client
        var cont: AsyncStream<OnlineMatchEvent>.Continuation!
        events = AsyncStream { cont = $0 }
        continuation = cont
        Task { await connect() }
    }

    func submit(_ code: String, ply: Int) async throws {
        struct Body: Encodable { let match_id: UUID; let ply: Int; let code: String }
        struct OK: Decodable { let ok: Bool? }
        do {
            let _: OK = try await client.functions.invoke(
                OnlineConfig.Endpoint.submitAction,
                options: .init(body: Body(match_id: info.matchId, ply: ply, code: code))
            )
        } catch let error as FunctionsError {
            throw Self.matchError(error)
        } catch {
            throw OnlineMatchError.network
        }
    }

    func resign() async throws {
        try await emit(rpc: OnlineConfig.Endpoint.resign, params: Resign(p_match: info.matchId))
    }

    func offerDraw() async throws {
        try await client.rpc(OnlineConfig.Endpoint.offerDraw, params: Resign(p_match: info.matchId)).execute()
    }

    func answerDraw(accept: Bool) async throws {
        try await emit(rpc: OnlineConfig.Endpoint.answerDraw, params: Answer(p_match: info.matchId, p_accept: accept))
    }

    func claimTimeout() async throws {
        try await emit(rpc: OnlineConfig.Endpoint.claimTimeout, params: Resign(p_match: info.matchId))
    }

    func fetchActions() async throws -> [String] {
        struct Row: Decodable { let code: String }
        let rows: [Row] = try await client.from("match_actions").select("code")
            .eq("match_id", value: info.matchId).order("ply").execute().value
        return rows.map(\.code)
    }

    func close() {
        guard !closed else { return }
        closed = true
        continuation.finish()
        let channel = channel
        Task { await channel?.unsubscribe() }
    }

    private struct Resign: Encodable { let p_match: UUID }
    private struct Answer: Encodable { let p_match: UUID; let p_accept: Bool }

    private func connect() async {
        let id = info.matchId.uuidString
        let ch = client.channel("match-\(id)")
        let inserts = ch.postgresChange(InsertAction.self, schema: "public", table: "match_actions",
                                        filter: .eq("match_id", value: id))
        let updates = ch.postgresChange(UpdateAction.self, schema: "public", table: "matches",
                                        filter: .eq("id", value: id))
        await ch.subscribe()
        channel = ch
        Task { [weak self] in
            for await row in inserts {
                guard let self, !self.closed else { return }
                self.yieldAction(row.record)
            }
        }
        Task { [weak self] in
            for await row in updates {
                guard let self, !self.closed else { return }
                self.yieldMatch(row.record)
            }
        }
    }

    private func yieldAction(_ record: [String: AnyJSON]) {
        guard let ply = Self.int(record["ply"]), let code = record["code"]?.stringValue else { return }
        continuation.yield(.action(ply: ply, code: code, clockMs: Self.int(record["clock_ms"])))
    }

    private func yieldMatch(_ record: [String: AnyJSON]) {
        if let white = Self.int(record["clock_white_ms"]), let black = Self.int(record["clock_black_ms"]),
           let turn = record["turn"]?.stringValue.flatMap(PlayerColor.init(rawValue:)) {
            continuation.yield(.clocks(whiteMs: white, blackMs: black, turn: turn))
        }
        if let offer = record["draw_offer_by"]?.stringValue.flatMap(PlayerColor.init(rawValue:)) {
            continuation.yield(.drawOffered(by: offer))
        } else if record["draw_offer_by"]?.isNil == true {
            continuation.yield(.drawOfferCleared)
        }
        let status = record["status"]?.stringValue ?? "active"
        guard status != "active" else { return }
        let winner = record["winner_color"]?.stringValue.flatMap(PlayerColor.init(rawValue:))
        let delta = info.myColor == .white ? Self.int(record["trophy_delta_white"]) : Self.int(record["trophy_delta_black"])
        continuation.yield(.finished(result: record["result"]?.stringValue ?? status, winner: winner, myTrophyDelta: delta))
    }

    private func emit<P: Encodable>(rpc name: String, params: P) async throws {
        let response: PostgrestResponse<Void> = try await client.rpc(name, params: params).execute()
        guard let obj = try? JSONDecoder().decode([String: AnyJSON].self, from: response.data) else { return }
        let status = obj["status"]?.stringValue
        if status == nil || status == "active" { return }
        if status == "finished" || status == "aborted" || obj["result"] != nil {
            let winner = obj["winner"]?.stringValue.flatMap(PlayerColor.init(rawValue:))
            let delta = info.myColor == .white ? Self.int(obj["trophy_delta_white"]) : Self.int(obj["trophy_delta_black"])
            continuation.yield(.finished(result: obj["result"]?.stringValue ?? status ?? "finished",
                                        winner: winner, myTrophyDelta: delta))
        }
    }

    private static func matchError(_ error: FunctionsError) -> OnlineMatchError {
        guard case .httpError(let code, let data) = error else { return .network }
        struct Body: Decodable { let error: String; let action_count: Int? }
        let body = try? JSONDecoder().decode(Body.self, from: data)
        switch body?.error {
        case "out_of_sync": return .outOfSync(actionCount: body?.action_count ?? 0)
        case "not_your_turn": return .notYourTurn
        case "timeout": return .timeout
        case "not_active": return .notActive
        case "illegal_action": return .illegalAction
        default:
            if code == 422 { return .illegalAction }
            if code == 409 { return .notActive }
            return .network
        }
    }

    /// Realtime schickt Zahlen oft als String.
    private static func int(_ value: AnyJSON?) -> Int? {
        guard let value else { return nil }
        if let i = value.intValue { return i }
        if let d = value.doubleValue { return Int(d) }
        if let s = value.stringValue { return Int(s) }
        return nil
    }
}

import Foundation
import Supabase

/// Freunde (wie web/src/friends.ts): Liste, Anfragen, Suche über Name oder Freundescode, Einladungslink,
/// Profil-Übersicht, Blockieren und Melden. Alles über die Server-Funktionen der Migration
/// Backend/supabase/migrations/20261107120000_friends.sql.
struct FriendPlayer: Decodable, Identifiable, Equatable {
    enum Relation: String, Decodable { case none, me = "self", friend, incoming, outgoing }

    let userId: UUID
    let name: String
    let avatar: String
    let frame: String?
    let title: String?
    let level: Int
    let trophies: Int
    let relation: Relation
    let since: Date?
    /// Bot-Spieler (offen gekennzeichnet)
    let isBot: Bool
    /// Nur bei Freunden: gerade in der App (oder laut Online-Zeiten des Bot-Spielers)
    let online: Bool

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id", name = "display_name", avatar, frame, title, level, trophies, relation, since
        case isBot = "is_bot", online
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(UUID.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        avatar = try c.decode(String.self, forKey: .avatar)
        frame = try c.decodeIfPresent(String.self, forKey: .frame)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        level = try c.decode(Int.self, forKey: .level)
        trophies = try c.decode(Int.self, forKey: .trophies)
        relation = try c.decode(Relation.self, forKey: .relation)
        since = try c.decodeIfPresent(Date.self, forKey: .since)
        isBot = try c.decodeIfPresent(Bool.self, forKey: .isBot) ?? false
        online = try c.decodeIfPresent(Bool.self, forKey: .online) ?? false
    }
}

struct FriendProfile: Decodable, Equatable {
    let userId: UUID
    let name: String
    let avatar: String
    let frame: String?
    let title: String?
    let level: Int
    let relation: FriendPlayer.Relation
    let trophies: Int
    let bestTrophies: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let rank: Int
    let friends: Int
    let since: Date?
    let vsWins: Int
    let vsLosses: Int
    let vsDraws: Int
    let isBot: Bool?
    let online: Bool?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id", name = "display_name", avatar, frame, title, level, relation, trophies
        case bestTrophies = "best_trophies", wins = "online_wins", losses = "online_losses", draws = "online_draws"
        case rank, friends, since, vsWins = "vs_wins", vsLosses = "vs_losses", vsDraws = "vs_draws"
        case isBot = "is_bot", online
    }
}

struct BlockedPlayer: Decodable, Identifiable {
    let userId: UUID
    let name: String
    let avatar: String
    let frame: String?
    var id: UUID { userId }
    enum CodingKeys: String, CodingKey { case userId = "user_id", name = "display_name", avatar, frame }
}

enum ReportReason: String, CaseIterable, Identifiable {
    case name, cheating, abuse, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .name: return L("Anstößiger Name")
        case .cheating: return L("Schummeln")
        case .abuse: return L("Beleidigung")
        case .other: return L("Etwas anderes")
        }
    }
}

/// Server-Meldungen als Text für die Oberfläche.
enum FriendError {
    static func message(_ error: Error) -> String {
        let text = (error as? PostgrestError)?.message ?? error.localizedDescription
        if text.contains("too_many_requests") { return L("Zu viele Anfragen. Versuche es später noch einmal.") }
        if text.contains("friend_limit") { return L("Ihr könnt höchstens 200 Freunde haben.") }
        if text.contains("no_account") { return L("Zuerst brauchst du ein Online-Konto.") }
        if text.contains("not_found") { return L("Niemand gefunden. Prüfe den Namen oder den Code.") }
        if text.contains("not_friends") { return L("Nur Freunde kannst du herausfordern.") }
        if text.contains("invite_gone") { return L("Die Herausforderung ist nicht mehr offen.") }
        if text.contains("deck_incomplete") { return L("Dein Deck braucht 4 verschiedene Karten.") }
        if text.contains("rules_outdated") { return L("Bitte aktualisiere Rook Raid, um online zu spielen.") }
        return AccountError(error).message
    }
}

/// Freundescode im Link: 6 Zeichen ohne 0/O/1/I.
enum FriendCode {
    static func isValid(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy { "23456789ABCDEFGHJKLMNPQRSTUVWXYZ".contains($0) }
    }

    /// https://<Domain>/f/<CODE> – die Domain der Browser-Fassung (RR_WEB_DOMAIN in Config/RookRaid.xcconfig).
    /// Ist die App installiert, öffnet iOS den Link direkt in der App (Universal Link), sonst den Browser.
    static func link(_ code: String) -> URL? {
        guard let domain = OnlineConfig.webDomain else { return nil }
        return URL(string: "https://\(domain)/f/\(code)")
    }

    /// Code aus einem geöffneten Link: Universal Link https://<Domain>/f/CODE oder – vom „In der App öffnen“-Knopf
    /// der Webseite, falls der Messenger den Link im eigenen Browser öffnet – rookraid://f/CODE.
    static func from(url: URL) -> String? {
        var parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme?.lowercased() == "rookraid", let host = url.host { parts.insert(host, at: 0) }
        guard parts.count == 2, parts[0] == "f" else { return nil }
        let code = parts[1].uppercased()
        return isValid(code) ? code : nil
    }
}

/// Zustand für die Oberfläche: Freunde, offene Anfragen, eigener Code, Neuigkeiten für den Hinweis oben.
@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    struct News: Equatable {
        enum Kind { case request, accepted, reward }
        let kind: Kind
        let name: String
        /// kind .reward: die Freundestruhe für den ersten Freund
        var chestId: UUID? = nil
    }

    /// Ein beendetes Spiel gegen einen Freund (friend_matches), aus meiner Sicht.
    struct FriendMatch: Decodable, Identifiable {
        enum Outcome: String, Decodable { case win, loss, draw }
        let matchId: UUID
        let endedAt: Date
        let result: Outcome
        let reason: String?
        let rated: Bool
        let trophyDelta: Int?
        let timeControl: String?
        var id: UUID { matchId }

        enum CodingKeys: String, CodingKey {
            case matchId = "match_id", endedAt = "ended_at", result, reason, rated, trophyDelta = "trophy_delta", timeControl = "time_control"
        }
    }

    @Published private(set) var players: [FriendPlayer] = []
    @Published private(set) var code: String?
    @Published private(set) var loaded = false
    /// Neue Anfrage oder angenommene Anfrage seit dem letzten Laden (Hinweis in der App, wie die Push-Nachricht)
    @Published var news: News?
    /// Code aus einem Einladungslink: wartet, bis es ein Konto gibt.
    @Published var pendingInvite: String?
    /// Eigener Online-Status für Freunde sichtbar (nil = noch nicht geladen)
    @Published private(set) var showOnline: Bool?

    private var client: SupabaseClient? { Backend.client }
    private var refreshing: Task<Void, Never>?
    private var poller: Task<Void, Never>?

    var friends: [FriendPlayer] { players.filter { $0.relation == .friend } }
    var incoming: [FriendPlayer] { players.filter { $0.relation == .incoming } }
    var outgoing: [FriendPlayer] { players.filter { $0.relation == .outgoing } }

    private var active: Bool { OnlineAccount.shared.hasAccount && client != nil }

    func refresh() async {
        guard active, let client else {
            players = []; code = nil; loaded = false; news = nil; showOnline = nil
            return
        }
        if let refreshing { await refreshing.value; return }
        let task = Task { @MainActor in
            do {
                let list: [FriendPlayer] = try await client.rpc("my_friends").execute().value
                if code == nil {
                    let mine: String = try await client.rpc("my_friend_code").execute().value
                    code = mine
                }
                if showOnline == nil, let uid = client.auth.currentUser?.id {
                    struct Row: Decodable { let show_online: Bool? }
                    let rows: [Row] = (try? await client.from("profiles").select("show_online").eq("id", value: uid).execute().value) ?? []
                    showOnline = rows.first?.show_online ?? true
                }
                if loaded {
                    let before = Dictionary(uniqueKeysWithValues: players.map { ($0.userId, $0.relation) })
                    if let fresh = list.first(where: { $0.relation == .incoming && before[$0.userId] != .incoming }) {
                        news = News(kind: .request, name: fresh.name)
                    } else if let accepted = list.first(where: { $0.relation == .friend && before[$0.userId] == .outgoing }) {
                        news = News(kind: .accepted, name: accepted.name)
                    }
                }
                // Erster Freund: eine Goldtruhe (einmal pro Spieler)
                if let chest = ProfileStore.shared.grantFirstFriendChestIfDue(hasFriend: list.contains { $0.relation == .friend }) {
                    news = News(kind: .reward, name: "", chestId: chest.id)
                }
                players = list
                loaded = true
            } catch {
                // offline: letzte Liste behalten
            }
        }
        refreshing = task
        await task.value
        refreshing = nil
    }

    /// Solange die App vorne ist: jede Minute nachsehen (Anfragen kommen auch ohne Push an).
    func startPolling() {
        poller?.cancel()
        poller = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    func stopPolling() {
        poller?.cancel()
        poller = nil
    }

    /// Die Push-Nachricht an den anderen geht sofort raus (push-dispatch verschickt nur, was der Server vorgemerkt hat).
    private func dispatchPush() {
        guard let client else { return }
        Task { try? await client.functions.invoke("push-dispatch", options: .init(body: [String: String]())) }
    }

    func find(_ query: String) async throws -> [FriendPlayer] {
        guard let client else { throw AccountError.offline }
        return try await client.rpc("find_player", params: ["p_query": query.trimmingCharacters(in: .whitespaces)]).execute().value
    }

    /// „sent“, „accepted“ oder „already_friends“
    @discardableResult
    func send(to user: UUID) async throws -> String {
        guard let client else { throw AccountError.offline }
        let reply: String = try await client.rpc("send_friend_request", params: ["p_user": user]).execute().value
        dispatchPush()
        await refresh()
        return reply
    }

    func respond(to user: UUID, accept: Bool) async throws {
        guard let client else { throw AccountError.offline }
        struct Params: Encodable { let p_user: UUID; let p_accept: Bool }
        do {
            try await client.rpc("respond_friend_request", params: Params(p_user: user, p_accept: accept)).execute()
        } catch let e as PostgrestError where e.message.contains("no_request") {
            // schon erledigt (anderes Gerät)
        }
        if accept { dispatchPush() }
        await refresh()
    }

    func cancel(_ user: UUID) async throws {
        try await call("cancel_friend_request", user)
        await refresh()
    }

    func remove(_ user: UUID) async throws {
        try await call("remove_friend", user)
        await refresh()
    }

    func block(_ user: UUID) async throws {
        try await call("block_player", user)
        await refresh()
    }

    func unblock(_ user: UUID) async throws { try await call("unblock_player", user) }

    /// Online-Status für Freunde zeigen oder verbergen.
    func setShowOnline(_ show: Bool) async throws {
        guard let client else { throw AccountError.offline }
        let before = showOnline
        showOnline = show
        do {
            try await client.rpc("set_show_online", params: ["p_show": show]).execute()
        } catch {
            showOnline = before
            throw error
        }
    }

    func blocked() async throws -> [BlockedPlayer] {
        guard let client else { throw AccountError.offline }
        return try await client.rpc("blocked_players").execute().value
    }

    func report(_ user: UUID, reason: ReportReason) async throws {
        guard let client else { throw AccountError.offline }
        struct Params: Encodable { let p_user: UUID; let p_reason: String }
        try await client.rpc("report_player", params: Params(p_user: user, p_reason: reason.rawValue)).execute()
    }

    func profile(_ user: UUID) async throws -> FriendProfile {
        guard let client else { throw AccountError.offline }
        return try await client.rpc("friend_profile", params: ["p_user": user]).execute().value
    }

    /// Die letzten Spiele gegen einen Freund (neueste zuerst).
    func matches(with user: UUID) async throws -> [FriendMatch] {
        guard let client else { throw AccountError.offline }
        struct Params: Encodable { let p_user: UUID; let p_limit: Int }
        return try await client.rpc("friend_matches", params: Params(p_user: user, p_limit: 20)).execute().value
    }

    private func call(_ fn: String, _ user: UUID) async throws {
        guard let client else { throw AccountError.offline }
        try await client.rpc(fn, params: ["p_user": user]).execute()
    }
}

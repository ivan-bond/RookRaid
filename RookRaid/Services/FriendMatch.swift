import Foundation
import Supabase

/// Freundschaftsspiele (wie web/src/friendMatch.ts): einladen, annehmen, ablehnen – und das Lebenszeichen für den
/// Online-Status. Server: Migration Backend/supabase/migrations/20261109120000_bot_players.sql.
/// 5 | 0, ohne Trophäen, zählt für die Bilanz gegeneinander. Eine Einladung gilt 2 Minuten.
struct MatchInvite: Decodable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let name: String
    let avatar: String
    let frame: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", name = "display_name", avatar, frame, createdAt = "created_at"
    }
}

@MainActor
final class FriendMatchCenter: ObservableObject {
    static let shared = FriendMatchCenter()

    /// Eigene Einladung, auf deren Antwort wir warten
    struct Outgoing: Equatable {
        enum State: Equatable { case waiting, declined, expired, failed(String) }
        let inviteId: UUID
        let friend: UUID
        let name: String
        let avatar: String
        let frame: String?
        let startedAt: Date
        var state: State
    }

    static let lifetime: TimeInterval = 120

    /// Der Freund aus dem letzten Freundschaftsspiel (für „Revanche“ im Ergebnisfenster).
    struct Opponent: Equatable {
        let id: UUID
        let name: String
        let avatar: String
        let frame: String?
    }
    private(set) var lastOpponent: Opponent?

    @Published private(set) var outgoing: Outgoing?
    /// Einladungen an mich (neueste zuerst)
    @Published private(set) var incoming: [MatchInvite] = []
    /// Partie steht bereit: RootView schließt die Sheets, HomeView startet sie.
    @Published var readyMatch: UUID?

    private var client: SupabaseClient? { Backend.client }
    private var heartbeat: Task<Void, Never>?
    private var watcher: Task<Void, Never>?
    private var dismissed = Set<UUID>()

    /// Alle 15 s, solange die App vorne ist: Lebenszeichen (Online-Status) und neue Einladungen.
    func start() {
        heartbeat?.cancel()
        heartbeat = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await self?.touch()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    func stop() {
        heartbeat?.cancel()
        heartbeat = nil
    }

    func touch() async {
        guard OnlineAccount.shared.hasAccount, let client else { incoming = []; return }
        struct Reply: Decodable { let invites: [MatchInvite] }
        guard let reply: Reply = try? await client.rpc("touch_online").execute().value else { return }
        let fresh = reply.invites.filter { !dismissed.contains($0.id) && Date().timeIntervalSince($0.createdAt) < Self.lifetime }
        if fresh.contains(where: { new in !incoming.contains { $0.id == new.id } }) { Haptics.shared.play(.select) }
        incoming = fresh
    }

    private struct Setup: Encodable {
        let p_rules_version: Int
        let p_deck: [String]
        let p_ultimate: String
        let p_card: PlayerCard
    }

    private var mySetup: Setup {
        let store = ProfileStore.shared
        return Setup(p_rules_version: OnlineConfig.rulesVersion, p_deck: store.activeDeck.map(\.rawValue),
                     p_ultimate: store.activeUltimate.rawValue, p_card: store.playerCard)
    }

    /// Freund herausfordern. Wartet danach selbst auf die Antwort (alle 2 s).
    func invite(_ friend: UUID, name: String, avatar: String, frame: String?) async throws {
        guard let client else { throw AccountError.offline }
        guard ProfileStore.shared.deckIsFull else { throw MatchmakingError.deckIncomplete }
        struct Params: Encodable {
            let p_user: UUID
            let p_rules_version: Int
            let p_deck: [String]
            let p_ultimate: String
            let p_card: PlayerCard
        }
        let s = mySetup
        let id: UUID = try await client.rpc("invite_friend_match", params: Params(
            p_user: friend, p_rules_version: s.p_rules_version, p_deck: s.p_deck, p_ultimate: s.p_ultimate, p_card: s.p_card
        )).execute().value
        Task { try? await client.functions.invoke("push-dispatch", options: .init(body: [String: String]())) }
        outgoing = Outgoing(inviteId: id, friend: friend, name: name, avatar: avatar, frame: frame, startedAt: Date(), state: .waiting)
        watch(id)
    }

    private func watch(_ id: UUID) {
        watcher?.cancel()
        watcher = Task { @MainActor [weak self] in
            struct Status: Decodable { let status: String; let match_id: UUID? }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, let client = self.client, self.outgoing?.inviteId == id else { return }
                guard let s: Status = try? await client.rpc("friend_match_status", params: ["p_invite": id]).execute().value else { continue }
                switch s.status {
                case "accepted":
                    if let o = self.outgoing { self.lastOpponent = Opponent(id: o.friend, name: o.name, avatar: o.avatar, frame: o.frame) }
                    self.outgoing = nil
                    if let match = s.match_id { self.readyMatch = match }
                    return
                case "declined":
                    self.outgoing?.state = .declined
                    return
                case "expired", "cancelled":
                    self.outgoing?.state = .expired
                    return
                default:
                    continue
                }
            }
        }
    }

    func cancelOutgoing() {
        watcher?.cancel()
        if let out = outgoing, out.state == .waiting, let client {
            Task { _ = try? await client.rpc("cancel_friend_match", params: ["p_invite": out.inviteId]).execute() }
        }
        outgoing = nil
    }

    /// Einladung annehmen: Die Partie wird angelegt und gleich gestartet.
    func accept(_ invite: MatchInvite) async throws {
        guard let client else { throw AccountError.offline }
        guard ProfileStore.shared.deckIsFull else { throw MatchmakingError.deckIncomplete }
        struct Params: Encodable {
            let p_invite: UUID
            let p_accept: Bool
            let p_rules_version: Int
            let p_deck: [String]
            let p_ultimate: String
            let p_card: PlayerCard
        }
        let s = mySetup
        drop(invite.id)
        let match: UUID? = try await client.rpc("answer_friend_match", params: Params(
            p_invite: invite.id, p_accept: true, p_rules_version: s.p_rules_version, p_deck: s.p_deck,
            p_ultimate: s.p_ultimate, p_card: s.p_card
        )).execute().value
        lastOpponent = Opponent(id: invite.userId, name: invite.name, avatar: invite.avatar, frame: invite.frame)
        if let match { readyMatch = match }
    }

    /// „Revanche“ nach einem Freundschaftsspiel: denselben Freund noch einmal herausfordern.
    /// Klappt das nicht, zeigt das Wartefenster den Grund.
    func rematch() async {
        guard let o = lastOpponent else { return }
        do {
            try await invite(o.id, name: o.name, avatar: o.avatar, frame: o.frame)
        } catch {
            outgoing = Outgoing(inviteId: UUID(), friend: o.id, name: o.name, avatar: o.avatar, frame: o.frame,
                                startedAt: Date(), state: .failed(FriendError.message(error)))
        }
    }

    func decline(_ invite: MatchInvite) {
        drop(invite.id)
        guard let client else { return }
        struct Params: Encodable {
            let p_invite: UUID
            let p_accept: Bool
            let p_rules_version: Int
            let p_deck: [String]
            let p_ultimate: String
            let p_card: PlayerCard
        }
        let s = mySetup
        Task {
            _ = try? await client.rpc("answer_friend_match", params: Params(
                p_invite: invite.id, p_accept: false, p_rules_version: s.p_rules_version, p_deck: s.p_deck,
                p_ultimate: s.p_ultimate, p_card: s.p_card
            )).execute()
        }
    }

    private func drop(_ id: UUID) {
        dismissed.insert(id)
        incoming.removeAll { $0.id == id }
    }

    /// Abmelden: alles vergessen.
    func reset() {
        cancelOutgoing()
        lastOpponent = nil
        incoming = []
        readyMatch = nil
        dismissed = []
    }
}

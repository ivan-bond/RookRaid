import Foundation
import Supabase

/// Fehler der Konto-Funktionen (Server-Meldungen aus Backend/supabase/migrations, z. B. `raise exception 'name_taken'`).
enum AccountError: Error, Equatable {
    case nameInvalid
    case nameTaken
    case notAuthenticated
    case offline
    /// Löschen eines Apple-Kontos: Die Bestätigung bei Apple wurde abgebrochen.
    case appleConfirmCancelled
    /// Anmeldung im Browser (Google) abgebrochen – keine Meldung nötig
    case cancelled
    /// Dieses Apple-/Google-Konto gehört schon zu einem anderen Rook-Raid-Konto
    case identityTaken
    case server(String)

    init(_ error: Error) {
        if let e = error as? AccountError { self = e; return }
        if (error as NSError).domain == "com.apple.AuthenticationServices.WebAuthenticationSession", (error as NSError).code == 1 {
            self = .cancelled; return
        }
        let message = (error as? PostgrestError)?.message ?? error.localizedDescription
        if message.contains("identity_already_exists") || message.contains("already linked") || message.contains("Identity is already") {
            self = .identityTaken; return
        }
        switch message {
        case "name_invalid": self = .nameInvalid
        case "name_taken": self = .nameTaken
        case "not_authenticated": self = .notAuthenticated
        default: self = (error as? URLError) != nil ? .offline : .server(message)
        }
    }

    var message: String {
        switch self {
        case .nameInvalid: return L("Der Name passt nicht: 2–16 Zeichen, Buchstaben, Ziffern, Leerzeichen, _ . -")
        case .nameTaken: return L("Dieser Name ist schon vergeben.")
        case .notAuthenticated: return L("Anmeldung fehlgeschlagen. Bitte versuche es noch einmal.")
        case .offline: return L("Keine Verbindung zum Server.")
        case .appleConfirmCancelled: return L("Bestätige das Löschen mit Apple. Dann meldet sich Rook Raid auch bei deiner Apple-ID ab.")
        case .cancelled: return L("Abgebrochen.")
        case .identityTaken: return L("Dieses Konto gehört schon zu einem anderen Rook-Raid-Spieler. Melde dich stattdessen damit an.")
        case .server: return L("Der Server hat nicht geantwortet. Bitte versuche es später noch einmal.")
        }
    }
}

/// Supabase-Fassung von `AccountService` (Anleitung Schritt 7).
final class SupabaseAccountService: AccountService {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }

    /// Spielername auf dem Server, wenn `setup_account` „existing“ meldet
    private(set) var existingName: String?

    var state: AccountState {
        guard let user = client.auth.currentUser else { return .guest }
        return .signedIn(userId: user.id.uuidString, anonymous: user.isAnonymous)
    }

    /// Angemeldet mit Apple (nicht nur anonym)?
    var currentUserId: String? { client.auth.currentUser?.id.uuidString }

    var isLinkedWithApple: Bool {
        client.auth.currentUser?.identities?.contains { $0.provider == "apple" } ?? false
    }

    /// Mit wem das Konto gesichert ist (Apple vor Google; nil = nur anonym)
    var securedBy: SignInProvider? {
        let ids = client.auth.currentUser?.identities ?? []
        if ids.contains(where: { $0.provider == "apple" }) { return .apple }
        if ids.contains(where: { $0.provider == "google" }) { return .google }
        return nil
    }

    /// Rücksprung aus dem Google-Anmeldefenster (URL-Schema in Config/Info.plist; in Supabase als Redirect-URL erlaubt)
    static let authCallback = URL(string: "rookraid://auth-callback")!

    /// Sign in with Google auf einem Gerät ohne dieses Konto (Supabase-OAuth im Anmeldefenster von iOS).
    func signInWithGoogle() async throws -> AccountSetup {
        try await client.auth.signInWithOAuth(provider: .google, redirectTo: Self.authCallback)
        return try await setup()
    }

    /// Anonymes Konto mit Google verknüpfen: ID, Trophäen, Freunde und Partien bleiben.
    @MainActor
    func linkGoogle() async throws {
        let response = try await client.auth.getLinkIdentityURL(provider: .google, redirectTo: Self.authCallback)
        let callback = try await WebAuthFlow.run(response.url, scheme: "rookraid")
        try await client.auth.session(from: callback)
    }

    /// Nur die Anmeldung (ohne Konto). Danach darf die App `name_available` fragen.
    func ensureSession() async throws {
        if client.auth.currentUser == nil { try await client.auth.signInAnonymously() }
    }

    func signInAnonymously() async throws -> AccountSetup {
        try await ensureSession()
        return try await setup()
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AccountSetup {
        try await client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        return try await setup()
    }

    /// Anonymes Konto behält seine ID, Trophäen und Partien (supabase-swift: `linkIdentityWithIdToken`).
    func linkApple(idToken: String, nonce: String) async throws {
        try await client.auth.linkIdentityWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
    }

    func nameAvailable(_ name: String) async throws -> Bool {
        try await client.rpc(OnlineConfig.Endpoint.nameAvailable, params: ["p_name": name]).execute().value
    }

    func setDisplayName(_ name: String) async throws {
        try await client.rpc(OnlineConfig.Endpoint.setDisplayName, params: ["p_name": name]).execute()
    }

    /// `setup_account` legt Profil und Fortschritt an (Gast-Fortschritt übernehmen) oder meldet „existing“.
    /// Der Spielername steht in `p_card.name` (eindeutig, Entscheidung E8).
    @MainActor private func setup() async throws -> AccountSetup {
        let store = ProfileStore.shared
        struct Params: Encodable { let p_snapshot: ProgressSnapshot; let p_card: PlayerCard }
        struct Reply: Decodable { let status: String; let progress: ServerProgress; let name: String? }
        let reply: Reply = try await client.rpc(OnlineConfig.Endpoint.setupAccount,
                                                params: Params(p_snapshot: store.progressSnapshot(), p_card: store.playerCard))
            .execute().value
        existingName = reply.name
        DeviceIdentity.link(accountId: client.auth.currentUser?.id.uuidString ?? "")
        return reply.status == "created" ? .created(reply.progress) : .existing(reply.progress)
    }

    func backup(_ snapshot: ProgressSnapshot) async throws {
        try await client.rpc(OnlineConfig.Endpoint.backupProgress, params: ["p_snapshot": snapshot]).execute()
    }

    /// Antwort von `sync_progress`: gespeichert (neue Nummer) oder veraltet (ein anderes Gerät war schneller).
    enum SyncReply { case saved(rev: Int), stale(ServerProgress), unsupported }

    /// Sichern mit Versionsprüfung: Der Server nimmt die Sicherung nur, wenn er noch auf `base` steht.
    func sync(_ snapshot: ProgressSnapshot, base: Int?) async throws -> SyncReply {
        struct Params: Encodable { let p_snapshot: ProgressSnapshot; let p_base_rev: Int? }
        struct Reply: Decodable { let status: String; let rev: Int?; let progress: ServerProgress? }
        do {
            let r: Reply = try await client.rpc("sync_progress", params: Params(p_snapshot: snapshot, p_base_rev: base)).execute().value
            if r.status == "saved", let rev = r.rev { return .saved(rev: rev) }
            if r.status == "stale", let p = r.progress { return .stale(p) }
            throw AccountError.server(r.status)
        } catch let e as PostgrestError where e.code == "PGRST202" || e.message.contains("sync_progress") {
            // Server ohne die Migration progress_sync: wie bisher sichern.
            try await backup(snapshot)
            return .unsupported
        }
    }

    /// Name des Kontos auf dem Server (eindeutig).
    func fetchDisplayName() async throws -> String? {
        struct Row: Decodable { let display_name: String }
        guard let id = client.auth.currentUser?.id else { return nil }
        let rows: [Row] = try await client.from("profiles").select("display_name").eq("id", value: id).limit(1).execute().value
        return rows.first?.display_name
    }

    /// Gewertete Partien auf dem Server (alle Geräte, auch solche, deren Ende die App nie gesehen hat).
    struct ServerGame: Decodable {
        struct Card: Decodable { let name: String? }
        let id: UUID
        let result: String?
        let winner_color: String?
        let white: UUID?
        let white_card: Card?
        let black_card: Card?
        let trophy_delta_white: Int?
        let trophy_delta_black: Int?
        let action_count: Int?
        let ended_at: Date?
        let created_at: Date
    }

    func fetchServerGames(limit: Int) async throws -> (me: UUID, games: [ServerGame]) {
        guard let me = client.auth.currentUser?.id else { return (UUID(), []) }
        let uid = me.uuidString.lowercased()
        let games: [ServerGame] = try await client.from("matches")
            .select("id,result,winner_color,white,white_card,black_card,trophy_delta_white,trophy_delta_black,action_count,ended_at,created_at")
            .eq("status", value: "finished")
            .or("white.eq.\(uid),black.eq.\(uid)")
            .order("ended_at", ascending: false)
            .limit(limit)
            .execute().value
        return (me, games)
    }

    /// Einmal je Konto: Trophäen, die nur auf dem Gerät standen (der Server hatte Partien abgelehnt), übernehmen.
    /// Der Server gibt nur zurück, was abgelehnte Bot-Partien nachweislich gekostet haben, und meldet den neuen Stand.
    func adoptDeviceTrophies(_ trophies: Int) async throws -> Int {
        try await client.rpc("adopt_device_trophies", params: ["p_trophies": trophies]).execute().value
    }

    func fetchProgress() async throws -> ServerProgress {
        try await client.from("progress").select().single().execute().value
    }

    func signOut() async throws { try await client.auth.signOut() }

    /// `appleCode`: frischer Apple-Autorisierungscode – damit widerruft der Server zuerst „Sign in with Apple“.
    func deleteAccount(appleCode: String?) async throws {
        struct Body: Encodable { let apple_authorization_code: String? }
        try await client.functions.invoke(OnlineConfig.Endpoint.deleteAccount,
                                          options: .init(body: Body(apple_authorization_code: appleCode)))
        try? await client.auth.signOut()
    }
}

/// Konto-Zustand für die Oberfläche: Anmeldung, Spielername, Server-Trophäen.
@MainActor
final class OnlineAccount: ObservableObject {
    static let shared = OnlineAccount()

    enum Status: Equatable {
        /// Kein Server konfiguriert (Config/Secrets.xcconfig fehlt)
        case unavailable
        /// Noch kein Online-Konto – alles lokal
        case guest
        /// Anonymes Konto: geht verloren, wenn die App gelöscht wird
        case anonymous
        /// Mit Apple oder Google gesichert (welcher Anbieter: `provider`)
        case secured
    }

    /// Bei `.secured`: Apple oder Google
    @Published private(set) var provider: SignInProvider?

    @Published private(set) var status: Status = .unavailable
    @Published private(set) var progress: ServerProgress?
    @Published private(set) var busy = false
    /// Konto gab es schon und hat eine Sicherung: Die App fragt, ob sie den Spielstand laden soll.
    @Published var pendingRestore: ServerProgress?

    private let service: SupabaseAccountService?

    private init() {
        service = Backend.client.map(SupabaseAccountService.init(client:))
        refreshStatus()
        PendingBotReports.retryIfNeeded()
    }

    /// Ein Online-Konto ist eingerichtet (nicht nur eine anonyme Anmeldung ohne Profil).
    var hasAccount: Bool { status == .anonymous || status == .secured }

    func refreshStatus() {
        guard let service else { status = .unavailable; return }
        switch service.state {
        case .guest: status = .guest; provider = nil
        case .signedIn:
            provider = service.securedBy
            if DeviceIdentity.current().isGuest { status = .guest }
            else { status = provider != nil ? .secured : .anonymous }
        }
    }

    /// Den Stand des Servers übernehmen (beim Start, beim Zurückkehren in die App, nach jeder Partie):
    /// - Trophäen kommen immer vom Server.
    /// - Hat ein anderes Gerät inzwischen gesichert, ersetzt dessen Spielstand den dieses Geräts (Verlauf wird zusammengeführt).
    /// - Hat dieses Gerät Änderungen, die der Server noch nicht kennt, gehen sie hin (mit Versionsprüfung).
    /// Solange eine Bot-Meldung noch nicht ankam, bleibt ein höherer lokaler Trophäen-Stand stehen.
    func reload() async {
        guard let service, hasAccount else { return }
        if var p = try? await service.fetchProgress() {
            let store = ProfileStore.shared
            // Ältere Fassungen haben abgelehnte Bot-Partien nur lokal gewertet (Taktik-Mana, das der Server nicht kennt).
            // Diese Trophäen einmal auf das Konto übernehmen, damit App und Browser denselben Stand zeigen.
            if store.profile.trophies > p.trophies, PendingBotReports.load() == nil,
               !UserDefaults.standard.bool(forKey: Self.trophiesAdoptedKey) {
                if let adopted = try? await service.adoptDeviceTrophies(store.profile.trophies) {
                    UserDefaults.standard.set(true, forKey: Self.trophiesAdoptedKey)
                    p.trophies = adopted
                    p.bestTrophies = max(p.bestTrophies, adopted)
                }
            }
            progress = p
            let name: String? = (try? await service.fetchDisplayName()) ?? nil
            if let name, !name.isEmpty, store.profile.name != name { store.profile.name = name }
            await adoptServerState(p, accountName: name)
            let waiting = PendingBotReports.load() != nil && p.trophies < store.profile.trophies
            if !waiting { adoptServerTrophies(p) }
            else { store.profile.bestTrophies = max(store.profile.bestTrophies, p.bestTrophies) }
        }
        await mergeServerGames()
    }

    /// Welche Server-Sicherung der Spielstand dieses Geräts kennt (je Konto).
    private static let syncKey = "rr.online.syncRev"
    private var syncRev: Int? {
        get {
            guard let d = UserDefaults.standard.dictionary(forKey: Self.syncKey),
                  let user = d["user"] as? String, user == service?.currentUserId, let rev = d["rev"] as? Int else { return nil }
            return rev
        }
        set {
            if let newValue, let user = service?.currentUserId {
                UserDefaults.standard.set(["user": user, "rev": newValue], forKey: Self.syncKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.syncKey)
            }
        }
    }

    private func adoptServerState(_ p: ServerProgress, accountName: String?) async {
        let known = syncRev
        if let snap = p.snapshot, known == nil || p.snapshotRev == nil || p.snapshotRev != known {
            restoreFromServer(p, snapshot: snap, accountName: accountName)
        } else if p.snapshot == nil {
            syncRev = p.snapshotRev ?? 0
            lastBackup = nil
            await syncNow()
        } else if ProfileStore.shared.hasPendingServerBackup {
            ProfileStore.shared.cancelPendingServerBackup()
            await syncNow()
        }
    }

    private func restoreFromServer(_ p: ServerProgress, snapshot: ProgressSnapshot, accountName: String?) {
        let store = ProfileStore.shared
        store.restore(from: snapshot, serverTrophies: p.trophies, serverBest: p.bestTrophies,
                      accountName: accountName ?? service?.existingName)
        if let rev = p.snapshotRev { syncRev = rev }
        // Was gerade geladen wurde, ist der Server-Stand – nicht zurückschicken (außer der Verlauf bekam Partien dazu).
        var key = store.progressSnapshot()
        key.createdAt = .distantPast
        lastBackup = (snapshot.history?.items.count ?? -1) == store.profile.history.count ? key : nil
    }

    /// Server-Partien in den Verlauf: Partien von anderen Geräten und solche, deren Ende die App nie gesehen hat
    /// (z. B. nach 45 s ohne Verbindung verloren).
    /// Spielende vom Server → Text wie in der Partie (unübersetzt, angezeigt mit `L`)
    static let serverReasons = ["mate": "durch Schachmatt", "stalemate": "durch Patt", "fifty": "durch die 50-Züge-Regel",
                                "repetition": "durch dreifache Stellungswiederholung", "timeout": "durch Zeitüberschreitung",
                                "resigned": "durch Aufgabe", "draw_agreed": "durch Einigung", "abandoned": "durch Verbindungsabbruch"]

    func mergeServerGames() async {
        guard let service, hasAccount,
              let (me, games) = try? await service.fetchServerGames(limit: GameRecord.limit), !games.isEmpty else { return }
        let reasons = Self.serverReasons
        let store = ProfileStore.shared
        var history = store.profile.history
        let known = Set(history.compactMap(\.matchId))
        var extra: [GameRecord] = []
        var changed = false
        for g in games where !known.contains(g.id) {
            let white = g.white == me
            let result: GameResultKind = g.winner_color == nil ? .draw : ((g.winner_color == "white") == white ? .win : .loss)
            let opponent = (white ? g.black_card?.name : g.white_card?.name) ?? ""
            let delta = (white ? g.trophy_delta_white : g.trophy_delta_black) ?? 0
            let date = g.ended_at ?? g.created_at
            // Ältere Einträge haben noch keine Partie-ID: gleicher Gegner und gleiches Ergebnis binnen 15 Minuten = dieselbe Partie.
            if let i = history.firstIndex(where: { $0.matchId == nil && $0.result == result && $0.opponent == opponent
                                                   && abs($0.date.timeIntervalSince(date)) < 15 * 60 }) {
                history[i].matchId = g.id
                if history[i].trophyDelta == 0 { history[i].trophyDelta = delta }
                changed = true
                continue
            }
            extra.append(GameRecord(id: g.id, date: date, opponent: opponent, result: result,
                                    reason: reasons[g.result ?? ""] ?? "", moves: g.action_count ?? 0,
                                    trophyDelta: delta, cardsPlayed: 0, replayID: nil, matchId: g.id))
        }
        guard changed || !extra.isEmpty else { return }
        store.profile.history = SnapshotHistory.merge(history, extra)
    }

    /// Direkt nach einer gewerteten Online-Partie, noch bevor die nächste Abfrage zurück ist.
    func noteOnlineResult(_ result: GameResultKind) {
        guard var p = progress else { return }
        let store = ProfileStore.shared
        p.trophies = store.profile.trophies
        p.bestTrophies = max(p.bestTrophies, store.profile.bestTrophies)
        switch result {
        case .win: p.onlineWins += 1
        case .loss: p.onlineLosses += 1
        case .draw: p.onlineDraws += 1
        }
        progress = p
    }

    enum NameCheck: Equatable { case available, taken, invalid, unknown }

    /// Live-Prüfung beim Eintippen. Dafür ist eine anonyme Anmeldung nötig (`name_available` nur für
    /// angemeldete Spieler). Wird der Dialog abgebrochen, räumt `discardProbeSession()` die Anmeldung wieder weg.
    func checkName(_ name: String) async -> NameCheck {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard Self.isValidName(trimmed) else { return .invalid }
        guard let service else { return .unknown }
        do {
            try await service.ensureSession()
            return try await service.nameAvailable(trimmed) ? .available : .taken
        } catch {
            return .unknown
        }
    }

    /// Gleiche Regel wie `valid_name()` auf dem Server: 2–16 Zeichen, Buchstaben, Ziffern, Leerzeichen, _ . -
    nonisolated static func isValidName(_ name: String) -> Bool {
        guard name == name.trimmingCharacters(in: .whitespaces), (2...16).contains(name.count) else { return false }
        return name.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || " _.-".unicodeScalars.contains($0) }
    }

    /// Erstes Online-Konto (anonym, Entscheidung E11) mit dem gewählten Namen. Ein neues Konto beginnt bei
    /// 0 Trophäen – sie kommen nur aus Partien, die der Server wertet.
    @discardableResult
    func createAccount(name: String) async throws -> AccountSetup {
        guard let service else { throw AccountError.offline }
        busy = true
        defer { busy = false }
        let store = ProfileStore.shared
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let previousName = store.profile.name
        store.profile.name = trimmed
        do {
            let setup = try await service.signInAnonymously()
            finishSetup(setup)
            return setup
        } catch {
            store.profile.name = previousName
            throw AccountError(error)
        }
    }

    private static let trophiesAdoptedKey = "rr.online.deviceTrophiesAdopted"

    @Published private(set) var offerAppleSecure = false
    private static let anonymousGamesKey = "rr.online.anonymousGames"
    private static let applePromptKey = "rr.online.applePromptShown"

    /// Nach einer gewerteten Online-Partie. Ab der dritten fragt Rocky einmal, das anonyme Konto zu sichern.
    func noteFinishedOnlineGame() {
        guard status == .anonymous else { return }
        guard !UserDefaults.standard.bool(forKey: Self.applePromptKey) else { return }
        let count = UserDefaults.standard.integer(forKey: Self.anonymousGamesKey) + 1
        UserDefaults.standard.set(count, forKey: Self.anonymousGamesKey)
        if count >= 3 { offerAppleSecure = true }
    }

    /// Der Hinweis wird gezeigt. Danach nicht noch einmal fragen.
    func consumeApplePrompt() -> Bool {
        guard offerAppleSecure else { return false }
        offerAppleSecure = false
        UserDefaults.standard.set(true, forKey: Self.applePromptKey)
        return true
    }

    /// Sign in with Apple auf einem Gerät ohne dieses Konto.
    /// „existing“ heißt: das Konto gab es schon – dann fragt die App, ob sie den Spielstand laden soll.
    @discardableResult
    func signInWithApple(idToken: String, nonce: String) async throws -> AccountSetup {
        guard let service else { throw AccountError.offline }
        busy = true
        defer { busy = false }
        do {
            let setup = try await service.signInWithApple(idToken: idToken, nonce: nonce)
            finishSetup(setup)
            return setup
        } catch {
            throw AccountError(error)
        }
    }

    /// Anonymes Konto mit Apple verknüpfen. Die Spieler-ID bleibt, der Fortschritt auch.
    func linkApple(idToken: String, nonce: String) async throws {
        guard let service else { throw AccountError.offline }
        busy = true
        defer { busy = false }
        do {
            try await service.linkApple(idToken: idToken, nonce: nonce)
            refreshStatus()
        } catch {
            throw AccountError(error)
        }
    }

    /// Sign in with Google auf einem Gerät ohne dieses Konto – wie `signInWithApple`.
    @discardableResult
    func signInWithGoogle() async throws -> AccountSetup {
        guard let service else { throw AccountError.offline }
        busy = true
        defer { busy = false }
        do {
            let setup = try await service.signInWithGoogle()
            finishSetup(setup)
            return setup
        } catch {
            throw AccountError(error)
        }
    }

    /// Anonymes Konto mit Google verknüpfen – wie `linkApple`.
    func linkGoogle() async throws {
        guard let service else { throw AccountError.offline }
        busy = true
        defer { busy = false }
        do {
            try await service.linkGoogle()
            refreshStatus()
        } catch {
            throw AccountError(error)
        }
    }

    /// Namen ändern (eindeutig) – lokal erst, wenn der Server zugestimmt hat.
    func rename(to name: String) async throws {
        guard let service else { throw AccountError.offline }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        busy = true
        defer { busy = false }
        do {
            try await service.setDisplayName(trimmed)
            ProfileStore.shared.profile.name = trimmed
        } catch {
            throw AccountError(error)
        }
    }

    /// Leise Sicherung auf dem Server: der ganze Spielstand (Karten, XP, Truhen, Verlauf …); Trophäen führt der Server selbst.
    /// Gleiche Sicherung nicht zweimal schicken (der Profil-Beobachter meldet jede Änderung).
    private var lastBackup: ProgressSnapshot?
    private var syncTask: Task<Void, Never>?

    func backupQuietly() {
        guard service != nil, hasAccount else { return }
        let previous = syncTask
        syncTask = Task { [weak self] in
            await previous?.value
            await self?.syncOnce()
        }
    }

    /// Sichern und warten, bis der Server geantwortet hat (vor dem Abmelden).
    func syncNow() async {
        backupQuietly()
        await syncTask?.value
    }

    private func syncOnce() async {
        guard let service, hasAccount else { return }
        let snapshot = ProfileStore.shared.progressSnapshot()
        var key = snapshot
        key.createdAt = .distantPast
        guard key != lastBackup else { return }
        lastBackup = key
        do {
            switch try await service.sync(snapshot, base: syncRev) {
            case .saved(let rev): syncRev = rev
            case .unsupported: break
            case .stale(let p):
                // Ein anderes Gerät hat inzwischen gesichert: dessen Stand gilt, neue Partien von hier bleiben im Verlauf.
                progress = p
                if let snap = p.snapshot { restoreFromServer(p, snapshot: snap, accountName: nil) }
                adoptServerTrophies(p)
            }
        } catch {
            lastBackup = nil
        }
    }

    /// Anonyme Anmeldung ohne Profil löschen (Name-Dialog abgebrochen). Hat der Spieler schon ein Konto, bleibt es.
    func discardProbeSession() async {
        guard let service else { return }
        guard case .signedIn(_, true) = service.state else { return }
        guard DeviceIdentity.current().isGuest else { return }
        try? await service.deleteAccount(appleCode: nil)
        progress = nil
        refreshStatus()
    }

    func signOut() async {
        guard let service else { return }
        busy = true
        defer { busy = false }
        // Alles, was noch wartet, zuerst aufs Konto – beim Abmelden geht nichts verloren.
        await syncNow()
        await PushRegistration.shared.unregister()
        try? await service.signOut()
        syncRev = nil
        lastBackup = nil
        DeviceIdentity.unlink()
        progress = nil
        refreshStatus()
    }

    /// Apple-Pflicht: Konto und Server-Daten löschen. Das lokale Profil bleibt auf dem Gerät.
    /// Mit Apple gesichert: erst bei Apple bestätigen (frischer Code), dann widerruft der Server die Anmeldung und löscht.
    func deleteAccount() async throws {
        guard let service else { throw AccountError.offline }
        var appleCode: String?
        if service.isLinkedWithApple {
            do {
                appleCode = try await AppleReauth.authorizationCode()
            } catch AppleReauth.Failure.cancelled {
                throw AccountError.appleConfirmCancelled
            } catch {
                throw AccountError.server(error.localizedDescription)
            }
        }
        busy = true
        defer { busy = false }
        do {
            try await service.deleteAccount(appleCode: appleCode)
        } catch {
            throw AccountError(error)
        }
        DeviceIdentity.unlink()
        syncRev = nil
        progress = nil
        refreshStatus()
    }

    /// Nach `setup_account`: Ein bestehendes Konto (neues Gerät, erneute Anmeldung) bringt seinen Spielstand sofort mit –
    /// ohne Nachfrage, der Server ist maßgeblich. Ein neues Konto bekommt den Stand dieses Geräts als erste Sicherung.
    private func finishSetup(_ setup: AccountSetup) {
        lastBackup = nil
        syncRev = nil
        refreshStatus()
        switch setup {
        case .created(let p):
            progress = p
            adoptServerTrophies(p)
            syncRev = p.snapshotRev ?? 0
            backupQuietly()
        case .existing(let p):
            progress = p
            if let name = service?.existingName { ProfileStore.shared.profile.name = name }
            if let snap = p.snapshot { restoreFromServer(p, snapshot: snap, accountName: service?.existingName) }
            else { backupQuietly() }
            adoptServerTrophies(p)
        }
        Task { await mergeServerGames() }
    }

    /// Ältere Fassungen fragten „Spielstand laden?“. Jetzt lädt die App immer; die Frage erscheint nicht mehr.
    func resolveRestore(load: Bool) {
        pendingRestore = nil
    }

    /// Online kommen Trophäen nur noch vom Server.
    private func adoptServerTrophies(_ p: ServerProgress) {
        let store = ProfileStore.shared
        store.profile.trophies = p.trophies
        store.profile.bestTrophies = max(store.profile.bestTrophies, p.bestTrophies)
    }
}

import Foundation
import Supabase

/// Fehler der Konto-Funktionen (Server-Meldungen aus Backend/supabase/migrations, z. B. `raise exception 'name_taken'`).
enum AccountError: Error, Equatable {
    case nameInvalid
    case nameTaken
    case notAuthenticated
    case offline
    case server(String)

    init(_ error: Error) {
        if let e = error as? AccountError { self = e; return }
        let message = (error as? PostgrestError)?.message ?? error.localizedDescription
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
    var isLinkedWithApple: Bool {
        client.auth.currentUser?.identities?.contains { $0.provider == "apple" } ?? false
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

    func fetchProgress() async throws -> ServerProgress {
        try await client.from("progress").select().single().execute().value
    }

    func signOut() async throws { try await client.auth.signOut() }

    func deleteAccount() async throws {
        try await client.functions.invoke(OnlineConfig.Endpoint.deleteAccount)
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
        /// Mit Apple gesichert
        case apple
    }

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
    var hasAccount: Bool { status == .anonymous || status == .apple }

    func refreshStatus() {
        guard let service else { status = .unavailable; return }
        switch service.state {
        case .guest: status = .guest
        case .signedIn:
            if DeviceIdentity.current().isGuest { status = .guest }
            else { status = service.isLinkedWithApple ? .apple : .anonymous }
        }
    }

    /// Server-Trophäen laden und in den lokalen Spielstand übernehmen.
    /// Solange eine Bot-Meldung noch nicht ankam, bleibt ein höherer lokaler Stand stehen.
    func reload() async {
        guard let service, hasAccount else { return }
        if let p = try? await service.fetchProgress() {
            progress = p
            let store = ProfileStore.shared
            let waiting = PendingBotReports.load() != nil && p.trophies < store.profile.trophies
            if !waiting { adoptServerTrophies(p) }
            else { store.profile.bestTrophies = max(store.profile.bestTrophies, p.bestTrophies) }
        }
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

    /// Erstes Online-Konto (anonym, Entscheidung E11) mit dem gewählten Namen. Übernimmt die Gast-Trophäen
    /// (Server deckelt auf 1 500) – danach gelten die Server-Trophäen.
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

    /// Leise Sicherung auf dem Server: Trophäen führt der Server selbst, Karten, XP und Truhen stehen in der Sicherung.
    func backupQuietly() {
        guard let service, hasAccount else { return }
        let snapshot = ProfileStore.shared.progressSnapshot()
        Task { try? await service.backup(snapshot) }
    }

    /// Anonyme Anmeldung ohne Profil löschen (Name-Dialog abgebrochen). Hat der Spieler schon ein Konto, bleibt es.
    func discardProbeSession() async {
        guard let service else { return }
        guard case .signedIn(_, true) = service.state else { return }
        guard DeviceIdentity.current().isGuest else { return }
        try? await service.deleteAccount()
        progress = nil
        refreshStatus()
    }

    func signOut() async {
        guard let service else { return }
        busy = true
        defer { busy = false }
        try? await service.signOut()
        DeviceIdentity.unlink()
        progress = nil
        refreshStatus()
    }

    /// Apple-Pflicht: Konto und Server-Daten löschen. Das lokale Profil bleibt auf dem Gerät.
    func deleteAccount() async throws {
        guard let service else { throw AccountError.offline }
        busy = true
        defer { busy = false }
        do {
            try await service.deleteAccount()
        } catch {
            throw AccountError(error)
        }
        DeviceIdentity.unlink()
        progress = nil
        refreshStatus()
    }

    /// Nach `setup_account`: neues Konto → Server-Trophäen übernehmen. Bestehendes Konto (neues Gerät, Neuinstallation)
    /// → Server-Namen übernehmen und, falls eine Sicherung da ist, fragen, ob der Spielstand geladen werden soll.
    private func finishSetup(_ setup: AccountSetup) {
        switch setup {
        case .created(let p):
            progress = p
            adoptServerTrophies(p)
        case .existing(let p):
            progress = p
            if let name = service?.existingName { ProfileStore.shared.profile.name = name }
            adoptServerTrophies(p)
            if p.snapshot != nil { pendingRestore = p }
        }
        refreshStatus()
    }

    /// Antwort auf „Spielstand laden?“: laden ersetzt den Stand dieses Geräts, behalten sichert ihn auf dem Server.
    func resolveRestore(load: Bool) {
        guard let p = pendingRestore else { return }
        pendingRestore = nil
        if load, let snapshot = p.snapshot {
            ProfileStore.shared.restore(from: snapshot, serverTrophies: p.trophies, serverBest: p.bestTrophies)
        } else {
            backupQuietly()
        }
    }

    /// Online kommen Trophäen nur noch vom Server.
    private func adoptServerTrophies(_ p: ServerProgress) {
        let store = ProfileStore.shared
        store.profile.trophies = p.trophies
        store.profile.bestTrophies = max(store.profile.bestTrophies, p.bestTrophies)
    }
}

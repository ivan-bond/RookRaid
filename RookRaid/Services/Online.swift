import Foundation

// MARK: - Online (Supabase)
//
// Konto, Gegnersuche und Partie laufen über den Server in Frankfurt, sobald URL und Schlüssel
// in der App stehen (Anleitung: Backend/ONLINE-IMPLEMENTIERUNG.md).
// Fehlen die Schlüssel, bleibt die App lokal.

enum OnlineConfig {
    /// Release-Builds sprechen mit dem Server, sobald URL und Schlüssel vorhanden sind.
    /// In Debug-Builds mit Schlüssel bleibt die Verbindung auch dann an, wenn diese Marke aus ist.
    static let enabled = true

    /// Server erreichbar und (in der Store-Fassung) online eingeschaltet.
    static var isLive: Bool {
        #if DEBUG
        return Backend.client != nil
        #else
        return enabled && Backend.client != nil
        #endif
    }
    /// So lange wird nach einem echten Gegner gesucht, bevor ein Bot einspringt.
    static let matchmakingTimeout: TimeInterval = 10
    /// Schonfrist bei Verbindungsabbruch, danach zählt die Partie als verloren (Server: 45 s ohne Heartbeat).
    static let reconnectGrace: TimeInterval = 45
    /// Ohne ersten Zug innerhalb dieser Zeit wird die Partie ohne Wertung abgebrochen.
    static let firstMoveTimeout: TimeInterval = 30
    /// Gegner werden nur mit gleicher Regel-Version zusammengebracht.
    static var rulesVersion: Int { RulesConfig.current.version }
    /// So oft fragt die App während der Gegnersuche `find_match` ab (der Server wertet Einträge > 6 s als verwaist).
    static let matchmakingPoll: TimeInterval = 2
    /// Online gibt es genau eine Zeitkontrolle: 5 | 0 (Entscheidung E3). Die Uhr-Einstellung gilt nur offline.
    static let timeControl: TimeControl = .blitz5
    /// Wer so lange keinen Lebenszeichen-Ping (`match_heartbeat`) schickt, verliert die Partie (Entscheidung E6).
    static let heartbeatInterval: TimeInterval = 10

    /// Supabase-Zugang aus der Info.plist (Schlüssel RRSupabaseURL, RRSupabaseAnonKey – Werte aus einer .xcconfig,
    /// nicht im Code). Fehlen sie, bleibt die App offline.
    static var supabaseURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "RRSupabaseURL") as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
    }
    static var supabaseAnonKey: String? {
        (Bundle.main.object(forInfoDictionaryKey: "RRSupabaseAnonKey") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Namen der Edge Functions und Datenbank-Funktionen (Backend/supabase)
    enum Endpoint {
        static let submitAction = "submit-action"
        static let finishBotMatch = "finish-bot-match"
        static let deleteAccount = "delete-account"
        static let setupAccount = "setup_account"
        static let backupProgress = "backup_progress"
        static let findMatch = "find_match"
        static let cancelMatchmaking = "cancel_matchmaking"
        static let startBotMatch = "start_bot_match"
        static let resign = "resign_match"
        static let offerDraw = "offer_draw"
        static let answerDraw = "answer_draw"
        static let claimTimeout = "claim_timeout"
        static let heartbeat = "match_heartbeat"
        static let nameAvailable = "name_available"
        static let setDisplayName = "set_display_name"
        static let leaderboard = "get_leaderboard"
        static let activeRules = "active_rules"
    }
}

// MARK: Gast-Identität

/// Feste Kennung dieses Geräts. Eigene Datei (nicht im Profil), damit sie sicher einmal erzeugt und gespeichert wird.
struct DeviceIdentity: Codable, Equatable {
    var guestId: UUID
    var createdAt: Date
    /// Konto-ID nach dem ersten Anmelden (Supabase-User-ID); nil = Gast
    var accountId: String?

    static let file = "identity"

    /// Lädt die Identität oder legt beim ersten Start eine neue an.
    @MainActor
    static func current() -> DeviceIdentity {
        if let id = Storage.load(DeviceIdentity.self, from: file) { return id }
        let fresh = DeviceIdentity(guestId: UUID(), createdAt: Date(), accountId: nil)
        Storage.saveNow(fresh, as: file)
        return fresh
    }

    /// Nach erfolgreicher Anmeldung: Konto merken (der Fortschritt wird vorher per `ProgressSnapshot` übertragen).
    @MainActor
    static func link(accountId: String) {
        var id = current()
        id.accountId = accountId
        Storage.saveNow(id, as: file)
    }

    /// Nach Abmelden oder Konto löschen: wieder Gast (die Gast-ID bleibt).
    @MainActor
    static func unlink() {
        var id = current()
        id.accountId = nil
        Storage.saveNow(id, as: file)
    }

    var isGuest: Bool { accountId == nil }
}

// MARK: Spielerkarte

/// Was der Gegner von dir sieht – auch die Bots bekommen eine solche Karte.
struct PlayerCard: Codable, Equatable {
    var name: String
    var avatar: String
    var frame: String?
    var title: String?
    var trophies: Int
    var level: Int
    var pieceSet: String?
}

extension ProfileStore {
    var playerCard: PlayerCard {
        PlayerCard(name: profile.name, avatar: activeAvatar.rawValue, frame: profile.selectedFrame,
                   title: activeTitle, trophies: profile.trophies, level: level, pieceSet: activeSkin?.rawValue)
    }
}

// MARK: Fortschritt für die Konto-Übernahme

/// Alles, was beim ersten Anmelden aus dem lokalen Gastspiel ins Konto übernommen wird.
/// Der Server prüft die Werte auf Plausibilität (z. B. Trophäen passend zu Siegen) und speichert sie dann.
struct ProgressSnapshot: Codable, Equatable {
    /// 3: Truhen-Zähler und gesehene Karten, damit XP, Karten und Truhen auf einem neuen Gerät gleich weitergehen.
    var schema = 3
    var guestId: UUID
    var createdAt: Date
    var rulesVersion: Int
    var appVersion: String

    var name: String
    var trophies: Int
    var bestTrophies: Int
    var wins: Int
    var losses: Int
    var draws: Int
    var xp: Int
    var shards: Int
    var shardsEarned: Int
    var streak: Int
    var bestStreak: Int
    var ladderBeaten: Int
    var unlockedCards: [String]
    var ownedBoards: [String]
    var ownedAvatars: [String]
    var chestTitles: [String]
    var claimedAchievements: [String]
    var solvedPuzzles: Int
    var labDone: [String]
    var pendingChests: Int
    var deck: [String]
    var ultimate: String

    // Schema 2: genug, um den Spielstand auf einem neuen Gerät wiederherzustellen (`ProfileStore.restore`)
    var solvedPuzzleIds: [String]? = nil
    var chests: [Chest]? = nil
    var levelChestsGranted: Int? = nil
    var arenaChestsGranted: Int? = nil
    var puzzleChestsGranted: Int? = nil
    var roadClaimed: [Int]? = nil
    var ladderWins: [String: Int]? = nil
    var streakFreezes: Int? = nil
    var selectedAvatar: String? = nil
    var selectedFrame: String? = nil
    var selectedTitle: String? = nil
    var selectedSkin: String? = nil
    var tutorialSeen: Bool? = nil
    var deckTourDone: Bool? = nil
    /// Schema 3: damit geöffnete Truhen, Glücksschutz und „neue Karte“ auf dem Server mitgehen.
    var pityCounter: Int? = nil
    var chestsOpened: Int? = nil
    var legendaryChests: Int? = nil
    var winChestDay: String? = nil
    var winChestsToday: Int? = nil
    var tutorialChestGiven: Bool? = nil
    var seenCards: [String]? = nil
}

extension ProfileStore {
    func progressSnapshot() -> ProgressSnapshot {
        let p = profile
        let identity = DeviceIdentity.current()
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        return ProgressSnapshot(guestId: identity.guestId, createdAt: Date(), rulesVersion: RulesConfig.current.version,
                                appVersion: version, name: p.name, trophies: p.trophies, bestTrophies: p.bestTrophies,
                                wins: p.wins, losses: p.losses, draws: p.draws, xp: p.xp, shards: p.shards,
                                shardsEarned: p.shardsEarned, streak: p.streak, bestStreak: p.bestStreak,
                                ladderBeaten: p.ladderBeaten, unlockedCards: p.unlockedCards, ownedBoards: p.ownedBoards,
                                ownedAvatars: p.ownedAvatars, chestTitles: p.chestTitles,
                                claimedAchievements: p.claimedAchievements, solvedPuzzles: p.solvedPuzzles.count,
                                labDone: p.labDone, pendingChests: p.chests.count,
                                deck: activeDeck.map(\.rawValue), ultimate: activeUltimate.rawValue,
                                solvedPuzzleIds: p.solvedPuzzles, chests: p.chests,
                                levelChestsGranted: p.levelChestsGranted, arenaChestsGranted: p.arenaChestsGranted,
                                puzzleChestsGranted: p.puzzleChestsGranted, roadClaimed: p.roadClaimed,
                                ladderWins: p.ladderWins, streakFreezes: p.streakFreezes,
                                selectedAvatar: p.selectedAvatar, selectedFrame: p.selectedFrame,
                                selectedTitle: p.selectedTitle, selectedSkin: p.selectedSkin,
                                tutorialSeen: p.tutorialSeen, deckTourDone: p.deckTourDone,
                                pityCounter: p.pityCounter, chestsOpened: p.chestsOpened,
                                legendaryChests: p.legendaryChests, winChestDay: p.winChestDay,
                                winChestsToday: p.winChestsToday, tutorialChestGiven: p.tutorialChestGiven,
                                seenCards: p.seenCards)
    }

    /// Spielstand aus der Server-Sicherung übernehmen (neues Gerät, Anleitung Schritt 7).
    /// Trophäen kommen immer vom Server; Einstellungen, Verlauf und Wiederholungen bleiben die dieses Geräts.
    func restore(from s: ProgressSnapshot, serverTrophies: Int, serverBest: Int) {
        var p = profile
        p.name = s.name
        p.trophies = serverTrophies
        p.bestTrophies = max(serverBest, s.bestTrophies, serverTrophies)
        p.wins = s.wins
        p.losses = s.losses
        p.draws = s.draws
        p.xp = s.xp
        p.shards = s.shards
        p.shardsEarned = s.shardsEarned
        p.streak = s.streak
        p.bestStreak = s.bestStreak
        p.ladderBeaten = s.ladderBeaten
        p.unlockedCards = s.unlockedCards.filter { CardType(rawValue: $0) != nil }
        p.ownedBoards = s.ownedBoards
        p.ownedAvatars = s.ownedAvatars
        p.chestTitles = s.chestTitles
        p.claimedAchievements = s.claimedAchievements
        p.labDone = s.labDone
        p.seenCards = p.unlockedCards
        if let v = s.solvedPuzzleIds { p.solvedPuzzles = v }
        if let v = s.chests { p.chests = v }
        if let v = s.levelChestsGranted { p.levelChestsGranted = v }
        if let v = s.arenaChestsGranted { p.arenaChestsGranted = v }
        if let v = s.puzzleChestsGranted { p.puzzleChestsGranted = v }
        if let v = s.roadClaimed { p.roadClaimed = v }
        if let v = s.ladderWins { p.ladderWins = v }
        if let v = s.streakFreezes { p.streakFreezes = v }
        p.selectedAvatar = s.selectedAvatar
        p.selectedFrame = s.selectedFrame
        p.selectedTitle = s.selectedTitle
        p.selectedSkin = s.selectedSkin
        if let v = s.tutorialSeen { p.tutorialSeen = p.tutorialSeen || v }
        if let v = s.deckTourDone { p.deckTourDone = p.deckTourDone || v }
        if let v = s.pityCounter { p.pityCounter = v }
        if let v = s.chestsOpened { p.chestsOpened = v }
        if let v = s.legendaryChests { p.legendaryChests = v }
        if let v = s.winChestDay { p.winChestDay = v }
        if let v = s.winChestsToday { p.winChestsToday = v }
        if let v = s.tutorialChestGiven { p.tutorialChestGiven = v }
        if let v = s.seenCards { p.seenCards = v }
        p.settings.deck = s.deck.compactMap(CardType.init(rawValue:))
        if let u = Ultimate(rawValue: s.ultimate) { p.settings.ultimate = u }
        profile = p
        flushSave()
    }

    /// Als JSON (für den Server oder zum Prüfen im Entwicklerbereich).
    func progressSnapshotJSON() -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(progressSnapshot()) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: Gegnersuche

struct MatchRequest: Codable, Equatable {
    var rulesVersion: Int
    var player: PlayerCard
    var deck: [String]
    var ultimate: String
    var timeControl: String
}

struct MatchFound: Equatable {
    enum Kind: String, Codable { case human, bot }
    var kind: Kind
    var opponent: PlayerCard
    /// Bei Bot-Ersatz: welcher Bot rechnet
    var botLevel: BotLevel?
    var youAreWhite: Bool
    /// Online: ID der Partie in `matches` (nil = rein lokale Partie)
    var matchId: UUID? = nil
    /// Bot-Partien zählen nicht für Bestenlisten.
    var countsForLeaderboard: Bool { kind == .human }
}

/// Gegnersuche. Die Supabase-Fassung sucht zuerst einen Menschen und fällt nach `OnlineConfig.matchmakingTimeout` auf einen Bot zurück.
protocol MatchService: AnyObject {
    func findMatch(_ request: MatchRequest) async throws -> MatchFound
    func cancel()
}

/// Offline-Fassung: sofort ein Bot passend zu den Trophäen (so spielt die App heute).
final class LocalMatchService: MatchService {
    private var cancelled = false

    func findMatch(_ request: MatchRequest) async throws -> MatchFound {
        cancelled = false
        let level = BotLevel.forTrophies(request.player.trophies)
        try Task.checkCancellation()
        if cancelled { throw CancellationError() }
        return MatchFound(kind: .bot, opponent: BotCards.card(for: level, near: request.player.trophies),
                          botLevel: level, youAreWhite: Bool.random())
    }

    func cancel() { cancelled = true }
}

/// Spielerkarten für Bot-Gegner im Online-Modus (Name, Avatar, Trophäen in der Nähe des Spielers).
enum BotCards {
    private static let first = ["Luca", "Mia", "Noah", "Lena", "Finn", "Emma", "Ben", "Hanna", "Elias", "Lara",
                                "Jonas", "Sofia", "Leon", "Clara", "Paul", "Ida", "Max", "Nora", "Tim", "Zoe"]
    private static let style = ["Rook", "Knight", "Gambit", "Castle", "Pawn", "Bishop", "Check", "Raid", "Fork", "Mate"]

    static func card(for level: BotLevel, near trophies: Int) -> PlayerCard {
        var rng = SystemRandomNumberGenerator()
        let name: String
        switch Int.random(in: 0..<3, using: &rng) {
        case 0: name = (first.randomElement() ?? "Luca") + String(Int.random(in: 7...99))
        case 1: name = (style.randomElement() ?? "Rook") + (first.randomElement() ?? "Mia")
        default: name = (first.randomElement() ?? "Lena") + "_" + (style.randomElement() ?? "Raid").lowercased()
        }
        let avatar = Avatar.allCases.randomElement()?.rawValue ?? Avatar.knight.rawValue
        let t = max(0, trophies + Int.random(in: -40...40))
        return PlayerCard(name: name, avatar: avatar, frame: nil, title: nil, trophies: t,
                          level: max(1, min(30, t / 120 + Int.random(in: 1...4))), pieceSet: nil)
    }
}

// MARK: - Konto (Online-Phase 1)

/// Was der Server über den Spieler führt (Tabelle `progress`). Phase 1: nur Trophäen und Online-Bilanz sind
/// maßgeblich; alles andere bleibt auf dem Gerät und wird als `snapshot` gesichert.
struct ServerProgress: Codable, Equatable {
    var trophies: Int
    var bestTrophies: Int
    var onlineWins: Int
    var onlineLosses: Int
    var onlineDraws: Int
    /// Letzte Sicherung des lokalen Fortschritts (zum Wiederherstellen auf einem neuen Gerät)
    var snapshot: ProgressSnapshot?

    enum CodingKeys: String, CodingKey {
        case trophies, snapshot
        case bestTrophies = "best_trophies", onlineWins = "online_wins", onlineLosses = "online_losses", onlineDraws = "online_draws"
    }

    init(trophies: Int, bestTrophies: Int, onlineWins: Int, onlineLosses: Int, onlineDraws: Int, snapshot: ProgressSnapshot?) {
        self.trophies = trophies
        self.bestTrophies = bestTrophies
        self.onlineWins = onlineWins
        self.onlineLosses = onlineLosses
        self.onlineDraws = onlineDraws
        self.snapshot = snapshot
    }

    /// Eine Sicherung aus einer älteren App-Fassung darf das Laden der Trophäen nicht verhindern.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trophies = try c.decode(Int.self, forKey: .trophies)
        bestTrophies = try c.decodeIfPresent(Int.self, forKey: .bestTrophies) ?? trophies
        onlineWins = try c.decodeIfPresent(Int.self, forKey: .onlineWins) ?? 0
        onlineLosses = try c.decodeIfPresent(Int.self, forKey: .onlineLosses) ?? 0
        onlineDraws = try c.decodeIfPresent(Int.self, forKey: .onlineDraws) ?? 0
        snapshot = try? c.decodeIfPresent(ProgressSnapshot.self, forKey: .snapshot)
    }
}

enum AccountState: Equatable {
    /// Noch kein Konto – alles lokal
    case guest
    /// Angemeldet (auch anonym, siehe Anleitung Entscheidung E11)
    case signedIn(userId: String, anonymous: Bool)
}

enum AccountSetup: Equatable {
    /// Neues Konto: Gast-Fortschritt wurde übernommen
    case created(ServerProgress)
    /// Konto gab es schon (anderes Gerät): App bietet „Fortschritt wiederherstellen“ an
    case existing(ServerProgress)
}

/// Anmeldung und Fortschritt. Die Supabase-Fassung nutzt supabase-swift (Auth + RPC `setup_account`, `backup_progress`).
protocol AccountService: AnyObject {
    var state: AccountState { get }
    /// Ohne Registrierung online spielen (Supabase Anonymous Sign-In) – Entscheidung E11
    func signInAnonymously() async throws -> AccountSetup
    /// Sign in with Apple: `identityToken` und `nonce` aus `ASAuthorizationAppleIDCredential`
    func signInWithApple(idToken: String, nonce: String) async throws -> AccountSetup
    func backup(_ snapshot: ProgressSnapshot) async throws
    func fetchProgress() async throws -> ServerProgress
    func signOut() async throws
    /// Apple-Pflicht: Konto und alle Daten löschen (Edge Function `delete-account`)
    func deleteAccount() async throws
}

// MARK: - Online-Partie

/// Alles, was die App zum Start einer Online-Partie braucht (aus `matches`).
struct OnlineMatchInfo: Equatable {
    var matchId: UUID
    var isBot: Bool
    var botLevel: BotLevel?
    var myColor: PlayerColor
    var opponent: PlayerCard
    var timeControl: TimeControl
    /// Decks, Ultimates und bisherige Aktionen – `record.replay()` baut die Stellung (auch beim Wiederverbinden)
    var record: MatchRecord
    /// Restzeiten in Sekunden, schon um die seit dem letzten Zug verstrichene Zeit gekürzt.
    var clockWhite: Double
    var clockBlack: Double
    /// Noch im Duell-Intro: die Server-Uhr hat noch nicht begonnen.
    var showIntro: Bool
}

/// Was während einer Online-Partie vom Server kommt (Realtime auf `match_actions` und `matches`).
enum OnlineMatchEvent: Equatable {
    /// Neue Aktion (auch die eigene als Bestätigung). `ply` = Index in `record.actions`.
    case action(ply: Int, code: String, clockMs: Int?)
    /// Uhrenstand nach jeder Aktion (Server ist maßgeblich; die App tickt nur die Anzeige herunter)
    case clocks(whiteMs: Int, blackMs: Int, turn: PlayerColor)
    case drawOffered(by: PlayerColor)
    case drawOfferCleared
    /// Partie vorbei: Ergebnis-Code (mate, timeout, resigned, draw_agreed, aborted, …), Sieger (nil = Remis/Abbruch)
    /// und die Trophäen-Änderung des eigenen Spielers
    case finished(result: String, winner: PlayerColor?, myTrophyDelta: Int?)
    /// Gegner verbunden / weg (Realtime Presence) – nur Anzeige, die Uhr läuft weiter
    case opponentConnected(Bool)
}

enum OnlineMatchError: Error, Equatable {
    /// Lokale Zählung weicht ab – Aktionen neu laden (`fetchActions`) und Stellung neu aufbauen
    case outOfSync(actionCount: Int)
    case notYourTurn
    case illegalAction
    case timeout
    case notActive
    case network
}

/// Eine laufende Online-Partie gegen einen Menschen. (Bot-Ersatz läuft lokal und meldet nur das Ergebnis.)
protocol OnlineMatchSession: AnyObject {
    var info: OnlineMatchInfo { get }
    var events: AsyncStream<OnlineMatchEvent> { get }
    /// Eigene Aktion senden; `ply` = Anzahl der bisherigen Aktionen
    func submit(_ code: String, ply: Int) async throws
    func resign() async throws
    func offerDraw() async throws
    func answerDraw(accept: Bool) async throws
    /// Eigene oder gegnerische Uhr bei 0:00 – der Server prüft und beendet die Partie
    func claimTimeout() async throws
    /// Alle bisherigen Aktionen (Wiederverbinden, nach outOfSync)
    func fetchActions() async throws -> [String]
    func close()
}

/// Wie eine Bot-Ersatz-Partie endete (Feld `outcome` von `finish-bot-match`)
enum BotMatchOutcome: String {
    /// Ergebnis steht in der Stellung (Matt, Patt, 50 Züge, Wiederholung)
    case completed = "final"
    case resigned
    case timeout
}

/// Laufende Bot-Ersatz-Partie: lokal wie `.bot`, aber mit Server-Partie-ID (Lebenszeichen und Wertung).
struct OnlineBotPlay: Equatable {
    var matchId: UUID
    var opponent: PlayerCard
}

/// Ergebnis einer Bot-Ersatz-Partie an den Server melden (Edge Function `finish-bot-match`).
protocol BotMatchReporter: AnyObject {
    /// Gibt die Trophäen-Änderung zurück (Server rechnet, nicht die App).
    func finish(matchId: UUID, actions: [String], outcome: BotMatchOutcome, humanIsWhite: Bool) async throws -> Int
}

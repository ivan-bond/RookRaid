import Foundation
import SwiftUI

// MARK: - Dateispeicher (JSON im Application-Support-Ordner der App)

enum Storage {
    /// Ordner einmal ermitteln (früher bei jedem Speichern mit Dateisystem-Abfrage).
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("GambitArena", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }()

    /// Kodieren und Schreiben laufen im Hintergrund, in fester Reihenfolge – der Hauptthread (Animationen) bleibt frei.
    private static let queue = DispatchQueue(label: "RookRaid.storage", qos: .utility)

    static func url(_ name: String) -> URL { directory.appendingPathComponent(name + ".json") }

    static func save<T: Encodable>(_ value: T, as name: String) {
        queue.async { write(value, name) }
    }

    /// Sofort und abgeschlossen speichern (z. B. wenn die App in den Hintergrund geht).
    static func saveNow<T: Encodable>(_ value: T, as name: String) {
        queue.sync { write(value, name) }
    }

    private static func write<T: Encodable>(_ value: T, _ name: String) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url(name), options: [.atomic])
        } catch {
            print("Speichern fehlgeschlagen (\(name)): \(error)")
        }
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        // Wartet auf ausstehende Schreibvorgänge, damit nie ein veralteter Stand gelesen wird.
        return queue.sync { () -> T? in
            guard let data = try? Data(contentsOf: url(name)) else { return nil }
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                print("Laden fehlgeschlagen (\(name)): \(error)")
                return nil
            }
        }
    }

    static func delete(_ name: String) {
        queue.async { try? FileManager.default.removeItem(at: url(name)) }
    }
}

// MARK: - Arenen

struct Arena: Identifiable {
    let number: Int
    let name: String
    let trophies: Int
    let mechanic: String
    let icon: String

    var id: Int { number }

    static var all: [Arena] { [
        Arena(number: 1, name: L("Trainingsgelände"), trophies: 0, mechanic: L("Ultimates Meteor und Festung"), icon: "figure.walk"),
        Arena(number: 2, name: L("Kasernenhof"), trophies: 90, mechanic: L("Eiszeit, Krönung + Magische Truhe"), icon: "shield.lefthalf.filled"),
        Arena(number: 3, name: L("Thronarena"), trophies: 240, mechanic: L("Wiedergeburt + Legendäre Truhe"), icon: "crown.fill"),
        Arena(number: 4, name: L("Sturmfeste"), trophies: 600, mechanic: L("Magische Truhe + Lava-Brett in Reichweite"), icon: "cloud.bolt.fill"),
        Arena(number: 5, name: L("Drachenhort"), trophies: 1200, mechanic: L("Legendäre Truhe + Mitternachts-Brett"), icon: "flame.fill"),
        Arena(number: 6, name: L("Königsgipfel"), trophies: 2100, mechanic: L("Legendäre Truhe · Gegner: Sphinx und Turmkönigin"), icon: "mountain.2.fill")
    ] }

    static func forTrophies(_ t: Int) -> Arena {
        all.last { t >= $0.trophies } ?? all[0]
    }

    var next: Arena? { Arena.all.first { $0.number == number + 1 } }
    var ultimates: [Ultimate] { Ultimate.allCases.filter { $0.arena == number } }
}

// MARK: - Einstellungen & Profil

enum BoardTheme: String, Codable, CaseIterable, Identifiable {
    case green, brown, blue, purple
    /// Sammelbretter: aus Magischen und Legendären Truhen oder für Splitter.
    case lava, emerald, midnight
    var id: String { rawValue }
    var name: String {
        switch self {
        case .green: return L("Rook Raid")
        case .brown: return L("Holz")
        case .blue: return L("Eis")
        case .purple: return L("Arkan")
        case .lava: return L("Lava")
        case .emerald: return L("Smaragd")
        case .midnight: return L("Mitternacht")
        }
    }
    var isCollectible: Bool { self == .lava || self == .emerald || self == .midnight }
    static let collectiblePrice = 300
}

enum TimeControl: String, Codable, CaseIterable, Identifiable {
    case none, blitz3, rapid5, rapid10
    /// 5 | 0 – die einzige Zeitkontrolle online (Entscheidung E3); offline nicht in der Auswahl.
    case blitz5
    var id: String { rawValue }

    /// Auswahl in den Spiel-Einstellungen (offline)
    static var offlineChoices: [TimeControl] { [.none, .blitz3, .rapid5, .rapid10] }

    var name: String {
        switch self {
        case .none: return L("Ohne Uhr")
        case .blitz3: return "3 | 2"
        case .rapid5: return "5 | 3"
        case .rapid10: return "10 | 5"
        case .blitz5: return "5 | 0"
        }
    }
    var seconds: Double {
        switch self {
        case .none: return 0
        case .blitz3: return 180
        case .rapid5: return 300
        case .rapid10: return 600
        case .blitz5: return 300
        }
    }
    var increment: Double {
        switch self {
        case .none: return 0
        case .blitz3: return 2
        case .rapid5: return 3
        case .rapid10: return 5
        case .blitz5: return 0
        }
    }
    var isTimed: Bool { self != .none }
}

struct Settings: Codable, Equatable {
    var haptics = true
    var sound = true
    var hints = true
    var boardTheme: BoardTheme = .green
    var showCoordinates = true
    var unlockAll = false
    var timeControl: TimeControl = .blitz3
    var botLevel: BotLevel = .medium
    var playAsWhite = true
    var ultimate: Ultimate = .meteor
    /// Die vier Karten des eigenen Decks (Deck-Editor).
    /// Kampfdeck (0–4 Karten). Neue Spieler starten leer und stellen ihr erstes Deck selbst zusammen (v0.9.31).
    var deck: [CardType] = []
    /// Gebiets-Schleier auf dem Brett anzeigen.
    var showTerritory = true
    /// Bots spielen mit ihrem eigenen Figurenset.
    var botSkins = true
    /// App-Sprache: beim ersten Start die Systemsprache, danach die Wahl in den Einstellungen.
    var language: AppLanguage = AppLanguage.system

    /// Testmodus „alle Karten frei“ gilt nur in Debug-Builds (v0.9.26) – in der App-Store-Fassung und online nie.
    var testModeActive: Bool {
        #if DEBUG
        return unlockAll
        #else
        return false
        #endif
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        sound = try c.decodeIfPresent(Bool.self, forKey: .sound) ?? d.sound
        hints = try c.decodeIfPresent(Bool.self, forKey: .hints) ?? d.hints
        boardTheme = try c.decodeIfPresent(BoardTheme.self, forKey: .boardTheme) ?? d.boardTheme
        showCoordinates = try c.decodeIfPresent(Bool.self, forKey: .showCoordinates) ?? d.showCoordinates
        unlockAll = try c.decodeIfPresent(Bool.self, forKey: .unlockAll) ?? d.unlockAll
        timeControl = try c.decodeIfPresent(TimeControl.self, forKey: .timeControl) ?? d.timeControl
        botLevel = try c.decodeIfPresent(BotLevel.self, forKey: .botLevel) ?? d.botLevel
        playAsWhite = try c.decodeIfPresent(Bool.self, forKey: .playAsWhite) ?? d.playAsWhite
        let rawUltimate = (try? c.decodeIfPresent(String.self, forKey: .ultimate)) ?? nil
        ultimate = rawUltimate.flatMap { Ultimate(rawValue: $0) } ?? d.ultimate
        showTerritory = try c.decodeIfPresent(Bool.self, forKey: .showTerritory) ?? d.showTerritory
        botSkins = try c.decodeIfPresent(Bool.self, forKey: .botSkins) ?? d.botSkins
        language = (try? c.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? nil ?? d.language
        // Deck tolerant laden: unbekannte Karten überspringen, Doppelte entfernen
        // Seit v0.9.31 darf das Deck 0–4 Karten haben. Sehr alte Profile ohne gespeichertes Deck behalten die Startkarten.
        if let rawDeck = (try? c.decodeIfPresent([String].self, forKey: .deck)) ?? nil {
            var cards: [CardType] = []
            for raw in rawDeck { if let card = CardType(rawValue: raw), !cards.contains(card) { cards.append(card) } }
            deck = Array(cards.prefix(PlayerDeck.size))
        } else {
            deck = DeckPreset.starter.cards
        }
    }
}

enum GameResultKind: String, Codable {
    case win, loss, draw

    var label: String {
        switch self {
        case .win: return L("Sieg")
        case .loss: return L("Niederlage")
        case .draw: return L("Remis")
        }
    }
}

struct GameRecord: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var opponent: String
    var result: GameResultKind
    var reason: String
    var moves: Int
    var trophyDelta: Int
    var cardsPlayed: Int
    var replayID: UUID? = nil
}

struct Profile: Codable {
    var name = L("Du")
    var trophies = 0
    var bestTrophies = 0
    var wins = 0
    var losses = 0
    var draws = 0
    /// Datenformat des Profils (siehe SaveFormat).
    var dataVersion = SaveFormat.current
    var settings = Settings()
    var history: [GameRecord] = []
    var tutorialSeen = false

    // Puzzles & XP
    var xp = 0
    var solvedPuzzles: [String] = []
    var dailyBonusDay: String? = nil

    // Tägliche Flammen
    var streak = 0
    var bestStreak = 0
    var lastStreakDay: String? = nil
    var activeDays: [String] = []
    /// Tag, an dem die Tagestruhe (alle 3 Tagesziele) zuletzt geöffnet wurde.
    var dailyChestDay: String? = nil

    // Bot-Leiter (offline): Anzahl der der Reihe nach besiegten Bots und Siege je Bot
    var ladderBeaten = 0
    var ladderWins: [String: Int] = [:]

    // Truhen & Freischaltungen (v0.9.6)
    /// Ungeöffnete Truhen im Lager.
    var chests: [Chest] = []
    /// Splitter: kommen aus Truhen, kaufen gesperrte Karten und Sammelbretter.
    var shards = 0
    /// Freigeschaltete Karten (Startkarten zählen immer).
    var unlockedCards: [String] = []
    var ownedBoards: [String] = []
    /// Truhen ohne neue Karte in Folge (Glücksschutz).
    var pityCounter = 0
    var chestsOpened = 0
    var legendaryChests = 0
    /// Höchster Level, für den die Level-Truhe schon vergeben wurde.
    var levelChestsGranted = 1
    var arenaChestsGranted = 1
    var puzzleChestsGranted = 0
    var winChestDay: String? = nil
    var winChestsToday = 0
    var tutorialChestGiven = false

    // Puzzle-Serie (ohne Fehler und Hinweis) und Puzzle-Rausch
    var puzzleStreak = 0
    var bestPuzzleStreak = 0
    var rushBest = 0
    var rushPlayed = 0

    // Trophäenpfad: Belohnungen, die schon abgeholt wurden (Trophäenwerte der Stationen)
    var roadClaimed: [Int] = []

    // Profil: gewählter Titel und Rahmen (IDs der Erfolge), Karten, die man schon gesehen hat
    var selectedTitle: String? = nil
    var selectedFrame: String? = nil
    var seenCards: [String] = []

    // Flammen: Flammenschutz (max. 2), eingefrorene Tage, Hinweis nach Rettung, erreichte Meilensteine
    var streakFreezes = 1
    var frozenDays: [String] = []
    var freezeNotice: Int? = nil
    var streakMilestones: [Int] = []

    // Splitter: insgesamt verdient, Sparziel, Tagesangebote (Tag, gekaufte Angebote), Laden-Rahmen
    var shardsEarned = 0
    var shardGoal: String? = nil
    var shopDay: String? = nil
    var shopBought: [String] = []
    var shopFrames: [String] = []

    // Erfolge: abgeholte Erfolge und Zähler, die der Verlauf (nur 50 Partien) nicht hergibt
    var claimedAchievements: [String] = []
    var cardsByType: [String: Int] = [:]
    var ultimatesUsed = 0
    var bonusActions = 0
    var tacticBonuses = 0
    var mateWins = 0
    var winStreak = 0
    var bestWinStreak = 0
    var cardsBought = 0

    // Kartenschule (v0.9.26): Karten und Ultimates, die im Erklärmodus ausprobiert wurden
    var labDone: [String] = []
    /// Rockys Deck-Werkstatt (v0.9.32) gesehen oder beendet – danach startet sie nicht mehr von selbst.
    var deckTourDone = false

    // Kosmetik: Avatare (Besitz und Auswahl) und Titel aus Truhen
    var ownedAvatars: [String] = []
    var selectedAvatar: String? = nil
    var chestTitles: [String] = []
    /// Eigenes Figurenset: das Set eines besiegten Bots (BotLevel.rawValue), nil = Standardfiguren.
    var selectedSkin: String? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        trophies = try c.decodeIfPresent(Int.self, forKey: .trophies) ?? d.trophies
        bestTrophies = try c.decodeIfPresent(Int.self, forKey: .bestTrophies) ?? d.bestTrophies
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? d.wins
        losses = try c.decodeIfPresent(Int.self, forKey: .losses) ?? d.losses
        draws = try c.decodeIfPresent(Int.self, forKey: .draws) ?? d.draws
        dataVersion = try c.decodeIfPresent(Int.self, forKey: .dataVersion) ?? 5
        // Tolerant laden: Karten aus älteren Versionen, die es nicht mehr gibt, werden ignoriert.
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? d.settings
        history = (try? c.decodeIfPresent([GameRecord].self, forKey: .history)) ?? nil ?? d.history
        tutorialSeen = try c.decodeIfPresent(Bool.self, forKey: .tutorialSeen) ?? d.tutorialSeen
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? d.xp
        solvedPuzzles = try c.decodeIfPresent([String].self, forKey: .solvedPuzzles) ?? d.solvedPuzzles
        dailyBonusDay = try c.decodeIfPresent(String.self, forKey: .dailyBonusDay) ?? d.dailyBonusDay
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? d.streak
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? d.bestStreak
        lastStreakDay = try c.decodeIfPresent(String.self, forKey: .lastStreakDay) ?? d.lastStreakDay
        activeDays = try c.decodeIfPresent([String].self, forKey: .activeDays) ?? d.activeDays
        dailyChestDay = try c.decodeIfPresent(String.self, forKey: .dailyChestDay)
        ladderBeaten = try c.decodeIfPresent(Int.self, forKey: .ladderBeaten) ?? 0
        ladderWins = try c.decodeIfPresent([String: Int].self, forKey: .ladderWins) ?? [:]
        chests = (try? c.decodeIfPresent([Chest].self, forKey: .chests)) ?? nil ?? []
        shards = try c.decodeIfPresent(Int.self, forKey: .shards) ?? 0
        ownedBoards = try c.decodeIfPresent([String].self, forKey: .ownedBoards) ?? []
        pityCounter = try c.decodeIfPresent(Int.self, forKey: .pityCounter) ?? 0
        chestsOpened = try c.decodeIfPresent(Int.self, forKey: .chestsOpened) ?? 0
        legendaryChests = try c.decodeIfPresent(Int.self, forKey: .legendaryChests) ?? 0
        winChestDay = try c.decodeIfPresent(String.self, forKey: .winChestDay)
        winChestsToday = try c.decodeIfPresent(Int.self, forKey: .winChestsToday) ?? 0
        puzzleStreak = try c.decodeIfPresent(Int.self, forKey: .puzzleStreak) ?? 0
        bestPuzzleStreak = try c.decodeIfPresent(Int.self, forKey: .bestPuzzleStreak) ?? 0
        rushBest = try c.decodeIfPresent(Int.self, forKey: .rushBest) ?? 0
        rushPlayed = try c.decodeIfPresent(Int.self, forKey: .rushPlayed) ?? 0
        roadClaimed = try c.decodeIfPresent([Int].self, forKey: .roadClaimed) ?? []
        selectedTitle = try c.decodeIfPresent(String.self, forKey: .selectedTitle)
        selectedFrame = try c.decodeIfPresent(String.self, forKey: .selectedFrame)

        if let cards = try c.decodeIfPresent([String].self, forKey: .unlockedCards) {
            unlockedCards = cards
            levelChestsGranted = try c.decodeIfPresent(Int.self, forKey: .levelChestsGranted) ?? 1
            arenaChestsGranted = try c.decodeIfPresent(Int.self, forKey: .arenaChestsGranted) ?? 1
            puzzleChestsGranted = try c.decodeIfPresent(Int.self, forKey: .puzzleChestsGranted) ?? 0
            tutorialChestGiven = try c.decodeIfPresent(Bool.self, forKey: .tutorialChestGiven) ?? false
        } else {
            // Profil aus v0.9.5 oder älter: Niemand verliert Karten. Freigeschaltet ist, was bisher
            // per Level offen war; vergangene Level-, Arena- und Puzzle-Truhen werden nicht nachgeliefert.
            // Als Dankeschön liegt eine Goldtruhe bereit.
            // Level wie ProfileStore.level(forXP:) – hier ohne MainActor berechnet
            var lvl = 1
            while 25 * lvl * (lvl + 1) <= xp { lvl += 1 }
            let legacy: [(CardType, Int)] = [(.reinforce, 1), (.knighting, 1), (.bulwark, 1), (.revive, 1), (.advance, 2),
                                             (.sacrifice, 3), (.swap, 4), (.focus, 5), (.drain, 6), (.bishopize, 7)]
            unlockedCards = legacy.filter { $0.1 <= lvl }.map { $0.0.rawValue }
            levelChestsGranted = lvl
            arenaChestsGranted = Arena.forTrophies(trophies).number
            puzzleChestsGranted = solvedPuzzles.count / 5
            tutorialChestGiven = tutorialSeen
            if tutorialSeen {
                chests.append(Chest(rarity: .gold, source: .welcome))
            }
        }
        // Ältere Profile: alle bisher freien Karten gelten als gesehen (kein „NEU“-Gewitter)
        seenCards = try c.decodeIfPresent([String].self, forKey: .seenCards) ?? unlockedCards
        streakFreezes = try c.decodeIfPresent(Int.self, forKey: .streakFreezes) ?? 1
        frozenDays = try c.decodeIfPresent([String].self, forKey: .frozenDays) ?? []
        freezeNotice = try c.decodeIfPresent(Int.self, forKey: .freezeNotice)
        streakMilestones = try c.decodeIfPresent([Int].self, forKey: .streakMilestones) ?? []
        shardsEarned = try c.decodeIfPresent(Int.self, forKey: .shardsEarned) ?? shards
        shardGoal = try c.decodeIfPresent(String.self, forKey: .shardGoal)
        shopDay = try c.decodeIfPresent(String.self, forKey: .shopDay)
        shopBought = try c.decodeIfPresent([String].self, forKey: .shopBought) ?? []
        shopFrames = try c.decodeIfPresent([String].self, forKey: .shopFrames) ?? []
        claimedAchievements = try c.decodeIfPresent([String].self, forKey: .claimedAchievements) ?? []
        cardsByType = try c.decodeIfPresent([String: Int].self, forKey: .cardsByType) ?? [:]
        ultimatesUsed = try c.decodeIfPresent(Int.self, forKey: .ultimatesUsed) ?? 0
        bonusActions = try c.decodeIfPresent(Int.self, forKey: .bonusActions) ?? 0
        tacticBonuses = try c.decodeIfPresent(Int.self, forKey: .tacticBonuses) ?? 0
        mateWins = try c.decodeIfPresent(Int.self, forKey: .mateWins)
            ?? history.filter { $0.result == .win && $0.reason.contains("Schachmatt") }.count
        winStreak = try c.decodeIfPresent(Int.self, forKey: .winStreak) ?? 0
        bestWinStreak = try c.decodeIfPresent(Int.self, forKey: .bestWinStreak) ?? 0
        cardsBought = try c.decodeIfPresent(Int.self, forKey: .cardsBought) ?? 0
        ownedAvatars = try c.decodeIfPresent([String].self, forKey: .ownedAvatars) ?? []
        selectedAvatar = try c.decodeIfPresent(String.self, forKey: .selectedAvatar)
        selectedSkin = try c.decodeIfPresent(String.self, forKey: .selectedSkin)
        chestTitles = try c.decodeIfPresent([String].self, forKey: .chestTitles) ?? []
        labDone = try c.decodeIfPresent([String].self, forKey: .labDone) ?? []
        // Ältere Profile: Wer schon ein volles Deck hat, braucht die Werkstatt-Tour nicht (startbar über Rocky im Deck-Tab).
        deckTourDone = try c.decodeIfPresent(Bool.self, forKey: .deckTourDone)
            ?? (tutorialSeen && settings.deck.count >= PlayerDeck.size)
    }

    var gamesPlayed: Int { wins + losses + draws }
    var winRate: Double { gamesPlayed == 0 ? 0 : Double(wins) / Double(gamesPlayed) }
}

// MARK: - Laufende Partie

enum GameMode: Codable, Equatable {
    /// „Kampf!“: Gegner passend zu den Trophäen, gewertet
    case bot(BotLevel)
    /// Zu zweit an einem Gerät: ohne Trophäen
    case hotSeat
    /// Geführte erste Partie
    case tutorial
    /// Bot-Leiter: Charaktere nacheinander besiegen, XP statt Trophäen
    case ladder(BotLevel)
    /// „Deck testen“: Übungspartie ohne Trophäen, XP, Truhen und Statistik
    case practice(BotLevel)
    /// Mensch gegen Mensch. Die ID ist die Zeile in `matches`.
    case online(UUID)

    var isBot: Bool {
        switch self {
        case .bot, .ladder, .practice: return true
        default: return false
        }
    }

    var isOnline: Bool {
        if case .online = self { return true }
        return false
    }

    var isPractice: Bool {
        if case .practice = self { return true }
        return false
    }

    /// „Kampf!“ und Online-Partien zählen für die Trophäen. Online verbucht sie der Server.
    var isRated: Bool {
        switch self {
        case .bot, .online: return true
        default: return false
        }
    }

    var isLadder: Bool {
        if case .ladder = self { return true }
        return false
    }

    var botLevel: BotLevel? {
        switch self {
        case .bot(let l), .ladder(let l), .practice(let l): return l
        default: return nil
        }
    }
}

/// Was in einem Eintrag der Zugliste passiert ist – genug, um die Partie nachzuspielen.
enum ReplayAction: Codable, Equatable {
    case move(Move)
    case card(CardType, Square?)
    case ultimate(Square?)
}

struct MoveEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var ply: Int
    var color: PlayerColor
    var text: String
    var card: CardType?
    var action: ReplayAction? = nil
    /// Mana nach der Aktion: [Weiß, Schwarz].
    var manaAfter: [Int]? = nil
}

/// Versionsnummern der gespeicherten Daten. Bei Formatänderungen hochzählen und `migrate` erweitern.
enum SaveFormat {
    /// v5: erste gespeicherte Partien · v9: Bonusaktionen, Remisregeln, Umwandlungswahl, Zugdaten für Wiedergabe
    /// · v10: feste Decks mit 4 Karten und Abklingzeit.
    static let current = 13
    static let gameFile = "current_game"
    static let legacyGameFiles = ["current_game_v5"]
}

struct SavedGame: Codable {
    var version: Int = SaveFormat.current
    var state: GameState
    var mode: GameMode
    var humanColor: PlayerColor
    var timeControl: TimeControl
    var clocks: [PlayerColor: Double]
    var moves: [MoveEntry]
    var cardsPlayedByHuman: Int
    var startedAt: Date
    var initialState: GameState? = nil

    init(state: GameState, mode: GameMode, humanColor: PlayerColor, timeControl: TimeControl,
         clocks: [PlayerColor: Double], moves: [MoveEntry], cardsPlayedByHuman: Int, startedAt: Date,
         initialState: GameState?) {
        self.state = state
        self.mode = mode
        self.humanColor = humanColor
        self.timeControl = timeControl
        self.clocks = clocks
        self.moves = moves
        self.cardsPlayedByHuman = cardsPlayedByHuman
        self.startedAt = startedAt
        self.initialState = initialState
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 5
        state = try c.decode(GameState.self, forKey: .state)
        mode = try c.decode(GameMode.self, forKey: .mode)
        humanColor = try c.decode(PlayerColor.self, forKey: .humanColor)
        timeControl = try c.decodeIfPresent(TimeControl.self, forKey: .timeControl) ?? .none
        clocks = try c.decodeIfPresent([PlayerColor: Double].self, forKey: .clocks) ?? [:]
        moves = (try? c.decodeIfPresent([MoveEntry].self, forKey: .moves)) ?? nil ?? []
        cardsPlayedByHuman = try c.decodeIfPresent(Int.self, forKey: .cardsPlayedByHuman) ?? 0
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        initialState = try? c.decodeIfPresent(GameState.self, forKey: .initialState)
    }

    /// Bringt ältere Spielstände auf das aktuelle Format.
    mutating func migrate() {
        if version < 9 {
            // Ab v9 gelten Bonusaktionen und Remisregeln; ältere Stände starten mit leerer Historie.
            state.bonusActionUsed = false
            state.halfmoveClock = 0
            state.positionHistory = [state.positionKey()]
        }
        if version < 10 {
            // Ab v10 wird nicht mehr nachgezogen: Die aktuelle Hand wird zum festen Deck.
            state.decks = state.decks.mapValues { PlayerDeck(cards: $0.hand) }
        }
        version = SaveFormat.current
    }
}

/// Eine abgeschlossene Partie zum Nachspielen.
struct GameReplay: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var title: String
    var subtitle: String
    var humanColor: PlayerColor
    var initial: GameState
    var entries: [MoveEntry]
}

// MARK: - Profil-Store

@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var profile: Profile {
        didSet {
            achievementsCache = nil
            if profile.settings.language != oldValue.settings.language {
                Localizer.shared.set(profile.settings.language)
            }
            scheduleProfileSave()
            if progressReady { scheduleServerProgressBackup(comparedTo: oldValue) }
        }
    }
    /// Viele Änderungen kurz hintereinander (ein Zug, eine Truhe) werden zu einem Speichervorgang gebündelt.
    private var saveTask: Task<Void, Never>?
    /// Erst nach dem Laden: sonst würde der Start schon den Server anfassen, bevor das Profil steht.
    private var progressReady = false
    private var progressBackupTask: Task<Void, Never>?
    /// Zwischenspeicher für `achievements` (wird bei jeder Profiländerung verworfen).
    var achievementsCache: [Achievement]?
    @Published private(set) var hasSavedGame: Bool = false

    @Published private(set) var replays: [GameReplay] = []

    private init() {
        let stored = Storage.load(Profile.self, from: "profile")
        var loaded = stored ?? Profile()
        Localizer.shared.set(loaded.settings.language)
        if stored == nil { loaded.name = L("Du") }
        if loaded.dataVersion < 13 {
            // v13: zwölf statt acht Bots. Leiter-Fortschritt und Leiter-Erfolge auf die neue Reihenfolge abbilden –
            // neue Bots unterhalb des erreichten Fortschritts gelten als geschafft.
            let oldOrder: [BotLevel] = [.easy, .apprentice, .medium, .knight, .tactician, .baron, .hard, .queen]
            let k = min(loaded.ladderBeaten, oldOrder.count)
            if k > 0 { loaded.ladderBeaten = oldOrder[k - 1].tier }
            loaded.claimedAchievements = loaded.claimedAchievements.map { id in
                guard id.hasPrefix("ladder"), let n = Int(id.dropFirst(6)), (1...oldOrder.count).contains(n) else { return id }
                return "ladder-" + oldOrder[n - 1].rawValue
            }
        }
        if loaded.dataVersion < SaveFormat.current {
            loaded.dataVersion = SaveFormat.current   // Profilfelder werden tolerant geladen
        }
        profile = loaded
        replays = Storage.load([GameReplay].self, from: "replays") ?? []
        // Alte Spielstand-Dateien in das neue, versionierte Format übernehmen
        for legacy in SaveFormat.legacyGameFiles where FileManager.default.fileExists(atPath: Storage.url(legacy).path) {
            if var old = Storage.load(SavedGame.self, from: legacy) {
                old.migrate()
                Storage.save(old, as: SaveFormat.gameFile)
            }
            Storage.delete(legacy)
        }
        hasSavedGame = FileManager.default.fileExists(atPath: Storage.url(SaveFormat.gameFile).path)
        progressReady = true
    }

    /// Karten, XP und Truhen auf dem Konto sichern. Mehrere Änderungen hintereinander (Truhe öffnen) werden eine Meldung.
    private func scheduleServerProgressBackup(comparedTo old: Profile) {
        let cards = old.unlockedCards != profile.unlockedCards || old.seenCards != profile.seenCards
        let xp = old.xp != profile.xp
        let chests = old.chests != profile.chests
            || old.chestsOpened != profile.chestsOpened
            || old.pityCounter != profile.pityCounter
            || old.legendaryChests != profile.legendaryChests
            || old.levelChestsGranted != profile.levelChestsGranted
            || old.arenaChestsGranted != profile.arenaChestsGranted
            || old.puzzleChestsGranted != profile.puzzleChestsGranted
            || old.winChestDay != profile.winChestDay
            || old.winChestsToday != profile.winChestsToday
            || old.tutorialChestGiven != profile.tutorialChestGiven
        guard cards || xp || chests else { return }
        progressBackupTask?.cancel()
        progressBackupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            OnlineAccount.shared.backupQuietly()
        }
    }

    var settings: Settings {
        get { profile.settings }
        set { profile.settings = newValue }
    }

    var arena: Arena { Arena.forTrophies(profile.trophies) }

    func isUnlocked(_ ultimate: Ultimate) -> Bool {
        profile.settings.testModeActive || ultimate.arena <= arena.number
    }

    var unlockedUltimates: [Ultimate] { Ultimate.allCases.filter { isUnlocked($0) } }

    /// Gewählte Ultimate – fällt auf Meteor zurück, falls sie (noch) gesperrt ist.
    var activeUltimate: Ultimate {
        isUnlocked(profile.settings.ultimate) ? profile.settings.ultimate : .meteor
    }

    // MARK: Deck

    /// Startkarten gibt es sofort, alle anderen kommen aus Truhen oder werden mit Splittern gekauft.
    func isUnlocked(_ card: CardType) -> Bool {
        profile.settings.testModeActive || card.tier == .starter || profile.unlockedCards.contains(card.rawValue)
    }

    var unlockedCards: [CardType] { CardType.allCases.filter { isUnlocked($0) } }

    /// Frisch aus Truhen gezogene Karten, die im Deck-Tab noch nicht angesehen wurden („NEU“).
    func isNew(_ card: CardType) -> Bool {
        card.tier != .starter && profile.unlockedCards.contains(card.rawValue) && !profile.seenCards.contains(card.rawValue)
    }

    var newCardCount: Int { CardType.allCases.filter { isNew($0) }.count }

    func markSeen(_ card: CardType) {
        guard isNew(card) else { return }
        profile.seenCards.append(card.rawValue)
    }

    func markAllSeen() {
        for card in CardType.allCases where isNew(card) { profile.seenCards.append(card.rawValue) }
    }

    /// Das spielbare Deck (0–4 Karten): nur freigeschaltete Karten, jede einmal. Seit v0.9.31 wird nichts mehr
    /// automatisch aufgefüllt – leere Plätze bleiben leer, bis der Spieler sie selbst belegt.
    var activeDeck: [CardType] {
        var deck: [CardType] = []
        for card in profile.settings.deck where isUnlocked(card) && !deck.contains(card) { deck.append(card) }
        return Array(deck.prefix(PlayerDeck.size))
    }

    var deckIsFull: Bool { activeDeck.count >= PlayerDeck.size }

    /// Nach der ersten Partie erklärt Rocky einmal, wie man ein Deck baut.
    var needsDeckTour: Bool { profile.tutorialSeen && !profile.deckTourDone }

    func setDeck(_ cards: [CardType]) {
        guard cards.count <= PlayerDeck.size, Set(cards).count == cards.count else { return }
        profile.settings.deck = cards
    }

    /// Karte aus dem Deck nehmen (der Platz wird frei).
    func removeFromDeck(_ card: CardType) {
        setDeck(activeDeck.filter { $0 != card })
    }

    /// Karte auf einen freien Platz legen. Gibt false zurück, wenn das Deck voll ist oder die Karte nicht geht.
    @discardableResult
    func addToDeck(_ card: CardType) -> Bool {
        var deck = activeDeck
        guard isUnlocked(card), !deck.contains(card), deck.count < PlayerDeck.size else { return false }
        deck.append(card)
        setDeck(deck)
        return true
    }

    /// Alle Karten einer Vorlage sind freigeschaltet (Ultimate eingeschlossen).
    func isUnlocked(_ preset: DeckPreset) -> Bool {
        preset.cards.allSatisfy { isUnlocked($0) } && isUnlocked(preset.ultimate)
    }

    func apply(_ preset: DeckPreset) {
        guard isUnlocked(preset) else { return }
        profile.settings.deck = preset.cards
        profile.settings.ultimate = preset.ultimate
    }

    private func scheduleProfileSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            self.saveTask = nil
            Storage.save(self.profile, as: "profile")
        }
    }

    /// Ausstehendes Speichern sofort erledigen (App geht in den Hintergrund).
    func flushSave() {
        guard saveTask != nil else { return }
        saveTask?.cancel()
        saveTask = nil
        Storage.saveNow(profile, as: "profile")
    }

    // Laufende Partie
    func saveGame(_ game: SavedGame) {
        Storage.save(game, as: SaveFormat.gameFile)
        // Nur bei Änderung setzen: Jede Zuweisung würde sonst nach jedem Zug alle Tabs neu aufbauen.
        if !hasSavedGame { hasSavedGame = true }
    }

    func loadGame() -> SavedGame? {
        guard var game = Storage.load(SavedGame.self, from: SaveFormat.gameFile) else { return nil }
        if game.version < SaveFormat.current { game.migrate() }
        return game
    }

    func clearGame() {
        Storage.delete(SaveFormat.gameFile)
        if hasSavedGame { hasSavedGame = false }
    }

    // MARK: Wiedergaben

    @discardableResult
    func storeReplay(_ replay: GameReplay) -> UUID {
        replays.insert(replay, at: 0)
        if replays.count > 10 { replays = Array(replays.prefix(10)) }
        Storage.save(replays, as: "replays")
        return replay.id
    }

    func replay(for id: UUID?) -> GameReplay? {
        guard let id else { return nil }
        return replays.first { $0.id == id }
    }

    /// Ergebnis verbuchen. Gibt die Trophäen-Änderung zurück.
    /// `opponentTrophies` ist der Wert des Gegners (bei einem Bot seine Stufenmitte). Fehlt er, gilt ein gleich starker Gegner.
    @discardableResult
    func record(result: GameResultKind, rated: Bool, opponent: String, reason: String, moves: Int, cardsPlayed: Int,
                replayID: UUID? = nil, countsForStats: Bool? = nil, opponentTrophies: Int? = nil) -> Int {
        var delta = 0
        if !rated && (countsForStats ?? false) {
            switch result {
            case .win: profile.wins += 1
            case .loss: profile.losses += 1
            case .draw: profile.draws += 1
            }
        }
        if rated {
            delta = TrophyStake.delta(mine: profile.trophies, opponent: opponentTrophies ?? profile.trophies, result: result)
            switch result {
            case .win: profile.wins += 1
            case .loss: profile.losses += 1
            case .draw: profile.draws += 1
            }
            profile.trophies = max(0, profile.trophies + delta)
            profile.bestTrophies = max(profile.bestTrophies, profile.trophies)
        }
        let record = GameRecord(date: Date(), opponent: opponent, result: result, reason: reason,
                                moves: moves, trophyDelta: delta, cardsPlayed: cardsPlayed, replayID: replayID)
        profile.history.insert(record, at: 0)
        if profile.history.count > 50 { profile.history = Array(profile.history.prefix(50)) }
        return delta
    }

}

/// Trophäen einer gewerteten Partie. Dieselbe Rechnung wie `trophy_delta` auf dem Server.
/// Gegen einen gleich starken Gegner: Sieg +20, Remis 0, Niederlage −20.
/// Je 100 Trophäen Vorsprung des Gegners verschiebt das um 4 (Sieg mehr, Niederlage weniger), höchstens +40/−40, mindestens +8/−8.
/// Einzige Untergrenze ist 0 – Arenen haben keine Sperre, man kann herausfallen.
enum TrophyStake {
    static func delta(mine: Int, opponent: Int, result: GameResultKind) -> Int {
        let mine = max(0, mine)
        let gap = min(800, max(-800, max(0, opponent) - mine))
        let shift = gap / 100
        let raw: Int
        switch result {
        case .win: raw = min(40, max(8, 20 + shift * 4))
        case .draw: raw = min(12, max(-12, shift * 2))
        case .loss: raw = min(-8, max(-40, -(20 - shift * 4)))
        }
        return mine + raw < 0 ? -mine : raw
    }
}

extension ProfileStore {

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func dayKey(daysAgo: Int) -> String {
        dayKey(Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date())
    }

    /// Aktuelle Serie: zählt, solange gestern oder heute eine Flamme entzündet wurde.
    var currentStreak: Int {
        guard let last = profile.lastStreakDay else { return 0 }
        if last == ProfileStore.dayKey() || last == ProfileStore.dayKey(daysAgo: 1) { return profile.streak }
        return 0
    }

    var flameLitToday: Bool { profile.lastStreakDay == ProfileStore.dayKey() }

    func wasActive(on date: Date) -> Bool { profile.activeDays.contains(ProfileStore.dayKey(date)) }

    /// Verbucht eine Tagesaktivität (gelöstes Puzzle oder abgeschlossene Partie).
    /// Gibt die neue Serienlänge zurück, wenn die Flamme heute zum ersten Mal entzündet wurde.
    @discardableResult
    func registerActivity() -> Int? {
        let today = ProfileStore.dayKey()
        guard profile.lastStreakDay != today else { return nil }
        var p = profile
        p.streak = p.lastStreakDay == ProfileStore.dayKey(daysAgo: 1) ? p.streak + 1 : 1
        p.bestStreak = max(p.bestStreak, p.streak)
        p.lastStreakDay = today
        if !p.activeDays.contains(today) { p.activeDays.append(today) }
        if p.activeDays.count > 400 { p.activeDays = Array(p.activeDays.suffix(400)) }
        profile = p
        grantStreakMilestones()
        return p.streak
    }

    // MARK: Puzzles & XP

    /// XP, die für Level n insgesamt nötig sind: 0, 50, 150, 300, 500, …
    static func xpForLevel(_ n: Int) -> Int { 25 * (n - 1) * n }

    static func level(forXP xp: Int) -> Int {
        var n = 1
        while xpForLevel(n + 1) <= xp { n += 1 }
        return n
    }

    var level: Int { ProfileStore.level(forXP: profile.xp) }

    /// Fortschritt innerhalb des aktuellen Levels (0…1) und XP bis zum nächsten.
    var levelProgress: (fraction: Double, remaining: Int) {
        let lo = ProfileStore.xpForLevel(level)
        let hi = ProfileStore.xpForLevel(level + 1)
        let frac = Double(profile.xp - lo) / Double(max(1, hi - lo))
        return (min(1, max(0, frac)), hi - profile.xp)
    }

    func isSolved(_ puzzle: Puzzle) -> Bool { profile.solvedPuzzles.contains(puzzle.id) }

    // MARK: Tagesziele

    struct DailyGoal: Identifiable {
        enum Kind { case flame, puzzle, win }
        let kind: Kind
        let icon: String
        let title: String
        let done: Bool
        var id: String { title }
    }


    /// Drei Ziele pro Tag: Flamme entzünden, Tagespuzzle lösen, eine Partie gegen den Bot gewinnen.
    var dailyGoals: [DailyGoal] {
        let wonToday = profile.history.contains { Calendar.current.isDateInToday($0.date) && $0.result == .win && $0.opponent != "Zu zweit" }
        return [
            DailyGoal(kind: .flame, icon: "flame.fill", title: L("Flamme entzünden"), done: flameLitToday),
            DailyGoal(kind: .puzzle, icon: "puzzlepiece.fill", title: L("Tagespuzzle lösen"), done: !dailyBonusAvailable),
            DailyGoal(kind: .win, icon: "trophy.fill", title: L("Eine Partie gewinnen"), done: wonToday)
        ]
    }

    var dailyChestOpened: Bool { profile.dailyChestDay == ProfileStore.dayKey() }
    var dailyChestReady: Bool { !dailyChestOpened && dailyGoals.allSatisfy(\.done) }

    /// Öffnet die Tagestruhe. Gibt die gewonnenen XP zurück (nil, wenn nicht möglich).
    // MARK: Bot-Leiter

    /// Nächster Gegner der Leiter (nil = alle besiegt).
    var ladderNext: BotLevel? {
        let all = BotLevel.allCases
        return profile.ladderBeaten < all.count ? all[profile.ladderBeaten] : nil
    }

    func isLadderUnlocked(_ level: BotLevel) -> Bool { level.tier <= profile.ladderBeaten + 1 }
    func isLadderBeaten(_ level: BotLevel) -> Bool { level.tier <= profile.ladderBeaten }

    struct LadderReward: Equatable {
        var xp: Int
        var firstWin: Bool
        var unlocked: BotLevel?
        var levelUp: Int?
    }

    /// Verbucht einen Sieg in der Leiter: XP, Fortschritt, nächster Gegner.
    func recordLadderWin(_ level: BotLevel) -> LadderReward {
        let first = !isLadderBeaten(level)
        let before = self.level
        let xp = first ? level.xpFirstWin : 10
        var p = profile
        p.ladderWins[level.rawValue, default: 0] += 1
        var unlocked: BotLevel? = nil
        if first && level.tier == p.ladderBeaten + 1 {
            p.ladderBeaten = level.tier
            if level.tier < BotLevel.allCases.count { unlocked = BotLevel.allCases[level.tier] }
        }
        profile = p
        if first { grantLadderChest(level) }
        addXP(xp)
        return LadderReward(xp: xp, firstWin: first, unlocked: unlocked, levelUp: self.level > before ? self.level : nil)
    }

    /// Alle Tagesziele erfüllt: Die Tagestruhe (Gold) kommt ins Lager und wird zurückgegeben.
    func claimDailyChest() -> Chest? {
        guard dailyChestReady else { return nil }
        profile.dailyChestDay = ProfileStore.dayKey()
        grantChest(.daily, .gold)
        return profile.chests.last
    }

    /// Das Tagespuzzle: wechselt jeden Tag und bleibt über den Tag gleich.
    var dailyPuzzle: Puzzle? {
        let all = PuzzleCatalog.all
        guard !all.isEmpty else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let day = Int(start.timeIntervalSince1970 / 86_400)
        // Mit einer Primzahl springen, damit sich die Schwierigkeit von Tag zu Tag abwechselt.
        return all[(day * 7) % all.count]
    }

    var dailyBonusAvailable: Bool { profile.dailyBonusDay != ProfileStore.dayKey() }

    struct PuzzleReward: Equatable {
        var xp: Int
        var dailyBonus: Int
        var firstSolve: Bool
        var levelUp: Int?
        var streakLit: Int?
        /// Eine Rätseltruhe wurde vergeben.
        var chest = false
        /// Saubere Lösungen in Folge (nach diesem Puzzle)
        var puzzleStreak = 0
    }

    func breakPuzzleStreak() { profile.puzzleStreak = 0 }

    /// Puzzle-Rausch beendet: Bestwert und XP (3 pro gelöstem Puzzle). Rückgabe: neuer Bestwert?
    @discardableResult
    func finishRush(score: Int) -> Bool {
        profile.rushPlayed += 1
        let best = score > profile.rushBest
        if best { profile.rushBest = score }
        addXP(score * 3)
        registerActivity()
        return best
    }

    /// Nächstes ungelöstes Puzzle: niedrigste Schwierigkeit zuerst, in Katalog-Reihenfolge.
    var nextPuzzle: Puzzle? {
        let open = PuzzleCatalog.all.filter { !isSolved($0) }
        return open.min { a, b in a.difficulty != b.difficulty ? a.difficulty < b.difficulty : false }
            ?? PuzzleCatalog.all.randomElement()
    }

    /// Verbucht ein gelöstes Puzzle. Volle XP nur beim ersten Lösen ohne Fehler und Hinweis.
    func solvePuzzle(_ puzzle: Puzzle, clean: Bool, isDaily: Bool) -> PuzzleReward {
        let first = !isSolved(puzzle)
        let levelBefore = level
        var gained = first ? (clean ? puzzle.xp : max(1, puzzle.xp / 2)) : 0
        var bonus = 0
        if isDaily && dailyBonusAvailable {
            bonus = 15
            profile.dailyBonusDay = ProfileStore.dayKey()
        }
        gained += bonus
        if first { profile.solvedPuzzles.append(puzzle.id) }
        // Serie: zählt saubere Lösungen in Folge
        if clean {
            profile.puzzleStreak += 1
            profile.bestPuzzleStreak = max(profile.bestPuzzleStreak, profile.puzzleStreak)
        } else {
            profile.puzzleStreak = 0
        }
        let chest = first && grantPuzzleChestIfDue()
        addXP(gained)
        let lit = registerActivity()
        let up = level > levelBefore ? level : nil
        return PuzzleReward(xp: gained - bonus, dailyBonus: bonus, firstSolve: first, levelUp: up, streakLit: lit, chest: chest,
                            puzzleStreak: profile.puzzleStreak)
    }

    func resetProgress() {
        let settings = profile.settings
        profile = Profile()
        profile.settings = settings
        profile.tutorialSeen = true
        profile.deckTourDone = true
        replays = []
        Storage.delete("replays")
        clearGame()
    }
}

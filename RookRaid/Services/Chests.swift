import Foundation
import SwiftUI

// MARK: - Truhen
//
// Freischalt-Plan v0.9.6 (siehe Online-Plan, Abschnitt „Freischalt-Plan & Truhen“):
// - 4 Startkarten sofort, 10 weitere aus Truhen oder für Splitter.
// - Jede Truhe wird mit mehreren Fingertipps geöffnet: drei Taps mit Chance auf eine bessere Truhe, dann der Knall.
// - Der Level-Pfad garantiert die wichtigsten Karten in fester Reihenfolge, Zufallsfunde und Splitter beschleunigen.
// Die Zahlen sind mit einer Fortschritts-Simulation abgestimmt (regelmäßiger Spieler: alle Karten nach etwa 10 Tagen).

enum ChestRarity: Int, Codable, CaseIterable, Comparable, Identifiable {
    case wood, silver, gold, magic, legendary

    var id: Int { rawValue }
    static func < (a: ChestRarity, b: ChestRarity) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .wood: return L("Holztruhe")
        case .silver: return L("Silbertruhe")
        case .gold: return L("Goldtruhe")
        case .magic: return L("Magische Truhe")
        case .legendary: return L("Legendäre Truhe")
        }
    }

    var shortName: String { [L("Holz"), L("Silber"), L("Gold"), L("Magisch"), L("Legendär")][rawValue] }

    /// Großes Wort beim Aufwerten.
    var shout: String {
        switch self {
        case .wood: return L("HOLZ")
        case .silver: return L("SILBER!")
        case .gold: return L("GOLD!")
        case .magic: return L("MAGISCH!")
        case .legendary: return L("LEGENDÄR!!")
        }
    }

    /// Hauptfarbe, helle Kante, dunkler Schatten und Leuchtfarbe.
    var colors: (body: UInt32, light: UInt32, dark: UInt32, glow: UInt32) {
        switch self {
        case .wood: return (0x9A6A3C, 0xC8955E, 0x5E3B1E, 0xE8B57A)
        case .silver: return (0x9AA6B8, 0xE3E9F2, 0x5B6577, 0xD9E6FF)
        case .gold: return (0xE0A82E, 0xFFE08A, 0x8F5F0C, 0xFFD45C)
        case .magic: return (0x8B4FE0, 0xC9A2FF, 0x4B2391, 0xC28BFF)
        case .legendary: return (0xF2603A, 0xFFD27A, 0x9C2A12, 0xFFB347)
        }
    }

    var bodyColor: Color { Color(hex: colors.body) }
    var lightColor: Color { Color(hex: colors.light) }
    var darkColor: Color { Color(hex: colors.dark) }
    var glowColor: Color { Color(hex: colors.glow) }

    /// Chance pro Tap, eine Stufe aufzusteigen.
    var upgradeChance: Double {
        switch self {
        case .wood: return 0.35
        case .silver: return 0.25
        case .gold: return 0.15
        case .magic: return 0.08
        case .legendary: return 0
        }
    }

    var next: ChestRarity? { ChestRarity(rawValue: rawValue + 1) }

    var xp: Int { [5, 10, 20, 40, 80][rawValue] }
    var shards: Int { [5, 10, 20, 40, 100][rawValue] }
    /// Chance auf eine neue Karte (zusätzlich zu Garantien und Glücksschutz).
    var cardChance: Double { [0.02, 0.04, 0.08, 0.20, 0.60][rawValue] }
    /// Chance auf ein Sammelbrett.
    var boardChance: Double { [0, 0, 0, 0.10, 0.40][rawValue] }
}

enum ChestSource: String, Codable {
    case tutorial, win, daily, ladder, puzzle, level, arena, welcome, road, streak, shop

    var title: String {
        switch self {
        case .tutorial: return L("Erste Truhe")
        case .win: return L("Siegtruhe")
        case .daily: return L("Tagestruhe")
        case .ladder: return L("Leiter-Truhe")
        case .puzzle: return L("Rätseltruhe")
        case .level: return L("Level-Truhe")
        case .arena: return L("Arena-Truhe")
        case .welcome: return L("Willkommensgeschenk")
        case .road: return L("Trophäenpfad")
        case .streak: return L("Flammentruhe")
        case .shop: return L("Laden-Truhe")
        }
    }

    var icon: String {
        switch self {
        case .tutorial: return "sparkles"
        case .win: return "trophy.fill"
        case .daily: return "calendar"
        case .ladder: return "figure.stairs"
        case .puzzle: return "puzzlepiece.fill"
        case .level: return "arrow.up.circle.fill"
        case .arena: return "flag.fill"
        case .welcome: return "gift.fill"
        case .road: return "trophy.fill"
        case .streak: return "flame.fill"
        case .shop: return "bag.fill"
        }
    }
}

extension Chest {
    /// Zahl im gespeicherten Zusatz („Level 4“ → 4, „7 Tage“ → 7, „300 Trophäen“ → 300)
    private var labelNumber: Int? {
        guard let label else { return nil }
        return label.split(separator: " ").compactMap { Int($0) }.first
    }

    /// Große Zeile vor dem Öffnen: wofür es diese Truhe gibt.
    var reasonHeadline: String {
        switch source {
        case .tutorial: return L("Erste Schlacht gewonnen!")
        case .win: return L("Für deinen Sieg!")
        case .daily: return L("Alle Tagesziele geschafft!")
        case .ladder:
            if let label { return L("{0} besiegt!", Chest.localizedLabel(label)) }
            return L("Leiter-Sieg!")
        case .puzzle: return L("{0} Rätsel gelöst!", ProfileStore.puzzlesPerChest)
        case .level:
            if let n = labelNumber { return L("Level {0} erreicht!", n) }
            return L("Level aufgestiegen!")
        case .arena:
            if let label { return L("Neue Arena: {0}!", Chest.localizedLabel(label)) }
            return L("Neue Arena!")
        case .welcome: return L("Willkommen in der Arena!")
        case .road:
            if let n = labelNumber { return L("{0} Trophäen erreicht!", n) }
            return L("Trophäenpfad!")
        case .streak:
            if let n = labelNumber { return L("{0} Tage Flamme!", n) }
            return L("Flamme gehalten!")
        case .shop: return L("Frisch aus dem Laden!")
        }
    }
}

/// Was eine Truhe sicher enthält.
enum ChestGuarantee: Codable, Equatable {
    case card(CardType)
    case tier(CardTier)
}

struct Chest: Codable, Identifiable, Equatable {
    var id = UUID()
    var rarity: ChestRarity
    var source: ChestSource
    var guarantee: ChestGuarantee? = nil
    /// Erste Truhe: Der zweite Tap wertet sicher auf, damit jeder das Aufwerten einmal erlebt.
    var scriptedUpgrade = false
    /// Zusatz wie „Level 4“ oder „Sir Konrad“.
    var label: String? = nil
    var date = Date()

    var title: String { label.map { "\(source.title) · \(Chest.localizedLabel($0))" } ?? source.title }

    /// Zusätze werden deutsch gespeichert („Level 4“, „7 Tage“, „300 Trophäen“) und erst beim Anzeigen übersetzt.
    static func localizedLabel(_ label: String) -> String {
        let parts = label.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            if parts[0] == "Level", let n = Int(parts[1]) { return L("Level {0}", n) }
            if let n = Int(parts[0]) {
                if parts[1] == "Tage" { return L("{0} Tage", n) }
                if parts[1] == "Trophäen" { return L("{0} Trophäen", n) }
            }
        }
        if let level = BotLevel.allCases.first(where: { $0.canonicalName == label }) { return level.displayName }
        return L(label)
    }
}

enum ChestReward: Codable, Equatable, Identifiable {
    case xp(Int)
    case shards(Int)
    case card(CardType)
    case board(BoardTheme)
    /// Volle Sammlung: großer Splitter-Fund statt einer Karte.
    case jackpot(Int)
    /// Kosmetik aus Truhen
    case avatar(Avatar)
    case frame(AvatarFrame)
    case title(String)

    var id: String {
        switch self {
        case .xp: return "xp"
        case .shards: return "shards"
        case .card(let c): return "card-" + c.rawValue
        case .board(let b): return "board-" + b.rawValue
        case .jackpot: return "jackpot"
        case .avatar(let a): return "avatar-" + a.rawValue
        case .frame(let f): return "frame-" + f.rawValue
        case .title(let t): return "title-" + t
        }
    }

    /// Große Funde bekommen eine eigene Enthüllung mit Fanfare.
    var isBig: Bool {
        switch self {
        case .card, .board, .jackpot, .avatar, .frame, .title: return true
        default: return false
        }
    }
}

/// Ablauf einer Öffnung: Stufe nach jedem der drei Taps (vorab gewürfelt, damit die Animation weiß, wann aufgewertet wird).
struct ChestPlan: Equatable {
    let chest: Chest
    let steps: [ChestRarity]
    var final: ChestRarity { steps.last ?? chest.rarity }
    static let chargeTaps = 3
}

// MARK: - Level-Pfad

/// Garantierte Belohnungen beim Levelaufstieg – der sichtbare Teil des Freischalt-Plans.
struct LevelRoadStep: Identifiable {
    let level: Int
    let rarity: ChestRarity
    let guarantee: ChestGuarantee?
    var id: Int { level }

    static func step(for level: Int) -> LevelRoadStep {
        switch level {
        case 2: return LevelRoadStep(level: 2, rarity: .silver, guarantee: .card(.knighting))
        case 3: return LevelRoadStep(level: 3, rarity: .silver, guarantee: nil)
        case 4: return LevelRoadStep(level: 4, rarity: .gold, guarantee: .card(.bulwark))
        case 5: return LevelRoadStep(level: 5, rarity: .gold, guarantee: .card(.advance))
        case 6: return LevelRoadStep(level: 6, rarity: .gold, guarantee: .tier(.rare))
        case 7: return LevelRoadStep(level: 7, rarity: .gold, guarantee: nil)
        case 8: return LevelRoadStep(level: 8, rarity: .magic, guarantee: .tier(.rare))
        case 9: return LevelRoadStep(level: 9, rarity: .gold, guarantee: nil)
        case 10: return LevelRoadStep(level: 10, rarity: .magic, guarantee: .tier(.epic))
        case 11: return LevelRoadStep(level: 11, rarity: .gold, guarantee: .tier(.rare))
        case 12: return LevelRoadStep(level: 12, rarity: .magic, guarantee: .tier(.epic))
        case 13: return LevelRoadStep(level: 13, rarity: .gold, guarantee: nil)
        case 14: return LevelRoadStep(level: 14, rarity: .legendary, guarantee: .tier(.epic))
        default: return LevelRoadStep(level: level, rarity: level % 5 == 0 ? .legendary : .gold, guarantee: nil)
        }
    }

    var text: String {
        switch guarantee {
        case .card(let c)?: return c.name
        case .tier(let t)?: return L("Karte ({0})", t.name)
        case nil: return rarity.name
        }
    }
}

// MARK: - Logik im Profil

extension ProfileStore {

    static let winChestsPerDay = 3
    static let puzzlesPerChest = 5
    static let pityLimit = 12

    var pendingChests: [Chest] { profile.chests }

    /// Truhe ins Lager legen.
    func grantChest(_ source: ChestSource, _ rarity: ChestRarity, guarantee: ChestGuarantee? = nil,
                    label: String? = nil, scripted: Bool = false) {
        profile.chests.append(Chest(rarity: rarity, source: source, guarantee: guarantee, scriptedUpgrade: scripted, label: label))
    }

    /// XP gutschreiben – jeder neue Level bringt eine Level-Truhe.
    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        profile.xp += amount
        grantLevelChests()
    }

    func grantLevelChests() {
        while profile.levelChestsGranted < level {
            let next = profile.levelChestsGranted + 1
            profile.levelChestsGranted = next
            let step = LevelRoadStep.step(for: next)
            grantChest(.level, step.rarity, guarantee: step.guarantee, label: "Level \(next)")
        }
    }

    /// Kommende Stationen des Level-Pfads (für den Deck-Tab).
    func upcomingRoad(count: Int = 4) -> [LevelRoadStep] {
        ((level + 1)...(level + count)).map { LevelRoadStep.step(for: $0) }
    }

    // MARK: Quellen

    /// Kampf-Sieg: Die ersten drei Siege des Tages bringen je eine Siegtruhe. Rückgabe: Truhe wurde vergeben.
    @discardableResult
    func grantWinChest() -> Bool {
        let today = ProfileStore.dayKey()
        if profile.winChestDay != today {
            profile.winChestDay = today
            profile.winChestsToday = 0
        }
        guard profile.winChestsToday < ProfileStore.winChestsPerDay else { return false }
        profile.winChestsToday += 1
        grantChest(.win, .wood)
        return true
    }

    var winChestsLeftToday: Int {
        profile.winChestDay == ProfileStore.dayKey()
            ? max(0, ProfileStore.winChestsPerDay - profile.winChestsToday) : ProfileStore.winChestsPerDay
    }

    /// Bot-Leiter: erster Sieg gegen einen Charakter.
    func grantLadderChest(_ level: BotLevel) {
        grantChest(.ladder, level.ladderChest, label: level.canonicalName)
    }

    /// Jedes fünfte erstmals gelöste Puzzle bringt eine Rätseltruhe. Rückgabe: Truhe wurde vergeben.
    @discardableResult
    func grantPuzzleChestIfDue() -> Bool {
        let due = profile.solvedPuzzles.count / ProfileStore.puzzlesPerChest
        guard due > profile.puzzleChestsGranted else { return false }
        while profile.puzzleChestsGranted < due {
            profile.puzzleChestsGranted += 1
            grantChest(.puzzle, .silver)
        }
        return true
    }

    /// Erste Truhe nach der Einstiegspartie: wertet sicher auf und enthält Verstärkung.
    func grantTutorialChest() {
        guard !profile.tutorialChestGiven else { return }
        profile.tutorialChestGiven = true
        grantChest(.tutorial, .silver, guarantee: .card(.reinforce), scripted: true)
    }

    // MARK: Öffnen

    /// Würfelt die drei Taps vorab.
    func plan(_ chest: Chest) -> ChestPlan {
        var r = chest.rarity
        var steps: [ChestRarity] = []
        for i in 0..<ChestPlan.chargeTaps {
            let up = chest.scriptedUpgrade ? i == 1 : Double.random(in: 0..<1) < r.upgradeChance
            if up, let n = r.next { r = n }
            steps.append(r)
        }
        return ChestPlan(chest: chest, steps: steps)
    }

    /// Karten, die gerade aus Truhen kommen können (Level-Sperre je Stufe).
    var droppableCards: [CardType] {
        CardType.allCases.filter { !isUnlocked($0) && level >= $0.tier.gateLevel }
    }

    /// Öffnet die Truhe endgültig: Belohnungen auswürfeln, gutschreiben, Truhe aus dem Lager nehmen.
    /// Reihenfolge der Belohnungen: XP, Splitter, Brett, Karte – das Beste zum Schluss.
    func open(_ plan: ChestPlan) -> [ChestReward] {
        let rarity = plan.final
        var rewards: [ChestReward] = [.xp(rarity.xp), .shards(rarity.shards)]
        var p = profile
        p.chests.removeAll { $0.id == plan.chest.id }
        p.chestsOpened += 1
        p.shards += rarity.shards
        p.shardsEarned += rarity.shards
        if rarity == .legendary { p.legendaryChests += 1 }
        profile = p

        // Sammelbrett
        let lockedBoards = BoardTheme.allCases.filter { $0.isCollectible && !isOwned($0) }
        if let board = lockedBoards.randomElement(), Double.random(in: 0..<1) < rarity.boardChance {
            profile.ownedBoards.append(board.rawValue)
            rewards.append(.board(board))
        }

        // Karte: Garantie, sonst Zufall mit Glücksschutz
        var card: CardType? = nil
        switch plan.chest.guarantee {
        case .card(let c)?:
            card = isUnlocked(c) ? pickCard(preferring: c.tier) : c
        case .tier(let t)?:
            card = pickCard(preferring: t)
        case nil:
            break
        }
        var cardRoll = false
        if card == nil {
            let pity = profile.pityCounter >= ProfileStore.pityLimit - 1
            if pity || Double.random(in: 0..<1) < rarity.cardChance {
                cardRoll = true
                card = randomDroppableCard()
            }
        }
        // Volle Sammlung: Statt einer Karte gibt es einen großen Splitter-Fund.
        if cardRoll && card == nil && CardType.allCases.allSatisfy({ isUnlocked($0) }) {
            earnShards(ProfileStore.jackpotShards)
            rewards.append(.jackpot(ProfileStore.jackpotShards))
        }
        if let card, !isUnlocked(card) {
            profile.unlockedCards.append(card.rawValue)
            profile.pityCounter = 0
            rewards.append(.card(card))
        } else {
            profile.pityCounter += 1
        }
        // Kosmetik: Avatar, Rahmen oder Titel
        if let cosmetic = rollCosmetic(for: rarity) {
            // Die Karte bleibt das Beste zum Schluss
            if let i = rewards.firstIndex(where: { if case .card = $0 { return true }; return false }) {
                rewards.insert(cosmetic, at: i)
            } else {
                rewards.append(cosmetic)
            }
        }
        addXP(rarity.xp)
        return rewards
    }

    /// Gesperrte Karte bevorzugt aus dieser Stufe, sonst aus einer freigegebenen.
    private func pickCard(preferring tier: CardTier) -> CardType? {
        let same = CardType.allCases.filter { !isUnlocked($0) && $0.tier == tier }
        if let c = same.randomElement() { return c }
        return randomDroppableCard()
    }

    private func randomDroppableCard() -> CardType? {
        let pool = droppableCards
        guard !pool.isEmpty else { return nil }
        let total = pool.reduce(0) { $0 + $1.tier.dropWeight }
        var x = Double.random(in: 0..<total)
        for c in pool {
            x -= c.tier.dropWeight
            if x < 0 { return c }
        }
        return pool.last
    }

    // MARK: Splitter

    static let jackpotShards = 150

    /// Splitter gutschreiben (zählt auch für Erfolge und das Sparziel).
    func earnShards(_ n: Int) {
        guard n > 0 else { return }
        profile.shards += n
        profile.shardsEarned += n
    }

    /// Splitter ausgeben; false, wenn es nicht reicht.
    @discardableResult
    func spendShards(_ n: Int) -> Bool {
        guard profile.shards >= n else { return false }
        profile.shards -= n
        return true
    }

    func canBuy(_ card: CardType) -> Bool {
        !isUnlocked(card) && level >= card.tier.gateLevel && profile.shards >= card.tier.price
    }

    @discardableResult
    func buy(_ card: CardType) -> Bool {
        guard canBuy(card) else { return false }
        profile.shards -= card.tier.price
        profile.unlockedCards.append(card.rawValue)
        profile.seenCards.append(card.rawValue)
        profile.cardsBought += 1
        if profile.shardGoal == "card.\(card.rawValue)" { profile.shardGoal = nil }
        return true
    }

    func isOwned(_ board: BoardTheme) -> Bool {
        !board.isCollectible || profile.settings.testModeActive || profile.ownedBoards.contains(board.rawValue)
    }

    @discardableResult
    func buy(_ board: BoardTheme) -> Bool {
        guard !isOwned(board), profile.shards >= BoardTheme.collectiblePrice else { return false }
        profile.shards -= BoardTheme.collectiblePrice
        profile.ownedBoards.append(board.rawValue)
        if profile.shardGoal == "board.\(board.rawValue)" { profile.shardGoal = nil }
        return true
    }
}

extension BotLevel {
    /// Truhe für den ersten Leiter-Sieg gegen diesen Charakter.
    var ladderChest: ChestRarity {
        switch tier {
        case 1, 2, 3: return .silver
        case 4, 5, 6, 7: return .gold
        case 8, 9, 10: return .magic
        default: return .legendary
        }
    }
}

import Foundation

// MARK: - Kosmetik: Avatare, Truhen-Titel, Seltenheit

/// Seltenheit eines kosmetischen Gegenstands – bestimmt Preis und wie oft er aus Truhen fällt.
enum CosmeticRarity: Int, Comparable {
    case common, rare, epic, legendary

    static func < (a: CosmeticRarity, b: CosmeticRarity) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .common: return L("Gewöhnlich")
        case .rare: return L("Selten")
        case .epic: return L("Episch")
        case .legendary: return L("Legendär")
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .common: return 0x6FBF73
        case .rare: return 0x3FA9F5
        case .epic: return 0xB06CFF
        case .legendary: return 0xFFB648
        }
    }

    /// Gewicht beim Ziehen aus Truhen
    var dropWeight: Double { [3.0, 2.0, 1.0, 0.4][rawValue] }
}

/// Avatare: der Springer ist frei, alle anderen kommen aus Truhen oder aus dem Laden.
enum Avatar: String, CaseIterable, Identifiable, Codable {
    case knight, fox, owl, bear, penguin, frog, wolf, lion, robot, wizard, dragon, phoenix
    var id: String { rawValue }

    var name: String {
        switch self {
        case .knight: return L("Springer")
        case .fox: return L("Fuchs")
        case .owl: return L("Eule")
        case .bear: return L("Bär")
        case .penguin: return L("Pinguin")
        case .frog: return L("Frosch")
        case .wolf: return L("Wolf")
        case .lion: return L("Löwe")
        case .robot: return L("Roboter")
        case .wizard: return L("Magier")
        case .dragon: return L("Drache")
        case .phoenix: return L("Phönix")
        }
    }

    var rarity: CosmeticRarity {
        switch self {
        case .knight, .fox, .owl, .bear, .penguin, .frog: return .common
        case .wolf, .lion, .robot: return .rare
        case .wizard, .dragon: return .epic
        case .phoenix: return .legendary
        }
    }

    var price: Int {
        switch rarity {
        case .common: return 250
        case .rare: return 600
        case .epic: return 1200
        case .legendary: return 2000
        }
    }
}

/// Titel, die es nur aus Truhen gibt (die Erfolgs-Titel kommen aus den Erfolgen).
struct ChestTitle {
    let title: String
    let rarity: CosmeticRarity

    static let all: [ChestTitle] = [
        ChestTitle(title: "Glückspilz", rarity: .common),
        ChestTitle(title: "Bauernschreck", rarity: .common),
        ChestTitle(title: "Springer-Ass", rarity: .common),
        ChestTitle(title: "Turmstürmer", rarity: .common),
        ChestTitle(title: "Kartenhai", rarity: .rare),
        ChestTitle(title: "Frostfürst", rarity: .rare),
        ChestTitle(title: "Blitzschläger", rarity: .rare),
        ChestTitle(title: "Gambit-Genie", rarity: .epic),
        ChestTitle(title: "Meteorbändiger", rarity: .epic),
        ChestTitle(title: "Kronjuwel", rarity: .legendary)
    ]
}

extension AvatarFrame {
    /// Seltenheit der Laden-Rahmen (auch aus Truhen ziehbar)
    var rarity: CosmeticRarity {
        switch self {
        case .ruby: return .rare
        case .nebula: return .epic
        case .prism: return .legendary
        default: return .common
        }
    }
}

extension ProfileStore {
    // MARK: Avatare

    func isOwned(_ avatar: Avatar) -> Bool {
        avatar == .knight || profile.settings.testModeActive || profile.ownedAvatars.contains(avatar.rawValue)
    }

    var activeAvatar: Avatar {
        if let raw = profile.selectedAvatar, let a = Avatar(rawValue: raw), isOwned(a) { return a }
        return .knight
    }

    // MARK: Figurensets der Bots

    /// Das Figurenset eines Bots gehört dir, sobald du ihn besiegt hast – in der Leiter oder im Kampf.
    func isSkinUnlocked(_ level: BotLevel) -> Bool {
        if profile.settings.testModeActive || profile.ladderBeaten >= level.tier { return true }
        return profile.history.contains { $0.opponent == level.botName && $0.result == .win }
    }

    /// Dein gewähltes Figurenset (nil = Standardfiguren).
    var activeSkin: BotLevel? {
        guard let raw = profile.selectedSkin, let b = BotLevel(rawValue: raw), isSkinUnlocked(b) else { return nil }
        return b
    }

    var unlockedSkinCount: Int { BotLevel.allCases.filter { isSkinUnlocked($0) }.count }

    // MARK: Kosmetik aus Truhen

    /// Chance auf einen kosmetischen Fund je Truhe (Avatar, Rahmen oder Titel).
    static let cosmeticChance: [ChestRarity: Double] = [.wood: 0.03, .silver: 0.06, .gold: 0.12, .magic: 0.25, .legendary: 0.5]

    /// Würfelt einen kosmetischen Fund, schreibt ihn gut und gibt ihn als Belohnung zurück.
    /// Legendäre Dinge gibt es nur aus Magischen und Legendären Truhen.
    func rollCosmetic(for chest: ChestRarity) -> ChestReward? {
        guard Double.random(in: 0..<1) < (ProfileStore.cosmeticChance[chest] ?? 0) else { return nil }
        var pool: [(ChestReward, Double)] = []
        let allowLegendary = chest >= .magic
        for a in Avatar.allCases where !isOwned(a) && (allowLegendary || a.rarity < .legendary) {
            pool.append((.avatar(a), a.rarity.dropWeight))
        }
        for f in AvatarFrame.shopFrames where !profile.shopFrames.contains(f.rawValue) && (allowLegendary || f.rarity < .legendary) {
            pool.append((.frame(f), f.rarity.dropWeight))
        }
        for t in ChestTitle.all where !profile.chestTitles.contains(t.title) && (allowLegendary || t.rarity < .legendary) {
            pool.append((.title(t.title), t.rarity.dropWeight))
        }
        guard !pool.isEmpty else { return nil }
        var x = Double.random(in: 0..<pool.reduce(0) { $0 + $1.1 })
        var pick = pool[0].0
        for (r, w) in pool {
            x -= w
            if x < 0 { pick = r; break }
        }
        switch pick {
        case .avatar(let a): profile.ownedAvatars.append(a.rawValue)
        case .frame(let f): profile.shopFrames.append(f.rawValue)
        case .title(let t): profile.chestTitles.append(t)
        default: break
        }
        return pick
    }
}

import Foundation

// MARK: - Erfolge, Titel und Avatar-Rahmen

/// Rahmen um den Avatar – aus Erfolgen oder aus dem Splitter-Laden.
enum AvatarFrame: String, CaseIterable, Identifiable, Codable {
    case none, silver, gold, flame, crown, puzzle, legendary
    /// Nur im Laden
    case ruby, nebula, prism
    var id: String { rawValue }

    static let shopFrames: [AvatarFrame] = [.ruby, .nebula, .prism]
    var isShopFrame: Bool { AvatarFrame.shopFrames.contains(self) }

    var name: String {
        switch self {
        case .none: return L("Ohne")
        case .silver: return L("Silber")
        case .gold: return L("Gold")
        case .flame: return L("Flamme")
        case .crown: return L("Krone")
        case .puzzle: return L("Rätsel")
        case .legendary: return L("Legendär")
        case .ruby: return L("Rubin")
        case .nebula: return L("Nebel")
        case .prism: return L("Prisma")
        }
    }

    /// Verlauf des Rings (oben → unten).
    var colors: [UInt32] {
        switch self {
        case .none: return [0x5B7FC7, 0x3A5A9E]
        case .silver: return [0xF2F5FA, 0x9AA6B8]
        case .gold: return [0xFFE27A, 0xC98A1B]
        case .flame: return [0xFFD25E, 0xFF5A2B]
        case .crown: return [0xFFF0A8, 0xB06CFF]
        case .puzzle: return [0x8CF0B0, 0x2C9C8C]
        case .legendary: return [0xFF7AD9, 0x7A5CFF]
        case .ruby: return [0xFF8A9A, 0xC2183B]
        case .nebula: return [0x9AE6FF, 0x5B3FD1]
        case .prism: return [0xB8FFF3, 0xFF9DE6]
        }
    }

    var icon: String? {
        switch self {
        case .crown: return "crown.fill"
        case .flame: return "flame.fill"
        case .legendary: return "sparkles"
        case .puzzle: return "puzzlepiece.fill"
        case .ruby: return "suit.diamond.fill"
        case .nebula: return "moon.stars.fill"
        case .prism: return "rays"
        default: return nil
        }
    }
}

/// Bereiche, nach denen die Erfolge sortiert werden.
enum AchievementCategory: String, CaseIterable, Identifiable {
    case battle, ladder, trophies, cards, puzzles, flames, collection, shards, level
    var id: String { rawValue }

    var name: String {
        switch self {
        case .battle: return L("Kampf")
        case .ladder: return L("Bot-Leiter")
        case .trophies: return L("Trophäen")
        case .cards: return L("Karten & Ultimates")
        case .puzzles: return L("Puzzles")
        case .flames: return L("Flammen")
        case .collection: return L("Sammlung")
        case .shards: return L("Splitter")
        case .level: return L("Level")
        }
    }

    var icon: String {
        switch self {
        case .battle: return "bolt.fill"
        case .ladder: return "figure.stairs"
        case .trophies: return "trophy.fill"
        case .cards: return "rectangle.stack.fill"
        case .puzzles: return "puzzlepiece.fill"
        case .flames: return "flame.fill"
        case .collection: return "shippingbox.fill"
        case .shards: return "diamond.fill"
        case .level: return "star.fill"
        }
    }
}

/// Ein Erfolg mit Fortschritt. Beim Abholen gibt es Splitter, manche schalten Titel oder Rahmen frei.
struct Achievement: Identifiable {
    let id: String
    let category: AchievementCategory
    let icon: String
    let title: String
    let detail: String
    let progress: Int
    let goal: Int
    /// 0 = einfach, 1 Bronze, 2 Silber, 3 Gold
    var tier = 0
    var shards = 20
    var rewardTitle: String? = nil
    var rewardFrame: AvatarFrame? = nil

    var unlocked: Bool { progress >= goal }
    var fraction: Double { min(1, Double(progress) / Double(max(1, goal))) }

    var rewardText: String? {
        switch (rewardTitle, rewardFrame) {
        case let (t?, f?): return L("Titel „{0}“ + Rahmen „{1}“", L(t), f.name)
        case let (t?, nil): return L("Titel „{0}“", L(t))
        case let (nil, f?): return L("Rahmen „{0}“", f.name)
        default: return nil
        }
    }

    /// Alles, was es gibt – für die Anzeige.
    var fullRewardText: String {
        [L("{0} Splitter", shards), rewardText].compactMap { $0 }.joined(separator: " + ")
    }
}

extension ProfileStore {
    /// Rang-Titel nach Level – der Standard, solange kein Titel gewählt ist.
    nonisolated static func rank(for level: Int) -> String {
        switch level {
        case ..<3: return L("Bauer")
        case 3..<5: return L("Knappe")
        case 5..<8: return L("Ritter")
        case 8..<11: return L("Turmwächter")
        default: return L("Großmeister")
        }
    }

    /// 63 Erfolge in neun Bereichen. Zwischengespeichert, bis sich das Profil ändert (v0.9.26) – die Tab-Leiste,
    /// das Profil und die Erfolgsliste fragen oft danach, und jede Berechnung geht den ganzen Partieverlauf durch.
    var achievements: [Achievement] {
        if let cached = achievementsCache { return cached }
        let list = computeAchievements()
        achievementsCache = list
        return list
    }

    private func computeAchievements() -> [Achievement] {
        let p = profile
        let rated = p.history.filter { $0.opponent != "Zu zweit" }
        func beat(_ level: BotLevel) -> Int {
            (p.ladderBeaten >= level.tier || rated.contains { $0.opponent == level.botName && $0.result == .win }) ? 1 : 0
        }
        let cardsPlayed = max(p.cardsByType.values.reduce(0, +), p.history.reduce(0) { $0 + $1.cardsPlayed })
        let typesPlayed = CardType.allCases.filter { (p.cardsByType[$0.rawValue] ?? 0) > 0 }.count
        let collectible = CardType.allCases.filter { $0.tier != .starter }
        let collected = collectible.filter { p.unlockedCards.contains($0.rawValue) }.count
        let boards = BoardTheme.allCases.filter(\.isCollectible)
        let ownedBoards = boards.filter { p.ownedBoards.contains($0.rawValue) }.count
        let solved = p.solvedPuzzles.count
        let lvl = level
        typealias A = Achievement

        var list: [A] = [
            // Kampf
            A(id: "firstWin", category: .battle, icon: "crown.fill", title: L("Erster Sieg"), detail: L("Gewinne eine Partie"),
              progress: p.wins, goal: 1, shards: 20, rewardTitle: "Herausforderer"),
            A(id: "wins10", category: .battle, icon: "medal.fill", title: L("Kämpfer"), detail: L("Gewinne 10 Partien"),
              progress: p.wins, goal: 10, tier: 1, shards: 30),
            A(id: "wins50", category: .battle, icon: "medal.fill", title: L("Veteran"), detail: L("Gewinne 50 Partien"),
              progress: p.wins, goal: 50, tier: 2, shards: 80, rewardFrame: .silver),
            A(id: "wins100", category: .battle, icon: "medal.fill", title: L("Kriegsherr"), detail: L("Gewinne 100 Partien"),
              progress: p.wins, goal: 100, tier: 3, shards: 150, rewardTitle: "Kriegsherr"),
            A(id: "wins250", category: .battle, icon: "shield.lefthalf.filled", title: L("Unbesiegbar"), detail: L("Gewinne 250 Partien"),
              progress: p.wins, goal: 250, tier: 3, shards: 300, rewardTitle: "Unbesiegbar"),
            A(id: "mate10", category: .battle, icon: "xmark.shield.fill", title: L("Mattsetzer"), detail: L("10 Siege durch Schachmatt"),
              progress: p.mateWins, goal: 10, tier: 1, shards: 40),
            A(id: "mate50", category: .battle, icon: "xmark.shield.fill", title: L("Mattkünstler"), detail: L("50 Siege durch Schachmatt"),
              progress: p.mateWins, goal: 50, tier: 3, shards: 120, rewardTitle: "Mattkünstler"),
            A(id: "wstreak3", category: .battle, icon: "bolt.fill", title: L("Siegesserie"), detail: L("3 Siege in Folge"),
              progress: p.bestWinStreak, goal: 3, tier: 1, shards: 30),
            A(id: "wstreak5", category: .battle, icon: "bolt.fill", title: L("Heiße Serie"), detail: L("5 Siege in Folge"),
              progress: p.bestWinStreak, goal: 5, tier: 2, shards: 60),
            A(id: "wstreak10", category: .battle, icon: "bolt.circle.fill", title: L("Unaufhaltsam"), detail: L("10 Siege in Folge"),
              progress: p.bestWinStreak, goal: 10, tier: 3, shards: 150, rewardTitle: "Unaufhaltsam")
        ]

        // Bot-Leiter: je ein Erfolg pro Charakter
        let ladderShards = [20, 25, 30, 40, 50, 60, 75, 90, 110, 140, 170, 250]
        for level in BotLevel.allCases {
            var a = A(id: "ladder-\(level.rawValue)", category: .ladder, icon: level.icon, title: L("{0} besiegt", level.displayName),
                      detail: L("Schlage {0} {1}", level.displayName, level.title), progress: beat(level), goal: 1,
                      tier: level.tier >= 9 ? 3 : (level.tier >= 5 ? 2 : 1), shards: ladderShards[level.tier - 1])
            if level == .hard { a.rewardTitle = L("Bezwinger") }
            if level == .queen {
                a.rewardTitle = L("Königsbezwinger")
                a.rewardFrame = .crown
            }
            list.append(a)
        }

        list += [
            // Trophäen
            A(id: "arena2", category: .trophies, icon: "shield.lefthalf.filled", title: L("Aufsteiger"), detail: L("Arena 2 erreicht"),
              progress: p.bestTrophies, goal: 90, tier: 1, shards: 30),
            A(id: "arena3", category: .trophies, icon: "crown.fill", title: L("Thronanwärter"), detail: L("Arena 3 erreicht"),
              progress: p.bestTrophies, goal: 240, tier: 1, shards: 50),
            A(id: "arena4", category: .trophies, icon: "cloud.bolt.fill", title: L("Sturmreiter"), detail: L("Arena 4 erreicht"),
              progress: p.bestTrophies, goal: 600, tier: 2, shards: 80, rewardFrame: .gold),
            A(id: "arena5", category: .trophies, icon: "flame.fill", title: L("Drachentöter"), detail: L("Arena 5 erreicht"),
              progress: p.bestTrophies, goal: 1200, tier: 2, shards: 120),
            A(id: "arena6", category: .trophies, icon: "mountain.2.fill", title: L("Gipfelkönig"), detail: L("Arena 6 erreicht"),
              progress: p.bestTrophies, goal: 2100, tier: 3, shards: 200, rewardTitle: "Gipfelkönig"),
            A(id: "road", category: .trophies, icon: "flag.checkered", title: L("Ende des Pfads"), detail: L("2400 Trophäen erreicht"),
              progress: p.bestTrophies, goal: 2400, tier: 3, shards: 300),

            // Karten & Ultimates
            A(id: "cards25", category: .cards, icon: "rectangle.stack.fill", title: L("Kartenspieler"), detail: L("25 Karten gespielt"),
              progress: cardsPlayed, goal: 25, tier: 1, shards: 30),
            A(id: "cards100", category: .cards, icon: "rectangle.stack.fill", title: L("Kartenmeister"), detail: L("100 Karten gespielt"),
              progress: cardsPlayed, goal: 100, tier: 2, shards: 80, rewardTitle: "Kartenmeister"),
            A(id: "cards500", category: .cards, icon: "wand.and.stars", title: L("Großmagier"), detail: L("500 Karten gespielt"),
              progress: cardsPlayed, goal: 500, tier: 3, shards: 200, rewardTitle: "Großmagier"),
            A(id: "ult1", category: .cards, icon: "sparkles", title: L("Ultimativ"), detail: L("Setze eine Ultimate ein"),
              progress: p.ultimatesUsed, goal: 1, shards: 20),
            A(id: "ult25", category: .cards, icon: "sparkles", title: L("Ultimate-Meister"), detail: L("25 Ultimates eingesetzt"),
              progress: p.ultimatesUsed, goal: 25, tier: 2, shards: 100),
            A(id: "allTypes", category: .cards, icon: "square.grid.3x3.fill", title: L("Allrounder"), detail: L("Spiele jede der {0} Karten einmal", CardType.allCases.count),
              progress: typesPlayed, goal: CardType.allCases.count, tier: 2, shards: 100),
            A(id: "bonus50", category: .cards, icon: "figure.walk", title: L("Doppelschlag"), detail: L("50 Bonusaktionen gespielt"),
              progress: p.bonusActions, goal: 50, tier: 2, shards: 60),
            A(id: "tactic25", category: .cards, icon: "arrow.triangle.branch", title: L("Taktiker"), detail: L("25 Taktiken (Gabel, Fesselung …)"),
              progress: p.tacticBonuses, goal: 25, tier: 2, shards: 60, rewardTitle: "Taktiker"),

            // Puzzles
            A(id: "puzzles10", category: .puzzles, icon: "puzzlepiece.fill", title: L("Rätselfuchs"), detail: L("10 Puzzles gelöst"),
              progress: solved, goal: 10, tier: 1, shards: 30, rewardTitle: "Rätselfuchs"),
            A(id: "puzzles50", category: .puzzles, icon: "brain.head.profile", title: L("Rätselmeister"), detail: L("50 Puzzles gelöst"),
              progress: solved, goal: 50, tier: 2, shards: 80, rewardFrame: .puzzle),
            A(id: "puzzles100", category: .puzzles, icon: "brain.head.profile", title: L("Rätselgenie"), detail: L("100 Puzzles gelöst"),
              progress: solved, goal: 100, tier: 3, shards: 150),
            A(id: "puzzlesAll", category: .puzzles, icon: "checkmark.seal.fill", title: L("Rätselkönig"), detail: L("Alle {0} Puzzles gelöst", PuzzleCatalog.all.count),
              progress: solved, goal: PuzzleCatalog.all.count, tier: 3, shards: 300, rewardTitle: "Rätselkönig"),
            A(id: "pstreak5", category: .puzzles, icon: "target", title: L("Konzentriert"), detail: L("5 Puzzles in Folge ohne Fehler oder Hinweis"),
              progress: p.bestPuzzleStreak, goal: 5, tier: 1, shards: 30),
            A(id: "pstreak10", category: .puzzles, icon: "target", title: L("Fehlerlos"), detail: L("10 Puzzles in Folge ohne Fehler oder Hinweis"),
              progress: p.bestPuzzleStreak, goal: 10, tier: 2, shards: 60, rewardTitle: "Fehlerlos"),
            A(id: "pstreak25", category: .puzzles, icon: "scope", title: L("Makellos"), detail: L("25 Puzzles in Folge ohne Fehler oder Hinweis"),
              progress: p.bestPuzzleStreak, goal: 25, tier: 3, shards: 150),
            A(id: "rush10", category: .puzzles, icon: "bolt.circle.fill", title: L("Schnelldenker"), detail: L("10 Punkte im Puzzle-Rausch"),
              progress: p.rushBest, goal: 10, tier: 1, shards: 40),
            A(id: "rush20", category: .puzzles, icon: "bolt.circle.fill", title: L("Blitzdenker"), detail: L("20 Punkte im Puzzle-Rausch"),
              progress: p.rushBest, goal: 20, tier: 3, shards: 100, rewardTitle: "Blitzdenker"),

            // Flammen
            A(id: "streak3", category: .flames, icon: "flame.fill", title: L("Feuerserie"), detail: L("3 Tage in Folge gespielt"),
              progress: p.bestStreak, goal: 3, tier: 1, shards: 20, rewardFrame: .flame),
            A(id: "streak7", category: .flames, icon: "calendar", title: L("Unermüdlich"), detail: L("7 Tage in Folge gespielt"),
              progress: p.bestStreak, goal: 7, tier: 1, shards: 50, rewardTitle: "Unermüdlich"),
            A(id: "streak30", category: .flames, icon: "heart.fill", title: L("Feuerherz"), detail: L("30 Tage in Folge gespielt"),
              progress: p.bestStreak, goal: 30, tier: 2, shards: 150),
            A(id: "streak100", category: .flames, icon: "sun.max.fill", title: L("Ewige Flamme"), detail: L("100 Tage in Folge gespielt"),
              progress: p.bestStreak, goal: 100, tier: 3, shards: 400, rewardTitle: "Ewige Flamme"),
            A(id: "frozen", category: .flames, icon: "snowflake", title: L("Gerettet!"), detail: L("Ein Flammenschutz rettet deine Serie"),
              progress: p.frozenDays.isEmpty ? 0 : 1, goal: 1, shards: 20),

            // Sammlung
            A(id: "chests10", category: .collection, icon: "shippingbox.fill", title: L("Truhenöffner"), detail: L("10 Truhen geöffnet"),
              progress: p.chestsOpened, goal: 10, tier: 1, shards: 20),
            A(id: "chests50", category: .collection, icon: "shippingbox.fill", title: L("Schatzjäger"), detail: L("50 Truhen geöffnet"),
              progress: p.chestsOpened, goal: 50, tier: 2, shards: 60, rewardTitle: "Schatzjäger"),
            A(id: "chests200", category: .collection, icon: "shippingbox.circle.fill", title: L("Schatzkönig"), detail: L("200 Truhen geöffnet"),
              progress: p.chestsOpened, goal: 200, tier: 3, shards: 200),
            A(id: "legendary", category: .collection, icon: "sparkles", title: L("Legendär!"), detail: L("Eine Legendäre Truhe geöffnet"),
              progress: p.legendaryChests, goal: 1, tier: 2, shards: 50, rewardFrame: .legendary),
            A(id: "collector", category: .collection, icon: "square.stack.3d.up.fill", title: L("Sammler"), detail: L("Alle Karten freigeschaltet"),
              progress: collected, goal: collectible.count, tier: 3, shards: 150, rewardTitle: "Sammler"),
            A(id: "boards", category: .collection, icon: "checkerboard.rectangle", title: L("Brettsammler"), detail: L("Alle Sammelbretter besitzen"),
              progress: ownedBoards, goal: boards.count, tier: 2, shards: 150),

            // Splitter
            A(id: "shards500", category: .shards, icon: "diamond.fill", title: L("Glitzer"), detail: L("500 Splitter gesammelt"),
              progress: p.shardsEarned, goal: 500, tier: 1, shards: 25),
            A(id: "shards2000", category: .shards, icon: "diamond.fill", title: L("Kristallhort"), detail: L("2000 Splitter gesammelt"),
              progress: p.shardsEarned, goal: 2000, tier: 3, shards: 100),
            A(id: "firstBuy", category: .shards, icon: "bag.fill", title: L("Erster Kauf"), detail: L("Schalte eine Karte mit Splittern frei"),
              progress: p.cardsBought, goal: 1, shards: 20),

            // Level
            A(id: "level5", category: .level, icon: "star.fill", title: L("Level 5"), detail: L("Erreiche Level 5"),
              progress: lvl, goal: 5, tier: 1, shards: 50),
            A(id: "level10", category: .level, icon: "star.fill", title: L("Level 10"), detail: L("Erreiche Level 10"),
              progress: lvl, goal: 10, tier: 2, shards: 100),
            A(id: "level15", category: .level, icon: "star.circle.fill", title: L("Level 15"), detail: L("Erreiche Level 15"),
              progress: lvl, goal: 15, tier: 3, shards: 150, rewardTitle: "Meister"),
            A(id: "level20", category: .level, icon: "star.circle.fill", title: L("Level 20"), detail: L("Erreiche Level 20"),
              progress: lvl, goal: 20, tier: 3, shards: 300)
        ]
        return list
    }

    func isClaimed(_ a: Achievement) -> Bool { profile.claimedAchievements.contains(a.id) }

    var claimableAchievements: [Achievement] { achievements.filter { $0.unlocked && !isClaimed($0) } }

    /// Erfolg abholen: Splitter gutschreiben. Gibt die Splitter zurück (0, wenn nicht möglich).
    @discardableResult
    func claim(_ a: Achievement) -> Int {
        guard a.unlocked, !isClaimed(a) else { return 0 }
        profile.claimedAchievements.append(a.id)
        earnShards(a.shards)
        return a.shards
    }

    var unlockedTitles: [String] { achievements.filter(\.unlocked).compactMap(\.rewardTitle) + profile.chestTitles }

    var unlockedFrames: [AvatarFrame] {
        let won = Set(achievements.filter(\.unlocked).compactMap(\.rewardFrame))
        return AvatarFrame.allCases.filter { $0 == .none || won.contains($0) || profile.shopFrames.contains($0.rawValue) }
    }

    /// Titel unter dem Namen: gewählter Erfolgs-Titel, sonst der Rang nach Level.
    var activeTitle: String? {
        if let t = profile.selectedTitle, unlockedTitles.contains(t) { return L(t) }
        return ProfileStore.rank(for: level)
    }

    var activeFrame: AvatarFrame {
        if let raw = profile.selectedFrame, let f = AvatarFrame(rawValue: raw), unlockedFrames.contains(f) { return f }
        return .none
    }
}

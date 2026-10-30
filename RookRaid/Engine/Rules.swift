import Foundation

/// Alle Balance-Werte an einer Stelle (v0.9.26): Mana, Kosten, Abklingzeiten.
/// Die App bringt `rookraid-rules.json` mit. Später kann der Server eine neuere Fassung schicken
/// (gleiche Struktur, höhere `version`) – dann lässt sich nachbalancieren, ohne ein App-Update.
/// Online spielen nur Spieler mit derselben Regel-Version gegeneinander.
struct RulesConfig: Codable, Equatable {
    var version: Int
    var maxMana: Int
    var manaPerTurn: Int
    var goodMoveBonus: Int
    var ultimateCost: Int
    var cardCooldown: Int
    var drainGain: Int
    var focusGain: Int
    var sacrificeGain: Int
    /// Kartenkosten nach `CardType.rawValue`
    var cardCosts: [String: Int]
    /// Abweichende Abklingzeiten (sonst `cardCooldown`)
    var cardCooldowns: [String: Int]
    /// Abweichende Ultimate-Kosten (sonst `ultimateCost`)
    var ultimateCosts: [String: Int]

    /// Eingebaute Werte – identisch mit `rookraid-rules.json`, falls die Datei fehlt oder kaputt ist.
    static let builtIn = RulesConfig(
        version: 1, maxMana: 10, manaPerTurn: 1, goodMoveBonus: 1, ultimateCost: 8, cardCooldown: 2,
        drainGain: 2, focusGain: 4, sacrificeGain: 3,
        cardCosts: ["focus": 0, "sacrifice": 0, "drain": 0, "reinforce": 1,
                    "bulwark": 2, "shield": 2, "lightning": 2, "advance": 2,
                    "knighting": 3, "bishopize": 3, "sprint": 3, "freeze": 4, "swap": 4, "revive": 6],
        cardCooldowns: ["lightning": 3],
        ultimateCosts: ["fortress": 6])

    // MARK: Aktive Regeln

    /// Die geltenden Regeln. Kosten werden in der Bot-Suche sehr oft gelesen, darum liegen sie zusätzlich
    /// als fertige Tabellen bereit (kein Zeichenketten-Nachschlagen pro Abfrage).
    private(set) static var current: RulesConfig = loadInitial()
    private(set) static var costTable: [CardType: Int] = table(current)
    private(set) static var cooldownTable: [CardType: Int] = cooldowns(current)
    private(set) static var ultimateTable: [Ultimate: Int] = ultimateCosts(current)

    private static func table(_ r: RulesConfig) -> [CardType: Int] {
        Dictionary(uniqueKeysWithValues: CardType.allCases.map { ($0, r.cardCosts[$0.rawValue] ?? $0.defaultCost) })
    }

    private static func cooldowns(_ r: RulesConfig) -> [CardType: Int] {
        Dictionary(uniqueKeysWithValues: CardType.allCases.map { ($0, r.cardCooldowns[$0.rawValue] ?? r.cardCooldown) })
    }

    private static func ultimateCosts(_ r: RulesConfig) -> [Ultimate: Int] {
        Dictionary(uniqueKeysWithValues: Ultimate.allCases.map { ($0, r.ultimateCosts[$0.rawValue] ?? r.ultimateCost) })
    }

    /// Mitgelieferte Datei, außer eine gespeicherte Server-Fassung ist neuer.
    private static func loadInitial() -> RulesConfig {
        var rules = builtIn
        if let url = Bundle.main.url(forResource: "rookraid-rules", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundled = try? JSONDecoder().decode(RulesConfig.self, from: data) {
            rules = bundled
        }
        if let data = try? Data(contentsOf: remoteURL),
           let remote = try? JSONDecoder().decode(RulesConfig.self, from: data),
           remote.version > rules.version {
            rules = remote
        }
        return rules
    }

    private static var remoteURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("rules-remote.json")
    }

    /// Jede hier genannte Karte und Ultimate gibt es in dieser App.
    /// Eine unbekannte Karte heißt: nicht still übernehmen, sondern ein App-Update verlangen.
    var isKnownToThisApp: Bool {
        let cards = Set(cardCosts.keys).union(cardCooldowns.keys)
        return cards.allSatisfy { CardType(rawValue: $0) != nil }
            && ultimateCosts.keys.allSatisfy { Ultimate(rawValue: $0) != nil }
    }

    /// Neue Regeln vom Server übernehmen (nur höhere Versionen). Nicht während einer laufenden Partie aufrufen.
    @discardableResult
    static func adopt(_ remote: RulesConfig) -> Bool {
        guard remote.version > current.version else { return false }
        apply(remote)
        if let data = try? JSONEncoder().encode(remote) {
            try? FileManager.default.createDirectory(at: remoteURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: remoteURL, options: .atomic)
        }
        return true
    }

    /// Für Regeltests und Simulationen: Regeln direkt setzen (ohne Speichern).
    static func apply(_ rules: RulesConfig) {
        current = rules
        costTable = table(rules)
        cooldownTable = cooldowns(rules)
        ultimateTable = ultimateCosts(rules)
    }
}

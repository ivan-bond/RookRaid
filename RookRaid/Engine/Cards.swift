import Foundation

enum CardTargeting {
    case none, single
}

/// Kartenpool – 15 Zauber (v0.9.34 mit Rückzug). Vor der Partie wählt jeder Spieler 4 davon für sein Deck.
/// Die vier Karten bleiben die ganze Partie auf der Hand; nach dem Ausspielen lädt eine Karte
/// `GameState.cardCooldown` eigene Züge nach. Bonusaktionen beenden den Zug nicht – danach folgt noch ein Figurzug.
/// Kosten und Effekte sind mit Simulator-Turnieren abgestimmt (siehe Online-Plan, Abschnitt Karten-Balance).
enum CardType: String, Codable, CaseIterable, Identifiable {
    case shield, freeze, bulwark, sprint, lightning, knighting, reinforce, revive
    case bishopize, advance, swap, drain, focus, sacrifice
    /// v0.9.34: Ein eigener Bauer weicht bis zu zwei Felder zurück.
    case retreat

    var id: String { rawValue }

    var name: String {
        switch self {
        case .shield: return L("Schild")
        case .freeze: return L("Frost")
        case .bulwark: return L("Bollwerk")
        case .sprint: return L("Sturmlauf")
        case .lightning: return L("Blitz")
        case .knighting: return L("Ritterschlag")
        case .reinforce: return L("Verstärkung")
        case .revive: return L("Wiederkehr")
        case .bishopize: return L("Läuferweihe")
        case .advance: return L("Vormarsch")
        case .swap: return L("Leibwache")
        case .drain: return L("Manaraub")
        case .focus: return L("Konzentration")
        case .sacrifice: return L("Bauernopfer")
        case .retreat: return L("Rückzug")
        }
    }

    /// Kosten laut aktuellen Regeln (`rookraid-rules.json`).
    var cost: Int { RulesConfig.costTable[self] ?? defaultCost }

    /// Eingebaute Kosten (Rückfall, falls die Regeldatei eine Karte nicht kennt).
    var defaultCost: Int {
        switch self {
        case .focus, .sacrifice, .drain: return 0
        case .reinforce, .retreat: return 1
        case .bulwark, .shield, .lightning: return 2
        case .advance, .knighting, .bishopize: return 3
        case .sprint: return 3
        case .freeze, .swap: return 4
        case .revive: return 6
        }
    }

    /// Bonusaktionen: Danach machst du noch einen Figurzug.
    /// Abklingzeit in eigenen Zügen (v0.9.24: Blitz 3, alle anderen `GameState.cardCooldown`).
    var cooldown: Int { RulesConfig.cooldownTable[self] ?? GameState.cardCooldown }

    var keepsTurn: Bool {
        switch self {
        case .shield, .freeze, .bulwark, .sprint, .sacrifice, .advance, .swap, .retreat: return true
        default: return false
        }
    }

    /// Schild: Die geschützte Figur darf im folgenden Figurzug nicht ziehen.
    /// (Bei Frost ist das Ziel eine gegnerische Figur – sie steht in ihrem nächsten Zug ohnehin still.)
    /// Rückzug: Das Ziel ist das Feld, auf das der Bauer zurückweicht – er bleibt im Bonuszug stehen.
    var locksTarget: Bool { self == .shield || self == .retreat }

    /// Sturmlauf: Der vorgerückte Bauer darf im Bonuszug nicht noch einmal ziehen.
    var locksMovedPawn: Bool { self == .sprint }

    var icon: String {
        switch self {
        case .shield: return "shield.fill"
        case .freeze: return "snowflake"
        case .bulwark: return "building.columns.fill"
        case .sprint: return "hare.fill"
        case .lightning: return "bolt.fill"
        case .knighting: return "star.fill"
        case .reinforce: return "plus.circle.fill"
        case .revive: return "heart.circle.fill"
        case .bishopize: return "diamond.fill"
        case .advance: return "arrow.up.square.fill"
        case .swap: return "arrow.left.arrow.right"
        case .drain: return "drop.triangle.fill"
        case .focus: return "brain.head.profile"
        case .sacrifice: return "heart.slash.fill"
        case .retreat: return "arrow.down.square.fill"
        }
    }

    var description: String {
        switch self {
        case .shield: return L("Eine eigene Figur kann bis zum Ende des nächsten gegnerischen Zuges nicht geschlagen werden. Danach machst du noch einen Figurzug – mit einer anderen Figur, die geschützte bleibt stehen.")
        case .freeze: return L("Eine gegnerische Figur – nicht König oder Dame – kann in ihrem nächsten Zug nicht ziehen (sie bedroht aber weiter Felder). Danach machst du noch einen Figurzug.")
        case .bulwark: return L("Alle eigenen Bauern sind bis zum Ende des nächsten gegnerischen Zuges geschützt. Danach machst du noch einen Figurzug.")
        case .sprint: return L("Ein eigener Bauer rückt sofort 2 Felder vor (beide Felder müssen frei sein). Danach machst du noch einen Figurzug mit einer anderen Figur.")
        case .lightning: return L("Vernichtet einen gegnerischen Bauern, der in deine Hälfte vorgerückt ist – nur Schild und Bollwerk schützen ihn. Lädt 3 Züge nach.")
        case .knighting: return L("Ein eigener Bauer wird zum Springer.")
        case .reinforce: return L("Ein neuer Bauer erscheint auf einem freien Feld deiner zweiten Reihe.")
        case .revive: return L("Dein wertvollster geschlagener Turm, Läufer oder Springer kehrt auf deine Grundreihe zurück.")
        case .bishopize: return L("Ein eigener Bauer wird zum Läufer.")
        case .advance: return L("Alle eigenen Bauern rücken ein Feld vor, sofern das Feld davor frei ist. Auf die letzte Reihe zieht so kein Bauer. Danach machst du noch einen Figurzug.")
        case .swap: return L("Dein König tauscht den Platz mit einer eigenen Figur (kein Bauer). Danach darf der König nicht mehr rochieren. Danach machst du noch einen Figurzug.")
        case .drain: return L("Dein Gegner verliert die Hälfte seines Manas (abgerundet), du erhältst 2 Mana. Ideal, bevor er seine Ultimate zündet.")
        case .focus: return L("Du sammelst dich: +4 Mana.")
        case .sacrifice: return L("Opfere einen eigenen Bauern und erhalte 3 Mana. Danach machst du noch einen Figurzug.")
        case .retreat: return L("Ein eigener Bauer weicht 1 oder 2 Felder zurück (der Weg muss frei sein, nicht auf die Grundreihe). Danach machst du noch einen Figurzug mit einer anderen Figur.")
        }
    }

    /// Kurze Wirkung für Kacheln im Deck-Editor.
    var shortText: String {
        switch self {
        case .shield: return L("Figur unschlagbar")
        case .freeze: return L("Figur eingefroren")
        case .bulwark: return L("Bauern geschützt")
        case .sprint: return L("Bauer +2 Felder")
        case .lightning: return L("Bauer vernichten")
        case .knighting: return L("Bauer → Springer")
        case .reinforce: return L("Neuer Bauer")
        case .revive: return L("Figur kehrt zurück")
        case .bishopize: return L("Bauer → Läufer")
        case .advance: return L("Alle Bauern vor")
        case .swap: return L("König tauscht")
        case .drain: return L("Halbes Gegner-Mana")
        case .focus: return L("+4 Mana")
        case .sacrifice: return L("Bauer für 3 Mana")
        case .retreat: return L("Bauer bis 2 zurück")
        }
    }

    /// Rolle im Deck – hilft beim Bauen von Strategien.
    var role: CardRole {
        switch self {
        case .sprint, .advance, .knighting, .bishopize: return .attack
        case .freeze, .lightning, .drain: return .control
        case .shield, .bulwark, .swap, .reinforce, .retreat: return .defense
        case .focus, .sacrifice: return .mana
        case .revive: return .comeback
        }
    }

    /// Seltenheit: Startkarten gibt es sofort, alle anderen kommen aus Truhen (oder werden mit Splittern gekauft).
    var tier: CardTier {
        switch self {
        case .lightning, .shield, .sprint, .freeze: return .starter
        case .reinforce, .knighting, .bulwark, .advance, .retreat: return .common
        case .revive, .sacrifice, .swap: return .rare
        case .focus, .drain, .bishopize: return .epic
        }
    }

    var targeting: CardTargeting {
        switch self {
        case .bulwark, .advance, .drain, .focus: return .none
        default: return .single
        }
    }

    var targetPrompt: String {
        switch self {
        case .shield: return L("Wähle eine eigene Figur.")
        case .freeze: return L("Wähle eine gegnerische Figur (nicht König oder Dame).")
        case .bulwark, .advance, .drain, .focus: return ""
        case .sprint, .knighting, .bishopize: return L("Wähle einen eigenen Bauern.")
        case .sacrifice: return L("Wähle den Bauern, den du opferst.")
        case .lightning: return L("Wähle einen gegnerischen Bauern in deiner Hälfte.")
        case .reinforce: return L("Wähle ein freies Feld auf deiner zweiten Reihe.")
        case .revive: return L("Wähle ein freies Feld auf deiner Grundreihe.")
        case .swap: return L("Wähle die Figur, mit der dein König tauscht.")
        case .retreat: return L("Wähle das Feld, auf das dein Bauer zurückweicht.")
        }
    }
}

/// Seltenheitsstufe einer Karte – bestimmt, ab welchem Level sie aus Truhen kommen kann und was sie in Splittern kostet.
enum CardTier: String, Codable, CaseIterable, Comparable {
    case starter, common, rare, epic

    static func < (a: CardTier, b: CardTier) -> Bool { a.order < b.order }
    private var order: Int { CardTier.allCases.firstIndex(of: self) ?? 0 }

    var name: String {
        switch self {
        case .starter: return L("Start")
        case .common: return L("Gewöhnlich")
        case .rare: return L("Selten")
        case .epic: return L("Episch")
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .starter: return 0xA9B4C8
        case .common: return 0x6FBF73
        case .rare: return 0x3FA9F5
        case .epic: return 0xB06CFF
        }
    }

    /// Preis in Splittern (Startkarten sind immer frei).
    var price: Int {
        switch self {
        case .starter: return 0
        case .common: return 500
        case .rare: return 1500
        case .epic: return 3000
        }
    }

    /// Ab diesem Level kann die Stufe aus Truhen kommen oder gekauft werden – neue Spieler lernen erst die einfachen Karten.
    var gateLevel: Int {
        switch self {
        case .starter, .common: return 1
        case .rare: return 5
        case .epic: return 10
        }
    }

    /// Gewicht bei zufälligen Kartenfunden: einfache Karten kommen häufiger.
    var dropWeight: Double {
        switch self {
        case .starter: return 0
        case .common: return 3
        case .rare: return 2
        case .epic: return 1
        }
    }
}

enum CardRole: String, CaseIterable {
    case attack, control, defense, mana, comeback

    var name: String {
        switch self {
        case .attack: return L("Angriff")
        case .control: return L("Kontrolle")
        case .defense: return L("Verteidigung")
        case .mana: return L("Mana")
        case .comeback: return L("Comeback")
        }
    }

    var icon: String {
        switch self {
        case .attack: return "flame.fill"
        case .control: return "snowflake"
        case .defense: return "shield.fill"
        case .mana: return "drop.fill"
        case .comeback: return "arrow.counterclockwise"
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .attack: return 0xE0613A
        case .control: return 0x5BB5D9
        case .defense: return 0x6FBF73
        case .mana: return 0x8B5CF6
        case .comeback: return 0xF2C14E
        }
    }
}

// MARK: - Ultimates

/// Vor der Partie gewählt. Einsetzbar ab 8 Mana – verbraucht dann 8 Mana.
enum Ultimate: String, Codable, CaseIterable, Identifiable {
    case meteor, iceAge, fortress, coronation, rebirth

    var id: String { rawValue }

    var name: String {
        switch self {
        case .meteor: return L("Meteor")
        case .iceAge: return L("Eiszeit")
        case .fortress: return L("Festung")
        case .coronation: return L("Krönung")
        case .rebirth: return L("Wiedergeburt")
        }
    }

    var icon: String {
        switch self {
        case .meteor: return "flame.fill"
        case .iceAge: return "wind.snow"
        case .fortress: return "shield.lefthalf.filled"
        case .coronation: return "crown.fill"
        case .rebirth: return "arrow.counterclockwise.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .meteor: return L("Vernichtet eine gegnerische Figur – außer König und Dame. Ungeschützte gegnerische Bauern direkt daneben können zwei Züge lang nicht ziehen.")
        case .iceAge: return L("Alle gegnerischen Figuren außer dem König können in den nächsten zwei Zügen nicht ziehen.")
        case .fortress: return L("Keine deiner Figuren kann bis zum Ende des nächsten gegnerischen Zuges geschlagen werden. Danach machst du noch einen Figurzug – der darf aber nicht schlagen und kein Schach geben.")
        case .coronation: return L("Ein eigener Bauer wird sofort zur Dame. Hast du noch eine Dame, muss der Bauer in der gegnerischen Hälfte stehen.")
        case .rebirth: return L("Deine wertvollste geschlagene Figur (auch die Dame) kehrt auf deine Grundreihe zurück.")
        }
    }

    var style: String {
        switch self {
        case .meteor: return L("Angriff")
        case .iceAge: return L("Tempo")
        case .fortress: return L("Verteidigung")
        case .coronation: return L("Angriff")
        case .rebirth: return L("Comeback")
        }
    }

    /// In welcher Arena die Ultimate freigeschaltet wird.
    var arena: Int {
        switch self {
        case .meteor, .fortress: return 1
        case .iceAge, .coronation: return 2
        case .rebirth: return 3
        }
    }

    var needsTarget: Bool { self == .meteor || self == .coronation }

    /// Festung ist eine Bonusaktion: Danach folgt noch ein Figurzug.
    var keepsTurn: Bool { self == .fortress }

    /// Mana, ab dem die Ultimate einsetzbar ist – und das sie verbraucht (v0.9.23: Festung 6, alle anderen 8).
    var cost: Int { RulesConfig.ultimateTable[self] ?? GameState.ultimateCost }

    var targetPrompt: String {
        switch self {
        case .meteor: return L("Meteor: Wähle die gegnerische Figur.")
        case .coronation: return L("Krönung: Wähle den Bauern, der zur Dame wird.")
        default: return ""
        }
    }
}

// MARK: - Deck

/// Die vier Karten eines Spielers. Sie bleiben die ganze Partie auf der Hand – es wird nicht nachgezogen.
/// `queue` gibt es nur noch, damit Spielstände aus Version 0.9.4 und älter lesbar bleiben.
struct PlayerDeck: Codable, Equatable {
    static let size = 4

    var hand: [CardType]
    var queue: [CardType]

    /// Festes Deck aus der Deck-Auswahl.
    init(cards: [CardType]) {
        hand = Array(cards.prefix(PlayerDeck.size))
        queue = []
    }

    /// Feste Hand ohne Mischen – für Puzzles und das Tutorial.
    init(hand: [CardType], queue: [CardType] = []) {
        self.hand = hand
        self.queue = queue
    }

    /// Alte Spielstände: rotierender Stapel. Neue Decks haben keinen Stapel.
    mutating func play(at index: Int) {
        guard hand.indices.contains(index), !queue.isEmpty else { return }
        let card = hand[index]
        hand[index] = queue.removeFirst()
        queue.append(card)
    }
}

/// Vorgefertigte Decks: jedes steht für eine Strategie. Sie dienen als Vorlage im Deck-Editor und als Decks der Bots.
struct DeckPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let strategy: String
    let icon: String
    let cards: [CardType]
    let ultimate: Ultimate

    static var all: [DeckPreset] { [
        DeckPreset(id: "sturm", name: L("Sturmangriff"), strategy: L("Bauern nach vorn, Gebiet erobern, Figuren befördern. Krönung macht einen vorgestürmten Bauern zur zweiten Dame."),
                   icon: "flame.fill", cards: [.sprint, .advance, .knighting, .lightning], ultimate: .coronation),
        DeckPreset(id: "eis", name: L("Eiskönig"), strategy: L("Wichtige Figuren einfrieren und dem Gegner das Mana stehlen. Eiszeit legt die ganze Armee lahm."),
                   icon: "snowflake", cards: [.freeze, .drain, .lightning, .shield], ultimate: .iceAge),
        DeckPreset(id: "festung", name: L("Festung"), strategy: L("Nichts hergeben: Schutz für Figuren und Bauern, Nachschub auf der zweiten Reihe – und aus Bauern werden Springer. Festung schützt alles und erlaubt noch einen Zug."),
                   icon: "building.columns.fill", cards: [.shield, .bulwark, .reinforce, .knighting], ultimate: .fortress),
        DeckPreset(id: "ritual", name: L("Ritual"), strategy: L("Mana sammeln, so schnell es geht – und mit dem Meteor früher und öfter zuschlagen als der Gegner."),
                   icon: "drop.fill", cards: [.focus, .sacrifice, .drain, .lightning], ultimate: .meteor),
        DeckPreset(id: "phoenix", name: L("Phönix"), strategy: L("Verluste zahlen sich aus: Geschlagene Figuren kehren zurück, Bauern werden zu Läufern. Wiedergeburt holt sogar die Dame."),
                   icon: "arrow.counterclockwise.circle.fill", cards: [.revive, .reinforce, .sacrifice, .bishopize], ultimate: .rebirth),
        DeckPreset(id: "taktik", name: L("Taktiker"), strategy: L("Bonusaktionen für Doppelschläge: einfrieren, schützen, vorstoßen – und dann zuschlagen."),
                   icon: "scope", cards: [.shield, .freeze, .swap, .sprint], ultimate: .meteor)
    ] }

    static var starter: DeckPreset { DeckPreset(id: "start", name: L("Grundausstattung"), strategy: L("Ein ausgewogenes Deck für den Anfang."),
                                    icon: "square.stack.3d.up.fill", cards: [.lightning, .shield, .sprint, .freeze], ultimate: .meteor) }
}

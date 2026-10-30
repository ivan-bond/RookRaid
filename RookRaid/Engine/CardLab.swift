import Foundation

/// Kartenschule (v0.9.26): zu jeder Karte und Ultimate eine kleine Stellung, in der man sie selbst ausprobiert.
/// Alle Stellungen wurden mit dem Regel-Port im Simulator geprüft (Ziele gültig, Antworten legal, Matts echt).
enum LabItem: Hashable, Identifiable {
    case card(CardType)
    case ultimate(Ultimate)

    var id: String {
        switch self {
        case .card(let c): return "c-" + c.rawValue
        case .ultimate(let u): return "u-" + u.rawValue
        }
    }

    /// Schlüssel für den Fortschritt im Profil
    var key: String { id }

    var name: String {
        switch self {
        case .card(let c): return c.name
        case .ultimate(let u): return u.name
        }
    }

    var art: String {
        switch self {
        case .card(let c): return "art-card-\(c.rawValue)"
        case .ultimate(let u): return "art-ult-\(u.rawValue)"
        }
    }

    var cost: Int {
        switch self {
        case .card(let c): return c.cost
        case .ultimate(let u): return u.cost
        }
    }

    var keepsTurn: Bool {
        switch self {
        case .card(let c): return c.keepsTurn
        case .ultimate(let u): return u.keepsTurn
        }
    }

    /// Reihenfolge der Kartenschule: Startkarten zuerst, dann nach Kosten, zum Schluss die Ultimates.
    static var all: [LabItem] {
        let cards = CardType.allCases.sorted { a, b in
            let sa = a.tier == .starter ? 0 : 1, sb = b.tier == .starter ? 0 : 1
            return sa != sb ? sa < sb : (a.cost != b.cost ? a.cost < b.cost : a.rawValue < b.rawValue)
        }
        return cards.map { LabItem.card($0) } + Ultimate.allCases.map { LabItem.ultimate($0) }
    }
}

struct LabScenario {
    let item: LabItem
    /// Stellung, Weiß am Zug (unten)
    let fen: String
    var mana: Int
    var opponentMana = 0
    /// Bereits geschlagene eigene Figuren (für Wiederkehr und Wiedergeburt)
    var captured: [PieceType] = []
    /// Empfohlenes Ziel der Karte (andere gültige Ziele sind auch erlaubt)
    var target: String? = nil
    /// Rockys Auftrag zu Beginn
    let mission: String
    /// Nach der Karte (bei Bonusaktionen: Aufforderung zum Figurzug)
    var afterCard: String? = nil
    /// Empfohlener Bonuszug (wird als Hinweis markiert)
    var bonusHint: String? = nil
    /// Schlagversuche des Gegners, die die Karte verhindert – als durchgestrichene Pfeile gezeigt
    var blocked: [(String, String)] = []
    var blockedText: String? = nil
    /// Antwort von Schwarz (UCI), falls legal
    var reply: String? = nil
    var replyText: String? = nil
    /// Abschlusszug des Spielers mit Hinweis (z. B. das Matt)
    var finale: String? = nil
    var finaleText: String? = nil
    /// Was man mitnimmt
    let lessons: [String]

    static func scenario(for item: LabItem) -> LabScenario {
        switch item {
        case .card(let c): return card(c)
        case .ultimate(let u): return ultimate(u)
        }
    }

    // MARK: Karten

    private static func card(_ c: CardType) -> LabScenario {
        let item = LabItem.card(c)
        switch c {
        case .shield:
            return LabScenario(item: item, fen: "6k1/6pp/5p2/4N3/8/8/5PPP/6K1 w - - 0 1", mana: 2, target: "e5",
                               mission: L("Der Bauer auf f6 bedroht deinen Springer. Leg einen Schild um ihn – danach darfst du trotzdem noch ziehen!"),
                               afterCard: L("Geschützt! Der Springer bleibt stehen (goldenes Schloss). Mach jetzt einen Zug mit einer anderen Figur."),
                               bonusHint: "g1f1",
                               blocked: [("f6", "e5")], blockedText: L("Abgeprallt! Der Bauer kann den geschützten Springer nicht schlagen."),
                               reply: "h7h6",
                               lessons: [L("Schild schützt eine Figur bis zum Ende des nächsten gegnerischen Zugs."),
                                         L("Bonusaktion: Du ziehst danach noch – nur nicht mit der geschützten Figur."),
                                         L("Perfekt, wenn eine wertvolle Figur hängt und du trotzdem angreifen willst.")])
        case .freeze:
            return LabScenario(item: item, fen: "1r4k1/5ppp/8/1B6/8/8/5PPP/6K1 w - - 0 1", mana: 4, target: "b8",
                               mission: L("Der schwarze Turm zielt auf deinen Läufer. Friere den Turm ein!"),
                               afterCard: L("Eingefroren! Der Turm kann im nächsten Zug nicht ziehen. Du bist noch dran – zieh eine Figur."),
                               bonusHint: "g1f1",
                               blocked: [("b8", "b5")], blockedText: L("Der Turm steckt im Eis fest – kein Schlagen möglich."),
                               reply: "g8f8",
                               lessons: [L("Frost stoppt eine gegnerische Figur für einen Zug (nicht König oder Dame)."),
                                         L("Bonusaktion: Danach machst du noch einen Figurzug."),
                                         L("Friere den Angreifer ein – oder den Verteidiger, bevor du zuschlägst.")])
        case .bulwark:
            return LabScenario(item: item, fen: "6k1/5ppp/4n3/8/3P1P2/8/6PP/6K1 w - - 0 1", mana: 2,
                               mission: L("Der Springer greift gleich zwei Bauern an. Schütze alle Bauern auf einmal!"),
                               afterCard: L("Alle deine Bauern sind geschützt – bis nach dem nächsten Zug von Schwarz. Du bist noch dran."),
                               bonusHint: "g1f1",
                               blocked: [("e6", "d4"), ("e6", "f4")], blockedText: L("Der Springer beißt auf Granit: Kein Bauer lässt sich schlagen."),
                               reply: "g8f8",
                               lessons: [L("Bollwerk schützt alle eigenen Bauern für eine Runde."),
                                         L("Bonusaktion: Danach machst du noch einen Figurzug."),
                                         L("Hilft gegen Gabeln auf Bauern und gegen Blitz.")])
        case .sprint:
            return LabScenario(item: item, fen: "6k1/6pp/3n1r2/8/8/4P3/6PP/6K1 w - - 0 1", mana: 3, target: "e3",
                               mission: L("Dein Bauer auf e3 kann Springer und Turm gleichzeitig angreifen – wenn er schnell genug ist. Sturmlauf!"),
                               afterCard: L("Zwei Felder auf einmal – Gabel! Der Bauer bleibt jetzt stehen. Mach noch einen Zug mit einer anderen Figur."),
                               bonusHint: "g2g3",
                               lessons: [L("Sturmlauf schiebt einen Bauern zwei Felder vor (beide Felder müssen frei sein)."),
                                         L("Bonusaktion: Danach ziehst du noch."),
                                         L("Ideal für Bauerngabeln und um Freibauern nach vorn zu bringen.")])
        case .retreat:
            return LabScenario(item: item, fen: "6k1/5ppp/3p4/4P3/8/8/5PPP/6K1 w - - 0 1", mana: 1, target: "e4",
                               mission: L("Der Bauer d6 greift deinen Bauern e5 an. Zieh ihn mit Rückzug ein Feld zurück auf e4 – dort ist er sicher!"),
                               afterCard: L("Rückzug geglückt! Der Bauer steht sicher und bleibt jetzt stehen. Mach noch einen Zug mit einer anderen Figur."),
                               bonusHint: "g1f1",
                               reply: "h7h6",
                               lessons: [L("Rückzug: Ein eigener Bauer weicht 1 oder 2 Felder zurück – der Weg muss frei sein."),
                                         L("Auf deine Grundreihe geht es nicht, und im Bonuszug bleibt der Bauer stehen."),
                                         L("Rettet bedrohte Bauern, schließt Lücken vor dem König oder lockt den Gegner nach vorn.")])
        case .lightning:
            return LabScenario(item: item, fen: "6k1/5pp1/7p/8/8/2p5/5PPP/6K1 w - - 0 1", mana: 2, target: "c3",
                               mission: L("Ein schwarzer Bauer ist in deine Hälfte gestürmt. Blitz trifft nur dort – probier's!"),
                               afterCard: L("Zack! Der Eindringling ist weg. Die Bauern in der schwarzen Hälfte bleiben verschont."),
                               reply: "g8f8",
                               lessons: [L("Blitz vernichtet einen gegnerischen Bauern in deiner Hälfte – auch einen gedeckten."),
                                         L("Nur Schild und Bollwerk schützen ihn."),
                                         L("Danach lädt Blitz 3 Züge lang nach.")])
        case .knighting:
            return LabScenario(item: item, fen: "6k1/2r1r1pp/8/3P4/8/8/6PP/6K1 w - - 0 1", mana: 3, target: "d5",
                               mission: L("Verwandle deinen Bauern auf d5 in einen Springer – und greif beide Türme an!"),
                               afterCard: L("Hufgetrappel! Der neue Springer bedroht c7 und e7."),
                               reply: "c7c2", replyText: L("Schwarz kann nur einen Turm retten."),
                               finale: "d5e7", finaleText: L("Jetzt schlag zu: Springer nach e7!"),
                               lessons: [L("Ritterschlag macht aus einem eigenen Bauern sofort einen Springer."),
                                         L("Die Karte ersetzt deinen Zug."),
                                         L("Suche Felder, von denen der neue Springer zwei Figuren angreift.")])
        case .bishopize:
            return LabScenario(item: item, fen: "6k1/1r5n/8/8/4P3/8/6PP/6K1 w - - 0 1", mana: 3, target: "e4",
                               mission: L("Aus dem Bauern auf e4 wird ein Läufer – er greift Turm und Springer gleichzeitig an!"),
                               afterCard: L("Geweiht! Der Läufer zielt auf b7 und h7."),
                               reply: "b7b2", replyText: L("Schwarz rettet den Turm."),
                               finale: "e4h7", finaleText: L("Hol dir den Springer auf h7!"),
                               lessons: [L("Läuferweihe macht aus einem eigenen Bauern sofort einen Läufer."),
                                         L("Die Karte ersetzt deinen Zug."),
                                         L("Lange Diagonalen sind die Lieblingsstraßen des neuen Läufers.")])
        case .reinforce:
            return LabScenario(item: item, fen: "6k1/1q3ppp/8/8/8/8/5P1P/6K1 w - - 0 1", mana: 1, target: "g2",
                               mission: L("Die schwarze Dame zielt auf g2 – direkt neben deinen König. Stell einen neuen Bauern als Schutzschild hin!"),
                               afterCard: L("Ein frischer Bauer steht auf deiner zweiten Reihe und sperrt die Diagonale."),
                               lessons: [L("Verstärkung setzt einen neuen Bauern auf ein freies Feld deiner zweiten Reihe."),
                                         L("Ersetzt deinen Zug und kostet nur 1 Mana."),
                                         L("Stopft Löcher vor dem König und sperrt Linien.")])
        case .revive:
            return LabScenario(item: item, fen: "6k1/p4ppp/8/8/8/8/5PPP/6K1 w - - 0 1", mana: 6, captured: [.rook], target: "e1",
                               mission: L("Dein Turm wurde geschlagen. Hol ihn zurück – am besten auf e1!"),
                               afterCard: L("Der Turm ist wieder da!"),
                               reply: "a7a6",
                               finale: "e1e8", finaleText: L("Die schwarze Grundreihe ist offen. Turm nach e8 – Matt!"),
                               lessons: [L("Wiederkehr holt deinen wertvollsten geschlagenen Turm, Läufer oder Springer auf deine Grundreihe."),
                                         L("Ersetzt deinen Zug und kostet 6 Mana."),
                                         L("Das Comeback, wenn du Material verloren hast.")])
        case .sacrifice:
            return LabScenario(item: item, fen: "6k1/5ppp/8/8/8/8/PP3PPP/6K1 w - - 0 1", mana: 0, target: "a2",
                               mission: L("Kein Mana? Opfere einen Bauern – dafür bekommst du sofort +3 Mana."),
                               afterCard: L("+3 Mana! Und weil Bauernopfer eine Bonusaktion ist, darfst du jetzt noch ziehen."),
                               bonusHint: "g1f1",
                               lessons: [L("Bauernopfer: Ein eigener Bauer verschwindet, du bekommst +3 Mana."),
                                         L("Bonusaktion: Danach machst du noch einen Figurzug."),
                                         L("Lohnt sich, wenn das Mana eine starke Karte oder deine Ultimate freischaltet.")])
        case .focus:
            return LabScenario(item: item, fen: "6k1/5ppp/8/8/8/8/5PPP/6K1 w - - 0 1", mana: 1,
                               mission: L("Konzentration: Lade dein Mana auf einen Schlag um +4 auf."),
                               afterCard: L("Von 1 auf 5 Mana – jetzt sind Frost oder Leibwache drin."),
                               lessons: [L("Konzentration bringt sofort +4 Mana."),
                                         L("Kostet 0 Mana, ersetzt aber deinen Zug."),
                                         L("Gut, wenn gerade nichts brennt und du auf deine Ultimate sparst.")])
        case .drain:
            return LabScenario(item: item, fen: "6k1/5ppp/8/8/8/8/5PPP/6K1 w - - 0 1", mana: 0, opponentMana: 8,
                               mission: L("Schwarz hat 8 Mana – gleich kommt seine Ultimate! Klau ihm die Hälfte."),
                               afterCard: L("Schwarz verliert die Hälfte seines Manas, du bekommst 2 dazu."),
                               lessons: [L("Manaraub: Der Gegner verliert die Hälfte seines Manas, du erhältst 2."),
                                         L("Kostet 0 Mana, ersetzt deinen Zug."),
                                         L("Spiel ihn, kurz bevor der Gegner seine Ultimate zünden kann.")])
        case .advance:
            return LabScenario(item: item, fen: "6k1/5ppp/8/8/8/8/PPP2PPP/6K1 w - - 0 1", mana: 3,
                               mission: L("Alle Bauern – marsch! Vormarsch schiebt jeden Bauern ein Feld vor."),
                               afterCard: L("Die ganze Bauernreihe ist vorgerückt. Bonusaktion: Zieh jetzt noch eine Figur."),
                               bonusHint: "g1f1",
                               lessons: [L("Vormarsch: Alle eigenen Bauern rücken ein Feld vor, wenn davor frei ist."),
                                         L("Kein Bauer erreicht so die letzte Reihe."),
                                         L("Bonusaktion für 3 Mana – stark, wenn viele Bauern frei vorrücken können.")])
        case .swap:
            return LabScenario(item: item, fen: "4r1k1/5ppp/8/8/8/8/4BPPP/4K2R w - - 0 1", mana: 4, target: "h1",
                               mission: L("Dein Läufer ist an den König gefesselt. Tausch den König mit dem Turm – die Leibwache befreit den Läufer!"),
                               afterCard: L("Platztausch! Der Turm schützt jetzt die e-Linie. Zieh den Läufer, wohin du willst."),
                               bonusHint: "e2b5",
                               lessons: [L("Leibwache: Dein König tauscht den Platz mit einer eigenen Figur (kein Bauer)."),
                                         L("Danach darf der König nicht mehr rochieren."),
                                         L("Bonusaktion für 4 Mana – rettet den König aus Fesselungen und Mattnetzen.")])
        }
    }

    // MARK: Ultimates

    private static func ultimate(_ u: Ultimate) -> LabScenario {
        let item = LabItem.ultimate(u)
        switch u {
        case .meteor:
            return LabScenario(item: item, fen: "3r2k1/p4ppp/8/8/8/8/5PPP/4R1K1 w - - 0 1", mana: 8, target: "d8",
                               mission: L("Der Turm auf d8 bewacht die schwarze Grundreihe. Lass einen Meteor auf ihn regnen!"),
                               afterCard: L("Volltreffer! Der Verteidiger ist weg."),
                               reply: "a7a6",
                               finale: "e1e8", finaleText: L("Die Grundreihe ist offen: Turm nach e8 – Matt!"),
                               lessons: [L("Meteor vernichtet eine gegnerische Figur (nicht König oder Dame)."),
                                         L("Ungeschützte Bauern daneben können zwei Züge lang nicht ziehen."),
                                         L("Ab 8 Mana – räum den wichtigsten Verteidiger ab.")])
        case .iceAge:
            return LabScenario(item: item, fen: "r5k1/5ppp/8/8/8/8/3Q1PPP/6K1 w - - 0 1", mana: 8,
                               mission: L("Der Turm auf a8 würde deine Dame auf d8 schlagen. Friere die ganze schwarze Armee ein!"),
                               afterCard: L("Eiszeit! Alle schwarzen Figuren außer dem König stecken fest."),
                               reply: "g8h8", replyText: L("Nur der König kann sich noch bewegen."),
                               finale: "d2d8", finaleText: L("Dame nach d8 – der eingefrorene Turm kann nicht helfen. Matt!"),
                               lessons: [L("Eiszeit friert alle gegnerischen Figuren außer dem König ein."),
                                         L("Ersetzt deinen Zug, ab 8 Mana."),
                                         L("Perfekt, um einen Mattangriff gegen jede Verteidigung durchzuziehen.")])
        case .fortress:
            return LabScenario(item: item, fen: "6k1/5ppp/8/3p4/2B1N3/8/5PPP/6K1 w - - 0 1", mana: 6,
                               mission: L("Der Bauer auf d5 greift Läufer und Springer gleichzeitig an. Bau eine Festung!"),
                               afterCard: L("Alles geschützt! Jetzt noch ein Zug – aber ohne Schlagen und ohne Schach."),
                               bonusHint: "g1f1",
                               blocked: [("d5", "c4"), ("d5", "e4")], blockedText: L("Der Bauer kommt an keiner Figur vorbei – die Festung hält."),
                               reply: "g8f8",
                               lessons: [L("Festung: Keine deiner Figuren kann im nächsten gegnerischen Zug geschlagen werden."),
                                         L("Danach noch ein Figurzug – ohne Schlagen und ohne Schach."),
                                         L("Schon ab 6 Mana.")])
        case .coronation:
            return LabScenario(item: item, fen: "6k1/p4ppp/8/4P3/8/8/5PPP/6K1 w - - 0 1", mana: 8, target: "e5",
                               mission: L("Krön deinen Bauern auf e5 – er wird sofort zur Dame!"),
                               afterCard: L("Eine neue Dame ist geboren!"),
                               reply: "a7a6",
                               finale: "e5e8", finaleText: L("Lang lebe die Dame: nach e8 – Matt!"),
                               lessons: [L("Krönung macht aus einem eigenen Bauern eine Dame."),
                                         L("Hast du schon eine Dame, nur Bauern in der gegnerischen Hälfte."),
                                         L("Ab 8 Mana.")])
        case .rebirth:
            return LabScenario(item: item, fen: "6k1/5ppp/8/8/8/8/5PPP/6K1 w - - 0 1", mana: 8, captured: [.queen],
                               mission: L("Deine Dame ist gefallen? Wiedergeburt holt sie zurück!"),
                               afterCard: L("Die Dame ist zurück auf deiner Grundreihe."),
                               lessons: [L("Wiedergeburt holt deine wertvollste geschlagene Figur zurück – auch die Dame."),
                                         L("Ersetzt deinen Zug, ab 8 Mana."),
                                         L("Das große Comeback.")])
        }
    }

    /// Startstellung mit Hand, Mana und geschlagenen Figuren.
    func makeState() -> GameState? {
        guard var s = GameState.fromFEN(fen) else { return nil }
        switch item {
        case .card(let c):
            s.decks[.white] = PlayerDeck(hand: [c], queue: [])
        case .ultimate(let u):
            s.decks[.white] = PlayerDeck(hand: [], queue: [])
            s.ultimates[.white] = u
        }
        s.decks[.black] = PlayerDeck(hand: [], queue: [])
        s.mana[.white] = mana
        s.mana[.black] = opponentMana
        s.captured[.white] = captured.map { Piece($0, .white) }
        return s
    }
}

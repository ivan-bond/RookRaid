import Foundation

// MARK: - Bot-Charaktere

/// Die zwölf Bots – dieselben Charaktere in der Bot-Leiter und im Kampf (Gegner nach Trophäen, alle 200 eine Stufe).
/// Die Rohwerte bleiben stabil, damit Spielstände und Verlauf lesbar bleiben; die Reihenfolge der Fälle ist die Stufe.
enum BotLevel: String, Codable, CaseIterable, Identifiable {
    case easy        // 1 Bruno
    case apprentice  // 2 Lotte
    case medium      // 3 Mila
    case jester      // 4 Kasimir (neu in v0.9.11)
    case knight      // 5 Sir Konrad
    case tactician   // 6 Frieda Falk
    case shadow      // 7 Nox (neu)
    case baron       // 8 Baron Rabe
    case hard        // 9 Viktor
    case frost       // 10 Magnus Frost (neu)
    case sphinx      // 11 Die Sphinx (neu)
    case queen       // 12 Die Turmkönigin

    var id: String { rawValue }

    /// Stufe 1–12
    var tier: Int { (BotLevel.allCases.firstIndex(of: self) ?? 0) + 1 }

    /// Trophäen pro Stufe im Kampf
    static let trophiesPerTier = 200

    /// Ab dieser Trophäenzahl ist der Bot der Kampf-Gegner.
    var trophyStart: Int { (tier - 1) * BotLevel.trophiesPerTier }

    /// Trophäenwert der Stufe (Mitte des 200er-Bands). Dieselbe Zahl wie `bot_rating` auf dem Server.
    var rating: Int { trophyStart + BotLevel.trophiesPerTier / 2 }

    /// Gegner passend zu den Trophäen: alle 200 Trophäen eine stärkere Stufe.
    static func forTrophies(_ trophies: Int) -> BotLevel {
        let i = min(BotLevel.allCases.count - 1, max(0, trophies / trophiesPerTier))
        return BotLevel.allCases[i]
    }

    var trophyRange: String {
        let lo = trophyStart
        return tier == BotLevel.allCases.count ? L("ab {0}", lo) : "\(lo)–\(lo + BotLevel.trophiesPerTier - 1)"
    }

    var name: String { L("Stufe {0}", tier) }

    /// Deutscher Name – bleibt im Partieverlauf gespeichert (unabhängig von der Sprache).
    var canonicalName: String {
        switch self {
        case .easy: return "Bruno"
        case .apprentice: return "Lotte"
        case .medium: return "Mila"
        case .jester: return "Kasimir"
        case .knight: return "Sir Konrad"
        case .tactician: return "Frieda Falk"
        case .shadow: return "Nox"
        case .baron: return "Baron Rabe"
        case .hard: return "Viktor"
        case .frost: return "Magnus Frost"
        case .sphinx: return "Die Sphinx"
        case .queen: return "Die Turmkönigin"
        }
    }

    /// Name in der gewählten Sprache
    var displayName: String { L(canonicalName) }

    var botName: String { "Bot " + canonicalName }

    var title: String {
        switch self {
        case .easy: return L("der Bauer")
        case .apprentice: return L("die Lehrling")
        case .medium: return L("die Magierin")
        case .jester: return L("der Gaukler")
        case .knight: return L("der Ritter")
        case .tactician: return L("die Taktikerin")
        case .shadow: return L("der Schatten")
        case .baron: return L("der Verteidiger")
        case .hard: return L("der Vernichter")
        case .frost: return L("der Eisherr")
        case .sphinx: return L("die Allwissende")
        case .queen: return L("Herrin der Arena")
        }
    }

    var motto: String {
        switch self {
        case .easy: return L("Schiebt gern Bauern und vergisst dabei seine Figuren.")
        case .apprentice: return L("Kennt die Regeln, aber noch nicht die Fallen.")
        case .medium: return L("Spielt Karten, wann immer sie kann.")
        case .jester: return L("Liebt Tricks – und fällt manchmal auf seine eigenen herein.")
        case .knight: return L("Liebt Springergabeln und Angriffe auf den König.")
        case .tactician: return L("Lauert auf Fesselungen und offene Figuren.")
        case .shadow: return L("Schleicht sich an – und schlägt zu, wenn du nicht hinsiehst.")
        case .baron: return L("Verteidigt zäh und schlägt spät zurück.")
        case .hard: return L("Rechnet weit voraus und verzeiht keinen Fehler.")
        case .frost: return L("Friert dein Spiel ein, bis nichts mehr geht.")
        case .sphinx: return L("Kennt jede Antwort, bevor du die Frage stellst.")
        case .queen: return L("Der Endgegner von Rook Raid.")
        }
    }

    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .apprentice: return "book.fill"
        case .medium: return "wand.and.stars"
        case .jester: return "theatermasks.fill"
        case .knight: return "shield.lefthalf.filled"
        case .tactician: return "scope"
        case .shadow: return "moon.stars.fill"
        case .baron: return "building.columns.fill"
        case .hard: return "bolt.fill"
        case .frost: return "snowflake"
        case .sphinx: return "eye.fill"
        case .queen: return "crown.fill"
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .easy: return 0x6FBF73
        case .apprentice: return 0x5BB5D9
        case .medium: return 0x8B5CF6
        case .jester: return 0xF06BA8
        case .knight: return 0x2F6FE4
        case .tactician: return 0xE39B3A
        case .shadow: return 0x5A4E9C
        case .baron: return 0x7E8AA3
        case .hard: return 0xE0413A
        case .frost: return 0x7FD3F5
        case .sphinx: return 0xC9A96E
        case .queen: return 0xF2C14E
        }
    }

    /// Eigenes Figurenset des Charakters – mit diesen Figuren spielt er gegen dich.
    var skinName: String {
        switch self {
        case .easy: return L("Grüner Hain")
        case .apprentice: return L("Bibliothek")
        case .medium: return L("Sternenzauber")
        case .jester: return L("Harlekin")
        case .knight: return L("Silberwacht")
        case .tactician: return L("Falkenauge")
        case .shadow: return L("Mitternacht")
        case .baron: return L("Rabenfeste")
        case .hard: return L("Glutriss")
        case .frost: return L("Ewiges Eis")
        case .sphinx: return L("Wüstenorakel")
        case .queen: return L("Goldene Krone")
        }
    }

    /// Bevorzugte Ultimate des Charakters (Leiter-Modus).
    var ultimate: Ultimate {
        switch self {
        case .easy: return .fortress
        case .apprentice: return .meteor
        case .medium: return .iceAge
        case .jester: return .coronation
        case .knight: return .coronation
        case .tactician: return .meteor
        case .shadow: return .meteor
        case .baron: return .fortress
        case .hard: return .rebirth
        case .frost: return .iceAge
        case .sphinx: return .rebirth
        case .queen: return .iceAge
        }
    }

    /// Deck des Charakters (Leiter-Modus) – passend zu seinem Spielstil.
    var deck: [CardType] {
        switch self {
        // v0.9.34: Bruno ist der erste Gegner – bewusst schwaches Deck (vorher Sturmlauf, Vormarsch, Verstärkung, Blitz)
        case .easy: return [.reinforce, .bulwark, .sprint, .retreat]
        case .apprentice: return [.lightning, .shield, .sprint, .freeze]
        case .medium: return [.freeze, .drain, .focus, .lightning]
        case .jester: return [.swap, .sprint, .sacrifice, .knighting]
        case .knight: return [.knighting, .sprint, .shield, .advance]
        case .tactician: return [.shield, .freeze, .swap, .sprint]
        case .shadow: return [.freeze, .lightning, .advance, .sprint]
        case .baron: return [.freeze, .advance, .shield, .focus]
        case .hard: return [.freeze, .advance, .shield, .focus]
        case .frost: return [.freeze, .advance, .shield, .focus]
        case .sphinx: return [.freeze, .advance, .focus, .sprint]
        case .queen: return [.freeze, .advance, .swap, .focus]
        }
    }

    /// XP für den ersten Sieg in der Leiter; jeder weitere Sieg bringt 10 XP.
    var xpFirstWin: Int { [30, 35, 40, 50, 60, 70, 80, 95, 110, 130, 150, 200][tier - 1] }

    /// Suchparameter – mit Turnieren im Simulator abgestimmt. Gilt für Leiter und Kampf gleichermaßen.
    var profile: BotProfile {
        switch self {
        case .easy:
            return BotProfile(maxDepth: 1, deepProb: 1, qDepth: 2, qProb: 1, noise: 0.75, blunder: 0.07,
                              cardSkill: 0.65, targetLimit: 4, smartTargets: false, nodeLimit: 12_000, timeLimit: 0.4, useV2: false)
        case .apprentice:
            return BotProfile(maxDepth: 2, deepProb: 0.6, qDepth: 3, qProb: 1, noise: 0.4, blunder: 0.03,
                              cardSkill: 0.8, targetLimit: 5, smartTargets: false, nodeLimit: 30_000, timeLimit: 0.5, useV2: true)
        case .medium:
            return BotProfile(maxDepth: 2, deepProb: 1, qDepth: 3, qProb: 1, noise: 0.26, blunder: 0.015,
                              cardSkill: 0.9, targetLimit: 6, smartTargets: false, nodeLimit: 60_000, timeLimit: 0.6, useV2: true,
                              cardReplies: true)
        case .jester:
            return BotProfile(maxDepth: 3, deepProb: 0.65, qDepth: 4, qProb: 1, noise: 0.16, blunder: 0.008,
                              cardSkill: 1, targetLimit: 8, smartTargets: false, nodeLimit: 110_000, timeLimit: 0.8, useV2: true,
                              cardReplies: true)
        case .knight:
            return BotProfile(maxDepth: 3, deepProb: 1, qDepth: 5, qProb: 1, noise: 0.12, blunder: 0.004,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 180_000, timeLimit: 1, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        case .tactician:
            return BotProfile(maxDepth: 4, deepProb: 1, qDepth: 5, qProb: 1, noise: 0.05, blunder: 0.0015,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 380_000, timeLimit: 1.6, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        // v0.9.23: Stufen 7–12 neu abgestimmt – mehr Knoten und Denkzeit, kein Zufall mehr (Simulator geprüft)
        case .shadow:
            return BotProfile(maxDepth: 5, deepProb: 0.7, qDepth: 5, qProb: 1, noise: 0.01, blunder: 0,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 700_000, timeLimit: 2.2, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        case .baron:
            return BotProfile(maxDepth: 5, deepProb: 0.8, qDepth: 6, qProb: 1, noise: 0.01, blunder: 0,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 800_000, timeLimit: 2.4, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        case .hard:
            return BotProfile(maxDepth: 5, deepProb: 1, qDepth: 6, qProb: 1, noise: 0, blunder: 0,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 1_200_000, timeLimit: 3, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        case .frost:
            return BotProfile(maxDepth: 6, deepProb: 1, qDepth: 6, qProb: 1, noise: 0, blunder: 0,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 2_000_000, timeLimit: 4.5, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        case .sphinx:
            return BotProfile(maxDepth: 7, deepProb: 1, qDepth: 7, qProb: 1, noise: 0, blunder: 0,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 3_000_000, timeLimit: 6, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        case .queen:
            return BotProfile(maxDepth: 8, deepProb: 1, qDepth: 8, qProb: 1, noise: 0, blunder: 0,
                              cardSkill: 1, targetLimit: 8, smartTargets: true, nodeLimit: 4_500_000, timeLimit: 8, useV2: true,
                              cardReplies: true, v3: true, tt: true)
        }
    }

    /// Seit v0.9.11 identisch mit `profile` (Leiter und Kampf nutzen dieselben Bots).
    var ladderProfile: BotProfile { profile }
}

/// Wie stark ein Bot rechnet. Die Stärke hängt am Knotenbudget (geräteunabhängig);
/// `timeLimit` ist nur die harte Obergrenze der Denkzeit.
struct BotProfile {
    /// Maximale Suchtiefe in Halbzügen (iterative Vertiefung)
    let maxDepth: Int
    /// Wahrscheinlichkeit, die volle Tiefe zu nutzen – sonst eine weniger. Glättet die Sprünge zwischen Stufen.
    let deepProb: Double
    /// Tiefe der Ruhesuche (nur Schlagzüge) am Ende der Hauptsuche
    let qDepth: Int
    let qProb: Double
    /// Zufallsanteil bei der Zugwahl (in Bauerneinheiten)
    let noise: Double
    /// Wahrscheinlichkeit eines zufälligen Zugs (grober Patzer)
    let blunder: Double
    /// Wahrscheinlichkeit, eine Karte auf der Hand überhaupt in Betracht zu ziehen
    let cardSkill: Double
    let targetLimit: Int
    /// Alle Kartenziele prüfen statt nur einer Stichprobe
    let smartTargets: Bool
    let nodeLimit: Int
    /// Harte Obergrenze der Denkzeit in Sekunden
    let timeLimit: Double
    /// Erweiterte Bewertung: Königssicherheit, Entwicklung, Endspiel-Technik, Ultimate-Drohung
    let useV2: Bool
    /// Gegnerische Karten und Ultimate als Antwort mitrechnen (eine Ebene unter der Wurzel)
    var cardReplies: Bool = false
    /// v3-Suche: Killer- und Verlaufs-Sortierung, kein Abbruch der Suche im Schach
    var v3: Bool = false
    /// Transpositionstabelle (bekannte Stellungen abkürzen, bester Zug zuerst)
    var tt: Bool = false
    /// Late Move Reductions: späte ruhige Züge erst flacher prüfen
    var lmr: Bool = false
    /// v3-Bewertung: Bauernstruktur, Freibauern, Läuferpaar, Türme auf offenen Linien
    var evalV3: Bool = false
}

/// Entscheidung des Bots: genau eine Aktion.
enum AIDecision {
    case move(Move)
    case card(CardType, handIndex: Int, target: Square?)
    case ultimate(target: Square?)
}

// MARK: - Suche

private struct SearchAbort: Error {}

private final class SearchContext {
    var nodes = 0
    let nodeLimit: Int
    let deadline: UInt64
    let qDepth: Int
    let useV2: Bool
    let cardReplies: Bool
    var killers: [Int: Move] = [:]
    // v3
    let v3: Bool
    let lmr: Bool
    let useV3Eval: Bool
    let maxPly: Int
    let tt: TranspositionTable?
    var killers2: [Int: Move] = [:]
    var history = [Int32](repeating: 0, count: 4096)

    init(nodeLimit: Int, seconds: Double, qDepth: Int, profile p: BotProfile) {
        self.nodeLimit = nodeLimit
        self.deadline = DispatchTime.now().uptimeNanoseconds + UInt64(seconds * 1_000_000_000)
        self.qDepth = qDepth
        self.useV2 = p.useV2
        self.cardReplies = p.cardReplies
        self.v3 = p.v3
        self.lmr = p.lmr
        self.useV3Eval = p.evalV3
        self.maxPly = p.maxDepth + 6
        self.tt = p.tt ? TranspositionTable() : nil
    }

    func tick() throws {
        nodes += 1
        if nodes & 255 == 0, nodes > nodeLimit || DispatchTime.now().uptimeNanoseconds > deadline {
            throw SearchAbort()
        }
    }
}

private struct RootAction {
    let decision: AIDecision
    let child: GameState
    let bonus: Double
}

/// Such-KI: iterative Vertiefung mit Alpha-Beta, Ruhesuche und Killerzügen.
/// Karten und Ultimate werden an der Wurzel wie Züge bewertet; Bonuskarten zusammen mit dem besten Folgezug.
enum AIPlayer {

    /// `maxSeconds`: Obergrenze aus der Schachuhr (v0.9.23) – starke Bots denken bis zu 8 s, dürfen dabei aber nie die Zeit überschreiten.
    static func decide(_ state: GameState, level: BotLevel, ladder: Bool = false, maxSeconds: Double? = nil) -> AIDecision? {
        let p = ladder ? level.ladderProfile : level.profile
        let seconds = max(0.3, min(p.timeLimit, maxSeconds ?? p.timeLimit))
        let me = state.current
        var depthCap = p.maxDepth
        if depthCap > 1, Double.random(in: 0..<1) > p.deepProb { depthCap -= 1 }
        var q = p.qDepth
        if q > 0, Double.random(in: 0..<1) > p.qProb { q -= 1 }
        let ctx = SearchContext(nodeLimit: p.nodeLimit, seconds: seconds, qDepth: q, profile: p)
        let start = DispatchTime.now().uptimeNanoseconds

        var actions = rootActions(state, profile: p)
        guard !actions.isEmpty else { return nil }
        var completed: [(action: RootAction, score: Double)] = []
        // Teilergebnis der laufenden Tiefe (v3): bei Zeitablauf zählen die schon tiefer geprüften Kandidaten
        var partial: [(action: RootAction, score: Double)] = []

        do {
            for d in 1...max(1, depthCap) {
                var scored: [(action: RootAction, score: Double)] = []
                partial = []
                var alpha = -Double.infinity
                // Fenster so breit wie das Rauschen: Schranken außerhalb werden nie gewählt
                let margin = p.noise + 0.05
                for a in actions {
                    let sc = try score(a, me: me, depth: d, alpha: alpha - margin, ctx: ctx) + a.bonus
                    scored.append((a, sc))
                    partial = scored
                    if sc > alpha { alpha = sc }
                }
                completed = scored.sorted { $0.score > $1.score }
                actions = completed.map { $0.action }
                if abs(completed[0].score) > 9_000 { break }
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
                if elapsed > seconds * 0.45 || Double(ctx.nodes) > Double(p.nodeLimit) * 0.3 { break }
            }
        } catch {
            // Zeit oder Knotenbudget erschöpft: Ergebnis der letzten vollständigen Tiefe gilt.
            // v3: Der bisher beste Zug wird in jeder Tiefe zuerst gerechnet – was davon schon fertig ist, ist genauer.
            if p.v3 && !partial.isEmpty && !completed.isEmpty {
                completed = partial.sorted { $0.score > $1.score }
            }
        }
        guard !completed.isEmpty else { return actions.first?.decision }

        // Wiederholungen: Wer vorne liegt, meidet sie; wer hinten liegt, nimmt sie gern.
        if !state.positionHistory.isEmpty {
            let lead = completed[0].score
            completed = completed.map { item in
                guard case .move = item.action.decision else { return item }
                let key = item.action.child.positionKey()
                guard state.positionHistory.contains(key) else { return item }
                return (item.action, item.score + (lead > 0.5 ? -0.8 : (lead < -0.5 ? 0.4 : 0)))
            }.sorted { $0.score > $1.score }
        }

        var pick = completed[0]
        if p.noise > 0 {
            pick = completed.map { ($0, $0.score + Double.random(in: 0...p.noise)) }
                .max { $0.1 < $1.1 }?.0 ?? pick
        }
        if p.blunder > 0, Double.random(in: 0..<1) < p.blunder {
            let moves = completed.filter { item in
                if case .move = item.action.decision { return true }
                return false
            }
            if let r = moves.randomElement() { pick = r }
        }
        return pick.action.decision
    }

    private static func rootActions(_ state: GameState, profile p: BotProfile) -> [RootAction] {
        let me = state.current
        var out: [RootAction] = []
        for m in ordered(state.allLegalMoves(for: me), in: state) {
            var c = state
            c.makeMove(m)
            out.append(RootAction(decision: .move(m), child: c, bonus: 0))
        }
        // Nach Schild oder Frost bleibt nur noch der Figurzug.
        if state.bonusActionUsed { return out }

        if let hand = state.decks[me]?.hand {
            for (i, card) in hand.enumerated() {
                if Double.random(in: 0..<1) > p.cardSkill { continue }   // schwache Bots übersehen Karten
                guard state.canPlay(card, player: me) else { continue }
                let all: [Square?] = card.targeting == .none
                    ? [nil]
                    : state.targets(for: card, player: me).map { Optional($0) }
                let targets = p.smartTargets ? all : Array(all.shuffled().prefix(p.targetLimit))
                for t in targets {
                    var c = state
                    c.playCard(card, handIndex: i, target: t)
                    out.append(RootAction(decision: .card(card, handIndex: i, target: t), child: c,
                                          bonus: card.keepsTurn ? -0.15 : -0.1))
                }
            }
        }

        if state.canUseUltimate(me) {
            let list = state.ultimateTargets(me)
            let targets: [Square?] = list.isEmpty ? [nil] : list.map { Optional($0) }
            for t in targets {
                var c = state
                c.useUltimate(target: t)
                out.append(RootAction(decision: .ultimate(target: t), child: c, bonus: 0))
            }
        }
        return out
    }

    private static func score(_ a: RootAction, me: PlayerColor, depth: Int, alpha: Double, ctx: SearchContext) throws -> Double {
        let c = a.child
        if c.current == me {
            // Bonuskarte: Wir ziehen gleich noch – bester Folgezug bei gleicher Tiefe.
            var best = -Double.infinity
            for m in ordered(c.allLegalMoves(for: me), in: c) {
                var g = c
                g.makeMove(m)
                let v = -(try negamax(g, depth: depth - 1, alpha: -Double.infinity, beta: -max(alpha, best), ply: 1, ctx: ctx))
                if v > best { best = v }
            }
            return best
        }
        return -(try negamax(c, depth: depth - 1, alpha: -Double.infinity, beta: -alpha, ply: 1, ctx: ctx))
    }

    private static func negamax(_ s: GameState, depth: Int, alpha: Double, beta: Double, ply: Int, ctx: SearchContext) throws -> Double {
        try ctx.tick()
        let me = s.current
        var depth = depth
        let inCheck = ctx.v3 ? s.isInCheck(me) : false
        // Schach am Horizont: nicht in die Ruhesuche fallen (sonst übersieht der Bot Matt-Netze)
        if depth <= 0 && inCheck && ply < ctx.maxPly { depth = 1 }
        if depth <= 0 {
            if ctx.qDepth > 0 { return try quiesce(s, alpha: alpha, beta: beta, depth: ctx.qDepth, ctx: ctx) }
            if let t = leafTerminal(s) { return t }
            return evaluate(s, me, ctx)
        }
        var alpha = alpha
        let alpha0 = alpha
        var best = -Double.infinity
        var anyLegal = false

        // Transpositionstabelle: bekannte Stellung abkürzen, bester Zug zuerst
        var key: UInt64 = 0
        var slot = -1
        var ttMove = -1
        if let tt = ctx.tt, ply > 1 {
            key = AIPlayer.searchHash(s)
            slot = Int(truncatingIfNeeded: key) & TranspositionTable.mask
            if tt.keys[slot] == key && tt.depths[slot] >= 0 {
                ttMove = Int(tt.moves[slot])
                if Int(tt.depths[slot]) >= depth && abs(tt.values[slot]) < 9_000 {
                    let v = tt.values[slot]
                    switch tt.flags[slot] {
                    case 0: return v
                    case 1: if v >= beta { return v }
                    default: if v <= alpha { return v }
                    }
                }
            }
        }

        var moves: [Move]
        if ctx.v3 {
            moves = orderedV3(pseudoAll(s, me), in: s, ply: ply, ctx: ctx, ttMove: ttMove)
        } else {
            moves = ordered(pseudoAll(s, me), in: s)
            if let k = ctx.killers[ply], let i = moves.firstIndex(of: k), i > 0, s[k.to] == nil {
                moves.remove(at: i)
                moves.insert(k, at: 0)
            }
        }
        var bestMove = -1
        var index = 0
        for m in moves {
            let quiet = s[m.to] == nil && !m.isEnPassant
            var child = s
            child.makeMove(m)
            if child.isInCheck(me) { continue }
            anyLegal = true
            var sc: Double
            // Späte, ruhige Züge erst flacher prüfen; nur wenn sie vielversprechend sind, voll nachrechnen
            if ctx.lmr && depth >= 3 && index >= 3 && quiet && !inCheck && !child.isInCheck(child.current) {
                sc = -(try negamax(child, depth: depth - 2, alpha: -alpha - 0.01, beta: -alpha, ply: ply + 1, ctx: ctx))
                if sc > alpha {
                    sc = -(try negamax(child, depth: depth - 1, alpha: -beta, beta: -alpha, ply: ply + 1, ctx: ctx))
                }
            } else {
                sc = -(try negamax(child, depth: depth - 1, alpha: -beta, beta: -alpha, ply: ply + 1, ctx: ctx))
            }
            index += 1
            if sc > best {
                best = sc
                bestMove = m.from.index * 64 + m.to.index
            }
            if best > alpha { alpha = best }
            if alpha >= beta {
                if quiet {
                    if ctx.v3 {
                        if ctx.killers[ply] != m {
                            ctx.killers2[ply] = ctx.killers[ply]
                            ctx.killers[ply] = m
                        }
                        let h = m.from.index * 64 + m.to.index
                        ctx.history[h] = ctx.history[h] &+ Int32(depth * depth)
                    } else {
                        ctx.killers[ply] = m
                    }
                }
                break
            }
        }
        if !anyLegal {
            // Keine Figurzüge = Matt oder Patt, auch wenn noch Karten spielbar wären
            return s.isInCheck(me) ? -10_000 - Double(depth) : 0
        }
        // Gegnerische Karten und Ultimate als Antwort – nur direkt unter der Wurzel, mit wenigen Zielen
        if ply == 1 && ctx.cardReplies && !s.bonusActionUsed && alpha < beta {
            for child in cardChildren(s, me, limit: 3) {
                let sc: Double
                if child.current == me {
                    sc = (try negamax(child, depth: depth, alpha: alpha, beta: beta, ply: ply + 1, ctx: ctx)) - 0.1
                } else {
                    sc = -(try negamax(child, depth: depth - 1, alpha: -beta, beta: -alpha, ply: ply + 1, ctx: ctx)) - 0.1
                }
                if sc > best { best = sc }
                if best > alpha { alpha = best }
                if alpha >= beta { break }
            }
        }
        if let tt = ctx.tt, slot >= 0 {
            tt.keys[slot] = key
            tt.depths[slot] = Int8(clamping: depth)
            tt.values[slot] = best
            tt.moves[slot] = Int16(clamping: bestMove)
            tt.flags[slot] = best <= alpha0 ? 2 : (best >= beta ? 1 : 0)
        }
        return best
    }

    /// v3-Sortierung: Zug aus der Tabelle, Schlagzüge (MVV-LVA), zwei Killerzüge, dann Verlaufs-Heuristik.
    private static func orderedV3(_ moves: [Move], in s: GameState, ply: Int, ctx: SearchContext, ttMove: Int) -> [Move] {
        let k1 = ctx.killers[ply], k2 = ctx.killers2[ply]
        return moves.map { m -> (Move, Double) in
            let code = m.from.index * 64 + m.to.index
            let sc: Double
            if code == ttMove {
                sc = 5_000
            } else if let v = s[m.to] {
                sc = 1_000 + v.type.value * 10 - (s[m.from]?.type.value ?? 0)
            } else if m.isEnPassant {
                sc = 1_001
            } else if let k = k1, k == m {
                sc = 900
            } else if let k = k2, k == m {
                sc = 890
            } else {
                sc = Double(min(800, ctx.history[code]))
            }
            return (m, sc)
        }
        .sorted { $0.1 > $1.1 }
        .map { $0.0 }
    }

    /// Schlüssel einer Stellung für die Transpositionstabelle (Zobrist): Figuren inklusive Frost/Schild
    /// und Rochaderechten, Seite am Zug, Bonuszug und En-passant-Feld.
    static func searchHash(_ s: GameState) -> UInt64 {
        var h: UInt64 = 0
        let z = Zobrist.table
        for sq in GameState.allSquares {
            guard let p = s[sq] else { continue }
            var k: Int
            switch p.type {
            case .pawn: k = 0
            case .knight: k = 1
            case .bishop: k = 2
            case .rook: k = 3
            case .queen: k = 4
            case .king: k = 5
            }
            if p.color == .black { k += 6 }
            if p.isFrozen(at: s.ply) { k = p.color == .white ? 12 : 14 }
            else if p.isShielded(at: s.ply) { k = p.color == .white ? 13 : 15 }
            let j = k * 64 + sq.index
            h ^= z[j]
            if (p.type == .king || p.type == .rook) && !p.hasMoved { h ^= z[j] &* 31 &+ 7 }
        }
        if s.ply & 1 == 1 { h ^= z[Zobrist.side] }
        if s.bonusActionUsed { h ^= z[Zobrist.bonus] }
        if let ep = s.enPassantTarget { h ^= z[Zobrist.ep] &+ UInt64(ep.index) }
        return h
    }

    /// Kartenzüge für die Suche: pro Karte höchstens `limit` Ziele, die wertvollsten Figuren zuerst.
    private static func cardChildren(_ s: GameState, _ me: PlayerColor, limit: Int) -> [GameState] {
        var out: [GameState] = []
        func best(_ squares: [Square]) -> [Square] {
            guard squares.count > limit else { return squares }
            return Array(squares.sorted { (s[$0]?.type.value ?? 0) > (s[$1]?.type.value ?? 0) }.prefix(limit))
        }
        if let hand = s.decks[me]?.hand {
            for (i, card) in hand.enumerated() where s.canPlay(card, player: me) {
                let targets: [Square?] = card.targeting == .none ? [nil] : best(s.targets(for: card, player: me)).map { Optional($0) }
                for t in targets {
                    var c = s
                    c.playCard(card, handIndex: i, target: t)
                    out.append(c)
                }
            }
        }
        if s.canUseUltimate(me) {
            let list = best(s.ultimateTargets(me))
            let targets: [Square?] = list.isEmpty ? [nil] : list.map { Optional($0) }
            for t in targets {
                var c = s
                c.useUltimate(target: t)
                out.append(c)
            }
        }
        return out
    }

    /// Ruhesuche: nur Schlagzüge, damit der Bot am Suchhorizont keine Figuren einstellt.
    private static func quiesce(_ s: GameState, alpha: Double, beta: Double, depth: Int, ctx: SearchContext) throws -> Double {
        try ctx.tick()
        if let t = leafTerminal(s) { return t }
        let me = s.current
        let stand = evaluate(s, me, ctx)
        if depth <= 0 || stand >= beta { return stand }
        var alpha = max(alpha, stand)
        let captures = pseudoAll(s, me).filter { s[$0.to] != nil || $0.isEnPassant }
        for m in ordered(captures, in: s) {
            var child = s
            child.makeMove(m)
            if child.isInCheck(me) { continue }
            let sc = -(try quiesce(child, alpha: -beta, beta: -alpha, depth: depth - 1, ctx: ctx))
            if sc >= beta { return sc }
            if sc > alpha { alpha = sc }
        }
        return alpha
    }

    /// Patt oder Matt an einem Blatt erkennen – nur geprüft, wenn der Seite am Zug kaum Figuren bleiben.
    private static func leafTerminal(_ s: GameState) -> Double? {
        let me = s.current
        for sq in GameState.allSquares {
            if let p = s[sq], p.color == me, p.type != .king, p.type != .pawn { return nil }
        }
        if s.hasAnyLegalMove(for: me) { return nil }
        return s.isInCheck(me) ? -10_000 : 0
    }

    private static func evaluate(_ s: GameState, _ color: PlayerColor, _ ctx: SearchContext) -> Double {
        if ctx.useV3Eval { return s.evaluateV3(for: color) }
        return ctx.useV2 ? s.evaluateV2(for: color) : s.evaluate(for: color)
    }

    private static func pseudoAll(_ s: GameState, _ color: PlayerColor) -> [Move] {
        var out: [Move] = []
        for sq in GameState.allSquares where s[sq]?.color == color {
            out += s.pseudoMoves(from: sq)
        }
        return out
    }

    /// Schlagzüge zuerst (wertvolles Opfer, billiger Angreifer), dann Umwandlungen.
    static func ordered(_ moves: [Move], in s: GameState) -> [Move] {
        moves.map { ($0, moveOrderScore($0, s)) }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }

    private static func moveOrderScore(_ m: Move, _ s: GameState) -> Double {
        guard let victim = s[m.to] else {
            if m.isEnPassant { return 1 }
            if let p = s[m.from], p.type == .pawn, m.to.row == p.color.promotionRow { return 8 }
            return 0
        }
        let attacker = s[m.from]?.type.value ?? 0
        return victim.type.value * 10 - attacker
    }
}

// MARK: - Transpositionstabelle

/// Feste Zufallswerte für den Stellungsschlüssel (deterministisch erzeugt).
private enum Zobrist {
    static let side = 16 * 64
    static let bonus = 16 * 64 + 1
    static let ep = 16 * 64 + 2
    static let table: [UInt64] = {
        var x: UInt64 = 0x9E37_79B9_7F4A_7C15
        return (0..<(16 * 64 + 3)).map { _ in
            x ^= x << 13
            x ^= x >> 7
            x ^= x << 17
            return x
        }
    }()
}

/// Speicher für bereits durchsuchte Stellungen: Tiefe, Wert, Art der Schranke und bester Zug.
private final class TranspositionTable {
    static let bits = 18
    static let size = 1 << bits
    static let mask = size - 1
    var keys = [UInt64](repeating: 0, count: size)
    var depths = [Int8](repeating: -1, count: size)
    var values = [Double](repeating: 0, count: size)
    /// 0 exakt, 1 untere Schranke, 2 obere Schranke
    var flags = [UInt8](repeating: 0, count: size)
    var moves = [Int16](repeating: -1, count: size)
}

// MARK: - Bewertung

extension GameState {
    /// Stellungsbewertung aus Sicht von `color` (positiv = gut für `color`).
    func evaluate(for color: PlayerColor) -> Double {
        var score = 0.0
        for sq in GameState.allSquares {
            guard let p = self[sq] else { continue }
            var v = p.type.value
            let centerDist = abs(3.5 - Double(sq.row)) + abs(3.5 - Double(sq.col))
            switch p.type {
            case .knight, .bishop:
                v += (7 - centerDist) * 0.04
            case .pawn:
                v += Double(p.color.rank(of: sq) - 2) * 0.06
            case .queen:
                v += (7 - centerDist) * 0.01
            case .king:
                v += p.hasMoved && abs(sq.col - 4) <= 1 ? -0.2 : 0
            case .rook:
                break
            }
            if p.isFrozen(at: ply) { v -= 0.2 }
            score += p.color == color ? v : -v
        }
        // Mana ist Ultimate-Fortschritt. (Das Gebiet bringt seit v0.9.20 kein Mana mehr – die teure Gebietskarte
        // wird in der Suche nicht mehr berechnet, das macht die Bots spürbar schneller.)
        score += Double(mana[color, default: 0] - mana[color.opponent, default: 0]) * 0.12
        return score
    }

    /// Erweiterte Bewertung für die oberen Stufen.
    func evaluateV2(for color: PlayerColor) -> Double {
        var score = evaluate(for: color)
        score += kingSafety(color) - kingSafety(color.opponent)

        // Entwicklung: Leichtfiguren auf der Grundreihe kosten in der Eröffnung.
        if ply < 24 {
            for c in PlayerColor.allCases {
                var undeveloped = 0
                for sq in GameState.allSquares where sq.row == c.homeRow {
                    if let p = self[sq], p.color == c, p.type == .knight || p.type == .bishop { undeveloped += 1 }
                }
                score += (c == color ? -1 : 1) * Double(undeveloped) * 0.08
            }
        }

        // Endspiel-Technik: bei klarem Vorteil den gegnerischen König an den Rand drängen.
        let mat = materialValue(for: color)
        if abs(mat) >= 4 {
            let winner = mat > 0 ? color : color.opponent
            let loser = winner.opponent
            let loserPieces = pieces(of: loser).filter { $0.1.type != .king && $0.1.type != .pawn }.count
            if loserPieces <= 1, let lk = kingSquare(loser), let wk = kingSquare(winner) {
                let edge = abs(3.5 - Double(lk.row)) + abs(3.5 - Double(lk.col))
                let dist = Double(abs(lk.row - wk.row) + abs(lk.col - wk.col))
                let bonus = edge * 0.12 + (14 - dist) * 0.06
                score += winner == color ? bonus : -bonus
            }
        }

        // Volle Ultimate-Leiste ist eine Drohung (Meteor kostet etwa eine Leichtfigur).
        let o = color.opponent
        if let u = ultimates[o], mana[o, default: 0] >= u.cost { score -= u == .meteor ? 1.6 : 0.8 }
        if let u = ultimates[color], mana[color, default: 0] >= u.cost { score += u == .meteor ? 1.2 : 0.6 }
        return score
    }

    /// v3: zusätzlich Bauernstruktur, Freibauern, Läuferpaar und Türme auf offenen Linien / der 7. Reihe.
    func evaluateV3(for color: PlayerColor) -> Double {
        evaluateV2(for: color) + structure(color) - structure(color.opponent)
    }

    private static let passedBonus: [Double] = [0, 0, 0.1, 0.18, 0.3, 0.5, 0.8, 0]

    private func structure(_ color: PlayerColor) -> Double {
        var own = [Int](repeating: 0, count: 8), enemy = [Int](repeating: 0, count: 8)
        for sq in GameState.allSquares {
            if let p = self[sq], p.type == .pawn {
                if p.color == color { own[sq.col] += 1 } else { enemy[sq.col] += 1 }
            }
        }
        var score = 0.0
        var bishops = 0
        for sq in GameState.allSquares {
            guard let p = self[sq], p.color == color else { continue }
            switch p.type {
            case .bishop:
                bishops += 1
            case .rook:
                if own[sq.col] == 0 { score += enemy[sq.col] > 0 ? 0.1 : 0.2 }
                if color.rank(of: sq) == 7 { score += 0.2 }
            case .pawn:
                // Freibauer: kein gegnerischer Bauer davor auf derselben oder einer Nachbarlinie
                var passed = true
                var r = sq.row + color.forward
                outer: while r >= 0 && r < 8 {
                    for dc in -1...1 {
                        let c = sq.col + dc
                        guard c >= 0 && c < 8 else { continue }
                        if let q = self[Square(row: r, col: c)], q.type == .pawn, q.color != color {
                            passed = false
                            break outer
                        }
                    }
                    r += color.forward
                }
                if passed { score += GameState.passedBonus[color.rank(of: sq) - 1] }
                let left = sq.col > 0 && own[sq.col - 1] > 0
                let right = sq.col < 7 && own[sq.col + 1] > 0
                if !left && !right { score -= 0.12 }   // isoliert
            default:
                break
            }
        }
        for c in 0..<8 where own[c] > 1 { score -= 0.15 * Double(own[c] - 1) }   // Doppelbauern
        if bishops >= 2 { score += 0.3 }
        return score
    }

    /// Materialbilanz mit den Bewertungswerten (Läufer 3,2).
    func materialValue(for color: PlayerColor) -> Double {
        var sum = 0.0
        for sq in GameState.allSquares {
            if let p = self[sq] { sum += p.color == color ? p.type.value : -p.type.value }
        }
        return sum
    }

    /// Bauernschild, Rochade und gegnerische Figuren in Königsnähe.
    private func kingSafety(_ color: PlayerColor) -> Double {
        guard let k = kingSquare(color) else { return 0 }
        let f = color.forward
        var shield = 0.0
        for dc in -1...1 {
            for dr in [f, 2 * f] {
                let sq = k.offset(dr, dc)
                if sq.isValid, let p = self[sq], p.type == .pawn, p.color == color {
                    shield += dr == f ? 0.12 : 0.06
                    break
                }
            }
        }
        var danger = 0.0
        for sq in GameState.allSquares {
            guard let p = self[sq], p.color != color, p.type != .pawn, p.type != .king else { continue }
            if max(abs(sq.row - k.row), abs(sq.col - k.col)) <= 2 { danger += p.type == .queen ? 0.25 : 0.1 }
        }
        let castled = (k.col >= 6 || k.col <= 2) && k.row == color.homeRow ? 0.25 : 0
        return shield + castled - danger
    }
}

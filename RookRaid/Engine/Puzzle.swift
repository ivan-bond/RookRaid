import Foundation

enum PuzzleGoal: Equatable {
    case mate(Int)
    case material
    /// Rook Raid: mit einer Aktion mindestens so viele Felder besetzen.
    case territory(Int)

    var title: String {
        switch self {
        case .mate(let n): return L("Matt in {0}", n)
        case .material: return L("Gewinne Material")
        case .territory(let n): return L("Erreiche {0} Felder", n)
        }
    }

    var shortTitle: String {
        switch self {
        case .mate(let n): return L("Matt in {0}", n)
        case .material: return L("Material")
        case .territory(let n): return L("{0} Felder", n)
        }
    }

    var icon: String {
        switch self {
        case .mate: return "crown.fill"
        case .material: return "scalemass.fill"
        case .territory: return "square.grid.3x3.fill"
        }
    }
}

/// Ein Puzzle. Alle Lösungen wurden vorab mit einem Solver geprüft.
///
/// `lines` enthält Aktionsfolgen, abwechselnd Spieler und Antwort des Gegners:
/// - Schachzug in UCI („e2e4“), Karte als „card:freeze@f6“ bzw. „card:bulwark“,
///   Ultimate als „ult:meteor@g7“ bzw. „ult:iceAge“.
/// - Matt-Puzzles: Jede Linie endet mit einer Antwort; jedes Matt zählt als Schlusszug.
/// - Material-Puzzles: Die Linie endet mit dem letzten Spielerzug.
/// - Gebiets-Puzzles: Jede Aktion zählt, die das Ziel erreicht; die Linie enthält nur den Hinweis.
struct Puzzle: Identifiable, Equatable {
    let id: String
    let title: String
    let goal: PuzzleGoal
    let difficulty: Int
    let fen: String
    let lines: [[String]]
    /// Rook-Raid-Format: Karten auf der Hand, verfügbares Mana und Ultimate.
    var hand: [CardType] = []
    var mana: Int = 0
    var ultimate: Ultimate? = nil

    var isRookRaid: Bool {
        if case .territory = goal { return true }
        return !hand.isEmpty || ultimate != nil
    }

    var isTerritory: Bool {
        if case .territory = goal { return true }
        return false
    }

    /// Sinnbild für die Kachel: Ultimate, Karte oder Ziel.
    var tileIcon: String {
        if let u = ultimate { return u.icon }
        if let first = lines.first?.first, first.hasPrefix("card:") {
            let name = String(first.dropFirst(5).split(separator: "@").first ?? "")
            if let card = CardType(rawValue: name) { return card.icon }
        }
        return goal.icon
    }

    var xp: Int {
        switch difficulty {
        case 1: return 10
        case 2: return 20
        default: return 35
        }
    }

    var difficultyName: String {
        switch difficulty {
        case 1: return L("Leicht")
        case 2: return L("Mittel")
        default: return L("Schwer")
        }
    }

    var sideToMove: PlayerColor { fen.split(separator: " ").dropFirst().first == "b" ? .black : .white }
}

/// Eine Spieleraktion im Puzzle: Schachzug, Karte oder Ultimate.
enum PuzzleAction: Equatable {
    case move(Move)
    case card(CardType, Square?)
    case ultimate(Square?)

    func code(in state: GameState) -> String {
        switch self {
        case .move(let m):
            return m.uci(in: state)
        case .card(let c, let t):
            return "card:\(c.rawValue)" + (t.map { "@" + $0.name } ?? "")
        case .ultimate(let t):
            let name = state.ultimates[state.current]?.rawValue ?? ""
            return "ult:\(name)" + (t.map { "@" + $0.name } ?? "")
        }
    }

    /// Liest eine gespeicherte Aktion.
    static func parse(_ text: String, in state: GameState) -> PuzzleAction? {
        if text.hasPrefix("card:") || text.hasPrefix("ult:") {
            let body = text.split(separator: ":", maxSplits: 1).last.map(String.init) ?? ""
            let parts = body.split(separator: "@").map(String.init)
            let target = parts.count > 1 ? Square(name: parts[1]) : nil
            if text.hasPrefix("ult:") { return .ultimate(target) }
            guard let card = CardType(rawValue: parts.first ?? "") else { return nil }
            return .card(card, target)
        }
        return state.move(fromUCI: text).map { .move($0) }
    }
}

/// Ablauf eines Puzzles: prüft Spieleraktionen gegen die Lösungslinien und liefert die Antwort.
struct PuzzleRun {
    let puzzle: Puzzle
    private(set) var state: GameState
    private(set) var played: [String] = []
    /// Bisher ausgeführte Antworten des Gegners (= abgeschlossene Spielerzüge).
    private(set) var repliesPlayed = 0

    enum Outcome: Equatable {
        case wrong
        case continueWith(reply: Move)
        /// Bonuskarte (Schild/Frost) gespielt – der Spieler bleibt am Zug.
        case continueSameTurn
        case solved
    }

    init?(puzzle: Puzzle) {
        guard var s = GameState.fromFEN(puzzle.fen) else { return nil }
        let player = puzzle.sideToMove
        if !puzzle.hand.isEmpty {
            s.decks[player] = PlayerDeck(hand: puzzle.hand, queue: [])
        }
        if let u = puzzle.ultimate { s.ultimates[player] = u }
        s.mana[player] = puzzle.mana
        self.puzzle = puzzle
        self.state = s
    }

    var player: PlayerColor { puzzle.sideToMove }

    private var matchingLines: [[String]] {
        puzzle.lines.filter { line in
            line.count >= played.count && Array(line.prefix(played.count)) == played
        }
    }

    /// Nächste Lösungsaktion (für Hinweis und Vorspielen).
    var hintAction: PuzzleAction? {
        let idx = played.count
        guard let line = matchingLines.first(where: { $0.count > idx }) else { return nil }
        return PuzzleAction.parse(line[idx], in: state)
    }

    /// Zustand nach einer Aktion (ohne sie zu übernehmen).
    func preview(_ action: PuzzleAction) -> GameState {
        var after = state
        switch action {
        case .move(let m):
            after.makeMove(m)
        case .card(let c, let t):
            let idx = after.decks[player]?.hand.firstIndex(of: c) ?? 0
            after.playCard(c, handIndex: idx, target: t)
        case .ultimate(let t):
            after.useUltimate(target: t)
        }
        after.events = []
        return after
    }

    /// Prüft eine Spieleraktion. Bei Erfolg wird sie ausgeführt; eine Antwort muss mit `applyReply` folgen.
    mutating func attempt(_ action: PuzzleAction) -> Outcome {
        let text = action.code(in: state)
        let idx = played.count
        let after = preview(action)

        switch puzzle.goal {
        case .mate:
            if case .checkmate = after.status() {
                state = after
                played.append(text)
                return .solved
            }
        case .territory(let n):
            // Jede Aktion zählt, die das Ziel erreicht.
            if after.territory(player) >= n {
                state = after
                played.append(text)
                return .solved
            }
            return .wrong
        case .material:
            break
        }

        let candidates = matchingLines.filter { $0.count > idx }
        var line = candidates.first { $0[idx] == text }
        // Material-Puzzles: Der Schlusszug darf jede Figur sein, die dasselbe Ziel schlägt.
        if line == nil, case .material = puzzle.goal, case .move(let move) = action, state[move.to] != nil {
            line = candidates.first { $0.count == idx + 1 && String($0[idx].dropFirst(2).prefix(2)) == move.to.name }
        }
        guard let line else {
            // Sicherheitsnetz für Matt in 2: Ein nicht hinterlegter Zug zählt trotzdem,
            // wenn nach jeder Antwort ein Matt im nächsten Zug folgt.
            if case .mate(let n) = puzzle.goal, n - repliesPlayed == 2, after.current != player,
               let reply = PuzzleRun.toughestReplyBeforeMate(after) {
                state = after
                played.append(text)
                return .continueWith(reply: reply)
            }
            return .wrong
        }

        state = after
        played.append(text)
        if state.current == player && state.bonusActionUsed {
            return .continueSameTurn
        }
        if line.count > played.count, let reply = state.move(fromUCI: line[played.count]) {
            return .continueWith(reply: reply)
        }
        if case .material = puzzle.goal { return .solved }
        return .wrong
    }

    mutating func applyReply(_ move: Move) {
        played.append(move.uci(in: state))
        state.makeMove(move)
        state.events = []
        repliesPlayed += 1
    }

    /// Gegner am Zug: Hat der Spieler nach jeder Antwort ein Matt in 1? Dann die zäheste Antwort
    /// (die mit den wenigsten Mattzügen), sonst nil.
    static func toughestReplyBeforeMate(_ s: GameState) -> Move? {
        let replies = s.allLegalMoves(for: s.current)
        guard !replies.isEmpty else { return nil }
        var best: Move? = nil
        var fewest = Int.max
        for r in replies {
            var c = s
            c.makeMove(r)
            var mates = 0
            for m in c.allLegalMoves(for: c.current) {
                var d = c
                d.makeMove(m)
                if case .checkmate = d.status() {
                    mates += 1
                    if mates >= fewest { break }
                }
            }
            if mates == 0 { return nil }
            if mates < fewest {
                fewest = mates
                best = r
            }
        }
        return best
    }
}

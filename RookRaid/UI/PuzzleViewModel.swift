import SwiftUI

/// Steuert ein einzelnes Puzzle: Eingabe (Züge, Karten, Ultimate), Prüfung, Gegnerantwort,
/// Hinweis, Lösung und Belohnung.
@MainActor
final class PuzzleViewModel: ObservableObject {
    enum Phase: Equatable {
        case playing
        case opponentMoving
        case solved
        case revealed
    }

    let puzzle: Puzzle
    let isDaily: Bool
    /// Puzzle-Rausch: kein Verbuchen einzelner Puzzles, der Rausch zählt selbst.
    let isRush: Bool
    private var run: PuzzleRun
    private let store = ProfileStore.shared

    @Published private(set) var state: GameState
    @Published private(set) var phase: Phase = .playing
    @Published private(set) var selected: Square?
    @Published private(set) var targets: [Move] = []
    @Published private(set) var lastMove: Move?
    @Published private(set) var hintSquare: Square?
    @Published private(set) var hintCard: CardType?
    @Published private(set) var hintUltimate = false
    @Published private(set) var wrongSquare: Square?
    @Published private(set) var message: String
    @Published private(set) var mistakes = 0
    @Published private(set) var hintUsed = false
    @Published private(set) var reward: ProfileStore.PuzzleReward?
    @Published private(set) var shake = 0
    /// Ausgewählte Karte bzw. Ultimate, die noch ein Ziel braucht.
    @Published private(set) var pendingCard: CardType?
    @Published private(set) var pendingUltimate = false
    @Published private(set) var cardTargets: Set<Square> = []

    init?(puzzle: Puzzle, isDaily: Bool = false, rush: Bool = false) {
        guard let run = PuzzleRun(puzzle: puzzle) else { return nil }
        self.puzzle = puzzle
        self.isDaily = isDaily
        self.isRush = rush
        self.run = run
        self.state = run.state
        self.message = PuzzleViewModel.instruction(for: puzzle)
    }

    static func prompt(for puzzle: Puzzle) -> String {
        L("{0} am Zug · {1}", puzzle.sideToMove.displayName, puzzle.goal.title)
    }

    static func instruction(for puzzle: Puzzle) -> String {
        switch puzzle.goal {
        case .territory(let n):
            // Seit v0.9.20 nicht mehr im Katalog (Gebiet bringt kein Mana mehr); bleibt für alte Daten lesbar.
            return L("Erreiche {0} Felder", n)
        case .mate:
            if puzzle.ultimate != nil { return L("Deine Ultimate ist geladen. Nutze sie – oder deine Karten.") }
            if case .mate(1) = puzzle.goal, puzzle.hand.contains(where: { $0.keepsTurn }) {
                return L("Ein Zug allein reicht nicht – aber nach Schild oder Frost darfst du noch ziehen.")
            }
            if !puzzle.hand.isEmpty { return L("Ein Zug allein reicht nicht. Welche Karte bereitet das Matt vor?") }
            return prompt(for: puzzle)
        case .material:
            return prompt(for: puzzle)
        }
    }

    var player: PlayerColor { run.player }
    var flipped: Bool { player == .black }
    var canInteract: Bool { phase == .playing }
    var clean: Bool { mistakes == 0 && !hintUsed }
    var mana: Int { state.mana[player, default: 0] }
    var hand: [CardType] { state.decks[player]?.hand ?? [] }
    var ultimate: Ultimate? { state.ultimates[player] }
    var hasCards: Bool { puzzle.isRookRaid && (!puzzle.hand.isEmpty || puzzle.ultimate != nil) }

    var showsTerritory: Bool {
        if case .territory = puzzle.goal { return true }
        return false
    }

    var territoryGoal: Int? {
        if case .territory(let n) = puzzle.goal { return n }
        return nil
    }

    var control: [PlayerColor?] { state.controlMap() }
    var myTerritory: Int { state.territory(player) }

    func canAfford(_ card: CardType) -> Bool { mana >= card.cost }

    func isCardPlayable(_ card: CardType) -> Bool {
        canInteract && state.current == player && state.canPlay(card, player: player)
    }

    var ultimateUsable: Bool { canInteract && state.current == player && state.canUseUltimate(player) }

    // MARK: Eingabe

    func tap(_ sq: Square) {
        guard canInteract else { return }
        if pendingCard != nil || pendingUltimate {
            if cardTargets.contains(sq) {
                if let card = pendingCard {
                    submit(.card(card, sq))
                } else {
                    submit(.ultimate(sq))
                }
            } else {
                cancelPending()
            }
            return
        }
        if selected != nil, let move = targets.first(where: { $0.to == sq }) {
            submit(.move(move))
            return
        }
        if let p = state[sq], p.color == player {
            selected = sq
            targets = state.legalMoves(from: sq)
            Haptics.shared.play(.select)
            if state.isBonusLocked(sq) {
                message = L("Die geschützte Figur bleibt in diesem Zug stehen – zieh eine andere.")
                Haptics.shared.play(.invalid)
            }
        } else {
            selected = nil
            targets = []
        }
    }

    func canDrag(from sq: Square) -> Bool {
        canInteract && pendingCard == nil && !pendingUltimate && state[sq]?.color == player
    }

    func beginDrag(at sq: Square) {
        selected = sq
        targets = state.legalMoves(from: sq)
    }

    func drop(from: Square, to: Square) {
        guard canInteract else { return }
        if let move = state.legalMoves(from: from).first(where: { $0.to == to }) {
            submit(.move(move))
        } else {
            selected = nil
            targets = []
        }
    }

    func tapCard(_ card: CardType) {
        guard canInteract else { return }
        if pendingCard == card { cancelPending(); return }
        selected = nil
        targets = []
        guard canAfford(card) else {
            message = L("Zu wenig Mana für {0} ({1}).", card.name, card.cost)
            Haptics.shared.play(.invalid)
            return
        }
        guard state.canPlay(card, player: player) else {
            message = L("{0} hat hier kein gültiges Ziel.", card.name)
            Haptics.shared.play(.invalid)
            return
        }
        if card.targeting == .none {
            submit(.card(card, nil))
            return
        }
        pendingUltimate = false
        pendingCard = card
        cardTargets = Set(state.targets(for: card, player: player))
        message = "\(card.name): \(card.targetPrompt)"
        Haptics.shared.play(.select)
    }

    func tapUltimate() {
        guard canInteract, let u = ultimate else { return }
        if pendingUltimate { cancelPending(); return }
        selected = nil
        targets = []
        guard mana >= u.cost else {
            message = L("Die Ultimate braucht {0} Mana.", u.cost)
            Haptics.shared.play(.invalid)
            return
        }
        guard state.canUseUltimate(player) else {
            message = L("{0} ist hier nicht möglich.", u.name)
            Haptics.shared.play(.invalid)
            return
        }
        if u.needsTarget {
            pendingCard = nil
            pendingUltimate = true
            cardTargets = Set(state.ultimateTargets(player))
            message = u.targetPrompt
            Haptics.shared.play(.select)
        } else {
            submit(.ultimate(nil))
        }
    }

    func cancelPending() {
        pendingCard = nil
        pendingUltimate = false
        cardTargets = []
        message = PuzzleViewModel.instruction(for: puzzle)
    }

    // MARK: Prüfung

    private func submit(_ action: PuzzleAction) {
        selected = nil
        targets = []
        hintSquare = nil
        hintCard = nil
        hintUltimate = false
        pendingCard = nil
        pendingUltimate = false
        cardTargets = []
        let before = run.state
        switch run.attempt(action) {
        case .wrong:
            wrong(action, before: before)
        case .solved:
            show(run.state, action: action, before: before)
            solved()
        case .continueSameTurn:
            show(run.state, action: action, before: before)
            message = L("Richtig! Jetzt noch dein Figurzug.")
        case .continueWith(let reply):
            show(run.state, action: action, before: before)
            message = L("Richtig! Weiter so …")
            phase = .opponentMoving
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 750_000_000)
                self?.playReply(reply)
            }
        }
    }

    private func playReply(_ reply: Move) {
        let before = run.state
        run.applyReply(reply)
        show(run.state, action: .move(reply), before: before)
        phase = .playing
        message = L("Du bist dran – finde den nächsten Zug.")
    }

    private func show(_ s: GameState, action: PuzzleAction, before: GameState) {
        withAnimation(.easeOut(duration: 0.2)) {
            state = s
            if case .move(let m) = action { lastMove = m }
        }
        switch action {
        case .move(let m):
            let capture = before[m.to] != nil || m.isEnPassant
            if case .check = s.status() {
                Feedback.play(.check, .check)
            } else {
                Feedback.play(capture ? .capture : .move, capture ? .capture : .move)
            }
        case .card(let c, _):
            message = L("{0} gespielt.", c.name)
            switch c {
            case .freeze: Feedback.play(.frost, .frost)
            case .lightning: Feedback.play(.lightning, .lightning)
            case .shield, .bulwark: Feedback.play(.shield, .shield)
            default: Feedback.play(.card, .cardCast)
            }
        case .ultimate:
            message = L("{0} eingesetzt!", before.ultimates[player]?.name ?? L("Ultimate"))
            Feedback.play(.lightning, .heavyCapture)
        }
    }

    private func wrong(_ action: PuzzleAction, before: GameState) {
        mistakes += 1
        Feedback.play(.trap, .invalid)
        if isRush {
            // Im Rausch kostet ein Fehler ein Leben – das nächste Puzzle kommt sofort
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            phase = .revealed
            return
        }
        let preview = run.preview(action)
        withAnimation(.easeOut(duration: 0.15)) {
            state = preview
            if case .move(let m) = action { wrongSquare = m.to }
        }
        withAnimation(.linear(duration: 0.35)) { shake += 1 }
        if case .territory(let n) = puzzle.goal {
            message = L("Damit hast du {0} Felder – es müssen {1} sein.", preview.territory(player), n)
        } else if case .move = action {
            message = mistakes >= 2 ? L("Noch nicht. Tipp: Nutze den Hinweis.") : L("Das ist es nicht – versuch es noch einmal.")
        } else {
            message = L("Diese Aktion führt nicht zum Ziel. Versuch es noch einmal.")
        }
        phase = .opponentMoving
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.state = self.run.state
                self.wrongSquare = nil
            }
            self.phase = .playing
        }
    }

    private func solved() {
        phase = .solved
        if isRush {
            Feedback.play(.victory, .chestReveal)
            return
        }
        let r = store.solvePuzzle(puzzle, clean: clean, isDaily: isDaily)
        reward = r
        if case .territory = puzzle.goal {
            message = L("Geschafft: {0} Felder!", myTerritory)
        } else {
            message = L("Gelöst!")
        }
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            Feedback.play(.victory, .victory)
        }
    }

    // MARK: Hilfen

    func showHint() {
        guard canInteract, let a = run.hintAction ?? mateMove().map({ PuzzleAction.move($0) }) else { return }
        hintUsed = true
        switch a {
        case .move(let m):
            hintSquare = m.from
            message = L("Hinweis: Diese Figur ist der Schlüssel.")
        case .card(let c, let t):
            hintCard = c
            hintSquare = t
            message = L("Hinweis: Spiele {0}", c.name) + (t != nil ? L(" auf das markierte Feld.") : ".")
        case .ultimate(let t):
            hintUltimate = true
            hintSquare = t
            message = L("Hinweis: Jetzt ist der Moment für deine Ultimate.")
        }
        Haptics.shared.play(.tick)
    }

    /// Spielt die Lösung vor. Danach gibt es keine XP.
    func revealSolution() {
        guard canInteract else { return }
        cancelPending()
        phase = .revealed
        store.breakPuzzleStreak()
        message = L("So geht's:")
        Task { [weak self] in
            guard let self else { return }
            while true {
                guard let a = self.run.hintAction ?? self.mateMove().map({ PuzzleAction.move($0) }) else { break }
                let before = self.run.state
                let outcome = self.run.attempt(a)
                self.show(self.run.state, action: a, before: before)
                if outcome == .continueSameTurn {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    continue
                }
                if case .continueWith(let reply) = outcome {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    let b2 = self.run.state
                    self.run.applyReply(reply)
                    self.show(self.run.state, action: .move(reply), before: b2)
                    try? await Task.sleep(nanoseconds: 900_000_000)
                } else {
                    break
                }
            }
            self.message = L("Lösung gezeigt – probier das nächste Puzzle.")
        }
    }

    /// Bei Matt-Puzzles ist der Schlusszug nicht gespeichert: den ersten mattsetzenden Zug suchen.
    private func mateMove() -> Move? {
        guard case .mate = puzzle.goal else { return nil }
        for (sq, _) in run.state.pieces(of: player) {
            for m in run.state.legalMoves(from: sq) {
                var s = run.state
                s.makeMove(m)
                if case .checkmate = s.status() { return m }
            }
        }
        return nil
    }

    func isLastMoveSquare(_ sq: Square) -> Bool {
        guard let m = lastMove else { return false }
        return m.from == sq || m.to == sq
    }
}

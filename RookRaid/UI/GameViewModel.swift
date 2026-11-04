import SwiftUI

/// Ausgewählte Aktion, die noch ein Ziel braucht. `card == nil` bedeutet: Ultimate.
struct PendingCard: Equatable {
    var card: CardType?
    var handIndex: Int
}

enum EffectKind: Equatable {
    case capture
    case bigCapture
    case frost
    case shield
    case lightning
    case sparkle
    case smoke
    case revive
    case promotion
    case meteor
    case iceWave
}

struct BoardEffect: Identifiable, Equatable {
    let id = UUID()
    let kind: EffectKind
    let square: Square
    var duration: Double = 0.9
    let seed: UInt64 = UInt64.random(in: 1...UInt64.max)
}

struct CastBanner: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let isUltimate: Bool
    let caster: PlayerColor
    /// Kartenbild (Asset-Name), falls vorhanden
    var art: String? = nil
}

struct Announcement: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}

/// Schwebende Mana-Gutschrift an der Leiste („+2 Gabel“).
struct ManaFloat: Identifiable, Equatable {
    let id = UUID()
    let color: PlayerColor
    let amount: Int
    let label: String
}

struct Finisher: Equatable {
    let square: Square
    let winner: PlayerColor
}

struct GameOverInfo: Equatable {
    let title: String
    let subtitle: String
    let result: GameResultKind?
    var trophyDelta: Int
    let rated: Bool
    /// Neue Serienlänge, falls diese Partie heute die Flamme entzündet hat.
    var streakLit: Int? = nil
    /// Bot-Leiter: gewonnene XP und neu freigeschalteter Gegner
    var ladderXP: Int? = nil
    var ladderUnlocked: String? = nil
    /// Mit diesem Sieg neu freigeschaltetes Figurenset (das des besiegten Bots).
    var skinUnlocked: BotLevel? = nil
    /// In dieser Partie verdiente Truhen (Sieg, Leiter, Arena, Level).
    var chests: [Chest] = []
    /// Kampf-Sieg ohne Truhe, weil die drei Siegtruhen des Tages schon vergeben sind.
    var winChestsUsedUp = false
    /// Neu erreichte Belohnung auf dem Trophäenpfad.
    var roadReady: RoadStep? = nil
    /// Zu zweit: Es gibt einen Sieger (Konfetti) – früher am Titeltext erkannt, jetzt sprachunabhängig.
    var hasWinner = false
    /// Für das Siegfenster: besiegter (oder siegreicher) Bot und kleine Statistik
    var opponent: BotLevel? = nil
    /// Bot-Ersatz: Spielerkarte statt Bot-Porträt (der Ersatz bleibt unerkennbar)
    var disguise: PlayerCard? = nil
    var moveCount = 0
    var cardsPlayed = 0
    var winnerColor: PlayerColor? = nil
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published private(set) var status: GameStatus = .ongoing
    @Published private(set) var selected: Square?
    @Published private(set) var legalMoves: [Move] = []
    @Published private(set) var pending: PendingCard?
    @Published private(set) var cardTargets: Set<Square> = []
    @Published private(set) var playable: Set<Int> = []
    @Published private(set) var ultimateUsable = false
    @Published private(set) var moves: [MoveEntry] = []
    @Published private(set) var effects: [BoardEffect] = []
    @Published private(set) var banner: CastBanner?
    @Published private(set) var announcement: Announcement?
    @Published private(set) var manaFloats: [ManaFloat] = []
    @Published private(set) var finisher: Finisher?
    @Published private(set) var shake = 0
    /// Schachuhr als eigenes Objekt (v0.9.25): tickt 10× pro Sekunde, ohne dass Brett, Hand und Leisten neu berechnet werden.
    let clock = GameClock()
    private(set) var clocks: [PlayerColor: Double] {
        get { clock.seconds }
        set { clock.seconds = newValue }
    }
    @Published private(set) var isThinking = false
    /// Gebietskarte (Index = row * 8 + col) und Anzahl Felder pro Spieler.
    @Published private(set) var control: [PlayerColor?] = Array(repeating: nil, count: 64)
    @Published private(set) var territory: [PlayerColor: Int] = [:]
    /// Kurzer Hinweis als Blase unter der Hand – verschwindet nach ein paar Sekunden von selbst.
    @Published var hint: String? {
        didSet { scheduleHintClear() }
    }
    private var hintToken = 0

    private func scheduleHintClear() {
        guard hint != nil else { return }
        hintToken += 1
        let token = hintToken
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard let self, self.hintToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.hint = nil }
        }
    }
    @Published var gameOver: GameOverInfo?
    /// Bauer erreicht die letzte Reihe: wartet auf die Wahl der Figur.
    @Published private(set) var promotionRequest: Move?
    /// Wiedergabe der gerade beendeten Partie.
    @Published private(set) var lastReplay: GameReplay?

    // Geführte erste Partie
    @Published private(set) var coach: CoachState?
    @Published private(set) var tutorialSquares: [Square] = []
    @Published private(set) var tutorialCard: CardType?
    @Published private(set) var tutorialUltimate = false
    @Published private(set) var tutorialHighlightTerritory = false
    @Published private(set) var tutorialComplete: (xp: Int, streak: Int?)?
    @Published private(set) var closeRequested = false
    /// Duell-Intro vor Bot- und Online-Partien: Solange es läuft, zieht niemand und die Uhr steht.
    @Published private(set) var introActive = false
    /// Hinweis über der Partie (Verbindung, Remis).
    @Published var onlineNotice: String?
    /// Der Gegner hat Remis angeboten.
    @Published var incomingDraw = false
    /// Zählt Fehlversuche – die Aufgabenleiste wackelt bei jeder Erhöhung.
    @Published private(set) var questNudge = 0
    @Published private(set) var questNudgeText: String?
    private var tutorialIndex = 0
    private var questTerritoryBefore = 0
    private var questManaBefore = 0
    private var nudgeClearTask: Task<Void, Never>?

    let mode: GameMode
    let humanColor: PlayerColor
    let timeControl: TimeControl
    /// Bot-Ersatz online: Lebenszeichen, Wertung über den Server, Gegner sieht aus wie ein Mensch (E1).
    let onlineBotPlay: OnlineBotPlay?
    /// Mensch gegen Mensch.
    let onlineSession: OnlineMatchSession?
    /// Gegnerkarte: Bot-Ersatz oder echter Mensch.
    let onlineOpponent: PlayerCard?

    private var cardsPlayedByHuman = 0
    private var startedAt = Date()
    /// Ausgangsstellung (inklusive Kartenreihenfolge) für die Wiedergabe.
    private var initialState: GameState?
    private var clockTask: Task<Void, Never>?
    private var lastTick: Date?
    private var finished = false
    private var lastWarnedSecond = -1
    private let store = ProfileStore.shared
    private var heartbeatTask: Task<Void, Never>?
    private var eventsTask: Task<Void, Never>?
    private var onlineReported = false
    /// Trophäen-Änderung vom Server, wenn die Partie schon als `abandoned` gewertet wurde.
    private var pendingServerDelta: Int?
    private var appliedServerTrophies = false
    private var serverAborted = false
    private var serverDrawAgreed = false
    private var timeoutClaimed = false
    private var silenceClaimed = false
    private var lastHeartbeatOK: Date?
    private var sendChain: Task<Void, Never>?

    // MARK: Start

    init(mode: GameMode, humanColor: PlayerColor, timeControl: TimeControl, onlineBotPlay: OnlineBotPlay? = nil) {
        self.mode = mode
        self.humanColor = humanColor
        // Bot-Leiter ohne Uhr (v0.9.34): Gegen die Charaktere darf man in Ruhe nachdenken.
        self.timeControl = mode.isLadder ? .none : timeControl
        self.onlineBotPlay = onlineBotPlay
        self.onlineSession = nil
        self.onlineOpponent = onlineBotPlay?.opponent
        self.state = GameViewModel.freshState(mode: mode, humanColor: humanColor, onlineBotPlay: onlineBotPlay)
        self.introActive = mode.isBot
        setupNewGame()
        startHeartbeat()
    }

    /// Online gegen einen Menschen (Anleitung Schritt 9). Stellung aus dem Protokoll, Uhr vom Server.
    init(online info: OnlineMatchInfo, session: OnlineMatchSession, resumed: Bool = false) {
        self.mode = .online(info.matchId)
        self.humanColor = info.myColor
        self.timeControl = info.timeControl
        self.onlineBotPlay = nil
        self.onlineSession = session
        self.onlineOpponent = info.opponent
        var start = info.record.initialState()
        start.events = []
        self.initialState = start
        self.state = info.record.replay().state
        self.state.events = []
        self.moves = GameViewModel.entries(for: info.record)
        self.cardsPlayedByHuman = moves.filter { $0.color == info.myColor && $0.card != nil }.count
        self.introActive = info.showIntro && !resumed
        self.clocks = [.white: info.clockWhite, .black: info.clockBlack]
        refresh()
        if resumed {
            hint = L("Zurück in deiner Partie")
        }
        startOnlineSession()
    }

    deinit {
        heartbeatTask?.cancel()
        eventsTask?.cancel()
        onlineSession?.close()
    }

    /// Das Duell-Intro ist vorbei: Uhr starten, Bot darf ziehen.
    func finishIntro() {
        guard introActive else { return }
        introActive = false
        startClock()
        scheduleAIIfNeeded()
        explainOnlineLeave()
        // Die Server-Uhr läuft schon seit dem Ende des Intro-Fensters. Restzeiten neu holen.
        if mode.isOnline, let id = onlineMatchId, let client = Backend.client {
            Task {
                if let fresh = try? await OnlineMatches.load(id: id, client: client), !finished {
                    clocks[.white] = fresh.clockWhite
                    clocks[.black] = fresh.clockBlack
                }
            }
        }
    }

    init(saved: SavedGame) {
        self.mode = saved.mode
        self.humanColor = saved.humanColor
        self.timeControl = saved.mode.isLadder ? .none : saved.timeControl
        self.onlineBotPlay = nil
        self.onlineSession = nil
        self.onlineOpponent = nil
        self.state = saved.state
        self.state.events = []
        self.moves = saved.moves
        self.cardsPlayedByHuman = saved.cardsPlayedByHuman
        self.startedAt = saved.startedAt
        self.initialState = saved.initialState
        clock.seconds = saved.clocks
        refresh()
        scheduleAIIfNeeded()
    }

    private func setupNewGame() {
        clocks = timeControl.isTimed
            ? [.white: timeControl.seconds, .black: timeControl.seconds]
            : [:]
        moves = []
        cardsPlayedByHuman = 0
        startedAt = Date()
        var start = state
        start.events = []
        initialState = start
        lastReplay = nil
        promotionRequest = nil
        finished = false
        gameOver = nil
        finisher = nil
        hint = mode == .tutorial ? nil : L("Kontrolliere Felder, um Mana zu laden. Volle Leiste = Ultimate.")
        clearSelection()
        refresh()
        if mode == .tutorial {
            tutorialIndex = 0
            tutorialComplete = nil
            showTutorialStep()
        }
        save()
        scheduleAIIfNeeded()
    }

    func restart() {
        if onlineBotPlay != nil || mode.isOnline {
            closeRequested = true
            NotificationCenter.default.post(name: .startQuickBattle, object: nil)
            return
        }
        stopClock()
        state = GameViewModel.freshState(mode: mode, humanColor: humanColor)
        effects = []
        banner = nil
        announcement = nil
        manaFloats = []
        introActive = mode.isBot   // Revanche: noch einmal das Duell-Intro
        setupNewGame()
        startClock()
    }

    private static func freshState(mode: GameMode, humanColor: PlayerColor, onlineBotPlay: OnlineBotPlay? = nil) -> GameState {
        let store = ProfileStore.shared
        if mode == .tutorial {
            var s = GameState.initial(ultimates: [.white: .meteor], decks: [.white: TutorialScript.playerHand])
            s.decks[.black] = nil
            return s
        }
        let mine = store.activeUltimate
        let myDeck = store.activeDeck
        if case .ladder(let level) = mode {
            return GameState.initial(ultimates: [humanColor: mine, humanColor.opponent: level.ultimate],
                                     decks: [humanColor: myDeck, humanColor.opponent: level.deck])
        }
        if case .practice(let level) = mode {
            return GameState.initial(ultimates: [humanColor: mine, humanColor.opponent: level.ultimate],
                                     decks: [humanColor: myDeck, humanColor.opponent: level.deck])
        }
        if mode.isBot, let level = mode.botLevel {
            // Kampf: derselbe Charakter wie in der Leiter – mit seinem Deck. Die Ultimate muss in der Arena schon verfügbar sein.
            // Bot-Ersatz online: das Deck, das der Server in der Partie stehen hat (nicht um die Arena-Sperre gekürzt).
            let botUltimate: Ultimate
            if onlineBotPlay != nil {
                botUltimate = level.ultimate
            } else {
                let pool = Ultimate.allCases.filter { store.profile.settings.testModeActive || $0.arena <= store.arena.number }
                botUltimate = pool.contains(level.ultimate) ? level.ultimate : (pool.randomElement() ?? .meteor)
            }
            return GameState.initial(ultimates: [humanColor: mine, humanColor.opponent: botUltimate],
                                     decks: [humanColor: myDeck, humanColor.opponent: level.deck])
        }
        return GameState.initial(ultimates: [.white: mine, .black: mine], decks: [.white: myDeck, .black: myDeck])
    }

    // MARK: Abgeleitete Werte

    var aiColor: PlayerColor? {
        if mode == .hotSeat || mode.isOnline { return nil }
        return humanColor.opponent
    }
    var isHumanTurn: Bool {
        if mode.isOnline { return state.current == humanColor }
        return aiColor != state.current
    }
    var handOwner: PlayerColor { mode == .hotSeat ? state.current : humanColor }
    var flipped: Bool { (mode.isBot || mode.isOnline) && humanColor == .black }
    /// Die Farbe unten am Brett – ihr Gebiet wird als „eigenes“ hervorgehoben.
    var perspective: PlayerColor { flipped ? .black : .white }
    var canInteract: Bool {
        !status.isOver && isHumanTurn && !isThinking && gameOver == nil && !(coach?.done ?? false)
    }

    var botLevel: BotLevel? { mode.botLevel }

    /// Figurenset für eine Farbe: Der Bot spielt mit seinem eigenen Set, du mit den Standardfiguren.
    /// In der ersten Schlacht trägt Mila ihr Sternenzauber-Set.
    func skin(for color: PlayerColor) -> BotLevel? {
        // Deine Figuren: das Set, das du im Profil gewählt hast (zu zweit gilt es für beide Seiten nicht)
        if mode.isBot && color == humanColor { return store.activeSkin }
        // Bot-Ersatz: Standardfiguren – ein Bot-Set würde den Ersatz verraten (E1)
        if onlineBotPlay != nil || mode.isOnline, color != humanColor { return nil }
        guard color == aiColor, store.profile.settings.botSkins else { return nil }
        if mode == .tutorial { return .medium }
        return botLevel
    }

    func name(for color: PlayerColor) -> String {
        if mode == .tutorial { return color == humanColor ? store.profile.name : L("Mila") }
        if let card = onlineOpponent, color != humanColor { return card.name }
        if let level = botLevel {
            return color == humanColor ? store.profile.name : level.displayName
        }
        return color.displayName
    }

    var pendingCard: CardType? { pending?.card }
    var pendingIsUltimate: Bool { pending != nil && pending?.card == nil }

    func isCardPlayable(_ index: Int, for color: PlayerColor) -> Bool {
        color == state.current && canInteract && playable.contains(index)
    }

    func canUseUltimate(_ color: PlayerColor) -> Bool {
        color == state.current && canInteract && ultimateUsable
    }

    /// Mana pro Zug – seit v0.9.20 immer gleich (+1), unabhängig vom Gebiet.
    func income(for color: PlayerColor) -> Int {
        GameState.manaPerTurn
    }

    func territoryCount(_ color: PlayerColor) -> Int {
        territory[color, default: 0]
    }

    func isMoveTarget(_ sq: Square) -> Bool { legalMoves.contains { $0.to == sq } }

    func isLastMoveSquare(_ sq: Square) -> Bool {
        guard let m = state.lastMove else { return false }
        return m.from == sq || m.to == sq
    }

    var checkedKing: Square? {
        switch status {
        case .check, .checkmate: return state.kingSquare(state.current)
        default: return nil
        }
    }

    /// Figuren der Farbe `color`, die der Gegner geschlagen hat (für die Spielerleiste).
    func capturedPieces(lostBy color: PlayerColor) -> [Piece] {
        (state.captured[color] ?? []).sorted { $0.type.value > $1.type.value }
    }

    // MARK: Eingaben

    func tap(_ sq: Square) {
        guard canInteract else { return }
        if pending != nil {
            handleTarget(sq)
            return
        }
        if let move = legalMoves.first(where: { $0.to == sq }) {
            performOrAskPromotion(move)
            return
        }
        selectPiece(at: sq)
    }

    func canDrag(from sq: Square) -> Bool {
        canInteract && pending == nil && state[sq]?.color == state.current
    }

    func beginDrag(at sq: Square) {
        guard canDrag(from: sq) else { return }
        if selected != sq {
            selected = sq
            legalMoves = state.legalMoves(from: sq)
            Feedback.play(nil, .select)
        }
    }

    @discardableResult
    func drop(from: Square, to: Square) -> Bool {
        guard canInteract else { return false }
        if let move = state.legalMoves(from: from).first(where: { $0.to == to }) {
            performOrAskPromotion(move)
            return true
        }
        if from != to {
            Feedback.play(nil, .invalid)
            if state.isBonusLocked(from) {
                hint = L("Diese Figur steht unter deinem Schild und bleibt in diesem Zug stehen – zieh eine andere.")
            }
        }
        return false
    }

    private func isPromotion(_ move: Move) -> Bool {
        guard let p = state[move.from] else { return false }
        return p.type == .pawn && move.to.row == p.color.promotionRow
    }

    /// Bei einer Umwandlung erst die Figur wählen lassen.
    private func performOrAskPromotion(_ move: Move) {
        if mode == .tutorial && !tutorialAllows(.move(move)) {
            tutorialNudge()
            return
        }
        if isPromotion(move) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { promotionRequest = move }
            Feedback.play(.select, .select)
            return
        }
        perform(move)
    }

    func choosePromotion(_ type: PieceType) {
        guard var move = promotionRequest else { return }
        move.promotion = type
        withAnimation(.easeOut(duration: 0.2)) { promotionRequest = nil }
        perform(move)
    }

    func cancelPromotion() {
        withAnimation(.easeOut(duration: 0.2)) { promotionRequest = nil }
        clearSelection()
    }

    private var manaSnapshot: [Int] { [state.mana[.white, default: 0], state.mana[.black, default: 0]] }

    private func selectPiece(at sq: Square) {
        guard let p = state[sq], p.color == state.current else {
            clearSelection()
            return
        }
        if selected == sq {
            clearSelection()
            return
        }
        selected = sq
        legalMoves = state.legalMoves(from: sq)
        Feedback.play(nil, .select)
        if legalMoves.isEmpty {
            if state.isBonusLocked(sq) {
                hint = L("Diese Figur steht unter deinem Schild und bleibt in diesem Zug stehen – zieh eine andere.")
            } else {
                hint = p.isFrozen(at: state.ply) ? L("Diese Figur ist eingefroren.") : L("Diese Figur kann gerade nicht ziehen.")
            }
        } else {
            hint = nil
        }
    }

    func tapCard(_ index: Int) {
        guard canInteract, let deck = state.decks[state.current], deck.hand.indices.contains(index) else { return }
        let card = deck.hand[index]
        let player = state.current
        if mode == .tutorial {
            guard case .card(let expected, _) = currentTutorialExpect, expected == card else {
                tutorialNudge()
                return
            }
        }

        if let p = pending, p.handIndex == index {
            cancelPending()
            return
        }
        let cooldown = state.cooldownRemaining(card, player: player)
        if cooldown > 0 {
            hint = L("{0} lädt noch {1} {2} nach.", card.name, cooldown, cooldown == 1 ? L("Zug") : L("Züge"))
            Feedback.play(nil, .invalid)
            return
        }
        if state.mana[player, default: 0] < card.cost {
            hint = L("Nicht genug Mana – {0} kostet {1}.", card.name, card.cost)
            Feedback.play(nil, .invalid)
            return
        }
        guard state.canPlay(card, player: player) else {
            hint = L("{0} hat gerade kein gültiges Ziel.", card.name)
            Feedback.play(nil, .invalid)
            return
        }
        clearSelection()
        if card.targeting == .none {
            play(card, handIndex: index, target: nil)
            return
        }
        pending = PendingCard(card: card, handIndex: index)
        cardTargets = Set(state.targets(for: card, player: player))
        hint = card.targetPrompt
        Feedback.play(.select, .select)
    }

    func tapUltimate() {
        guard canInteract, let u = state.ultimates[state.current] else { return }
        let player = state.current
        if mode == .tutorial {
            guard case .ultimate = currentTutorialExpect else {
                tutorialNudge()
                return
            }
        }
        if pendingIsUltimate {
            cancelPending()
            return
        }
        let mana = state.mana[player, default: 0]
        guard mana >= u.cost else {
            hint = L("{0} braucht {1} Mana ({2}/{1}).", u.name, u.cost, mana)
            Feedback.play(nil, .invalid)
            return
        }
        guard state.canUseUltimate(player) else {
            hint = L("{0} hat gerade kein gültiges Ziel.", u.name)
            Feedback.play(nil, .invalid)
            return
        }
        clearSelection()
        if u.needsTarget {
            pending = PendingCard(card: nil, handIndex: -1)
            cardTargets = Set(state.ultimateTargets(player))
            hint = u.targetPrompt
            Feedback.play(.select, .select)
        } else {
            performUltimate(target: nil)
        }
    }

    func cancelPending() {
        pending = nil
        cardTargets = []
        hint = nil
    }

    private func handleTarget(_ sq: Square) {
        guard let pend = pending else { return }
        if mode == .tutorial {
            var expectedTarget: String? = nil
            switch currentTutorialExpect {
            case .card(_, let t)?: expectedTarget = t
            case .ultimate(let t)?: expectedTarget = t
            default: break
            }
            if let t = expectedTarget, t != sq.name {
                tutorialNudge()
                return
            }
        }
        guard cardTargets.contains(sq) else {
            cancelPending()
            hint = L("Abgebrochen.")
            return
        }
        if let card = pend.card {
            play(card, handIndex: pend.handIndex, target: sq)
        } else {
            performUltimate(target: sq)
        }
    }

    func resign() {
        guard !status.isOver else { return }
        if mode.isOnline {
            Task { await resignOnline() }
            return
        }
        let loser = mode.isBot ? humanColor : state.current
        status = .resigned(winner: loser.opponent)
        finish()
    }

    var canOfferDraw: Bool {
        mode.isOnline && !status.isOver && moves.count >= 2 && !incomingDraw
    }

    func offerDraw() {
        guard canOfferDraw else { return }
        Task {
            do {
                try await onlineSession?.offerDraw()
                hint = L("Remis angeboten.")
            } catch {
                let message = String(describing: error)
                hint = message.contains("too_early") ? L("Remis erst nach dem ersten Zugpaar.") : L("Keine Verbindung zum Server.")
            }
        }
    }

    func answerDraw(_ accept: Bool) {
        incomingDraw = false
        Task {
            do { try await onlineSession?.answerDraw(accept: accept) }
            catch { hint = L("Keine Verbindung zum Server.") }
        }
    }

    // MARK: Karten

    /// Zählt diese Aktion für die Erfolge? Nur eigene Aktionen in Bot-Partien (nicht in der Einstiegspartie).
    /// Statistik-Zähler der laufenden Partie. Sie gehen erst am Ende (oder beim Verlassen) gesammelt ins Profil –
    /// sonst würde jede Karte das Profil ändern und alle Tabs hinter dem Spiel neu aufbauen (v0.9.25).
    private struct PendingStats {
        var cards: [String: Int] = [:]
        var bonus = 0
        var ults = 0
        var tactics = 0
        var isEmpty: Bool { cards.isEmpty && bonus == 0 && ults == 0 && tactics == 0 }
    }
    private var pendingStats = PendingStats()

    /// Gesammelte Zähler mit einer einzigen Profiländerung übernehmen.
    func flushStats() {
        guard !pendingStats.isEmpty else { return }
        let p = pendingStats
        pendingStats = PendingStats()
        var profile = store.profile
        for (card, n) in p.cards { profile.cardsByType[card, default: 0] += n }
        profile.bonusActions += p.bonus
        profile.ultimatesUsed += p.ults
        profile.tacticBonuses += p.tactics
        store.profile = profile
    }

    private func countsForAchievements(_ player: PlayerColor) -> Bool {
        mode.isBot && mode != .tutorial && player == humanColor
    }

    private func play(_ card: CardType, handIndex: Int, target: Square?) {
        let player = state.current
        let before = state

        withAnimation(.easeOut(duration: 0.2)) {
            state.playCard(card, handIndex: handIndex, target: target)
        }
        // Bonusaktionen beenden den Zug nicht – das Inkrement gibt es erst nach dem Figurzug.
        if timeControl.isTimed && !card.keepsTurn { clocks[player, default: 0] += timeControl.increment }
        if !mode.isBot || player == humanColor { cardsPlayedByHuman += 1 }
        if countsForAchievements(player) {
            pendingStats.cards[card.rawValue, default: 0] += 1
            if card.keepsTurn { pendingStats.bonus += 1 }
        }

        showBanner(CastBanner(title: card.name, icon: card.icon, isUltimate: false, caster: player, art: "art-card-\(card.rawValue)"))
        Feedback.play(.card, .cardCast)

        var sound: SoundKind? = .shield
        var haptic: HapticKind? = .shield
        switch card {
        case .shield:
            if let target { addEffect(.shield, at: target) }
        case .bulwark:
            for (sq, p) in state.pieces(of: player) where p.type == .pawn { addEffect(.shield, at: sq) }
        case .freeze:
            if let target { addEffect(.frost, at: target, duration: 1.1) }
            sound = .frost; haptic = .frost
        case .lightning:
            if let target { addEffect(.lightning, at: target, duration: 0.8) }
            sound = .lightning; haptic = .lightning
            bumpShake()
        case .knighting:
            if let target { addEffect(.promotion, at: target, duration: 1.1) }
            sound = .summon; haptic = .summon
        case .sprint:
            if let target { addEffect(.smoke, at: target.offset(2 * player.forward, 0)) }
            sound = .move; haptic = .move
        case .retreat:
            if let target { addEffect(.smoke, at: target) }
            sound = .move; haptic = .move
        case .reinforce, .revive:
            sound = .summon; haptic = .summon
        case .bishopize:
            if let target { addEffect(.promotion, at: target, duration: 1.1) }
            sound = .summon; haptic = .summon
        case .advance:
            sound = .move; haptic = .move
        case .swap:
            if let target { addEffect(.smoke, at: target) }
            if let k = before.kingSquare(player) { addEffect(.smoke, at: k) }
            sound = .castle; haptic = .move
        case .drain, .focus:
            sound = .notify; haptic = .mana
        case .sacrifice:
            if let target { addEffect(.lightning, at: target, duration: 0.8) }
            sound = .trap; haptic = .mana
        }
        delayedFeedback(sound, haptic)
        processEvents()

        finishAction(entry: MoveEntry(ply: before.ply, color: player,
                                      text: card.name + (target.map { " → \($0.name)" } ?? ""), card: card,
                                      action: .card(card, target), manaAfter: manaSnapshot))
        if card.keepsTurn && state.bonusActionUsed && state.current == player && !status.isOver {
            let mine = !mode.isBot || player == humanColor
            if mine {
                hint = card == .shield
                    ? L("Schild steht! Jetzt noch ein Figurzug – die geschützte Figur bleibt stehen.")
                    : (card == .sprint ? L("Sturmlauf! Jetzt noch ein Figurzug mit einer anderen Figur.")
                       : (card == .retreat ? L("Rückzug! Jetzt noch ein Figurzug mit einer anderen Figur.")
                          : L("{0} gespielt – jetzt noch dein Figurzug!", card.name)))
            } else {
                hint = L("{0} spielt {1} und zieht gleich noch.", name(for: player), card.name)
            }
        }
    }

    // MARK: Ultimate

    private func performUltimate(target: Square?) {
        let player = state.current
        let before = state
        guard let u = state.ultimates[player] else { return }

        withAnimation(.easeOut(duration: 0.25)) {
            state.useUltimate(target: target)
        }
        if timeControl.isTimed && !u.keepsTurn { clocks[player, default: 0] += timeControl.increment }

        showBanner(CastBanner(title: u.name, icon: u.icon, isUltimate: true, caster: player, art: "art-ult-\(u.rawValue)"))
        let mine = !mode.isBot || player == humanColor
        if countsForAchievements(player) { pendingStats.ults += 1 }
        announce(u.name.uppercased() + "!", L("Ultimate von {0}", name(for: player)), u.icon,
                 color: mine ? CardStyle.ultimateDeep : Theme.red)
        Feedback.play(.lightning, .heavyCapture)
        bumpShake()

        switch u {
        case .meteor:
            if let target {
                addEffect(.meteor, at: target, duration: 1.2)
                // Betäubte Nachbarbauern bekommen den Frost-Effekt
                for (dr, dc) in Dir.king {
                    let n = target.offset(dr, dc)
                    if n.isValid, let q = state[n], q.isFrozen(at: state.ply), !(before[n]?.isFrozen(at: state.ply) ?? false) {
                        addEffect(.frost, at: n, duration: 1.1)
                    }
                }
            }
        case .iceAge:
            for (sq, p) in state.pieces(of: player.opponent) where p.type != .king {
                addEffect(.frost, at: sq, duration: 1.1)
            }
            if let k = state.kingSquare(player.opponent) { addEffect(.iceWave, at: k, duration: 1.2) }
        case .fortress:
            for (sq, p) in state.pieces(of: player) where p.type != .king { addEffect(.shield, at: sq) }
        case .coronation:
            if let target { addEffect(.promotion, at: target, duration: 1.2) }
        case .rebirth:
            break
        }
        processEvents()
        finishAction(entry: MoveEntry(ply: before.ply, color: player,
                                      text: "★ " + u.name + (target.map { " → \($0.name)" } ?? ""), card: nil,
                                      action: .ultimate(target), manaAfter: manaSnapshot))
        if u.keepsTurn && state.bonusActionUsed && state.current == player && !status.isOver {
            hint = mine ? L("{0} steht! Jetzt noch dein Figurzug.", u.name) : L("{0} setzt {1} ein und zieht gleich noch.", name(for: player), u.name)
        }
    }

    // MARK: Schachzüge

    private func perform(_ move: Move) {
        let mover = state.current
        let before = state
        let text = GameViewModel.notation(move, in: before)

        withAnimation(.easeOut(duration: 0.18)) {
            state.makeMove(move)
        }
        if timeControl.isTimed { clocks[mover, default: 0] += timeControl.increment }

        var hadCapture = processEvents()

        // Taktik-Erkennung: Ansage und Mana-Bonus
        if !state.status().isOver, let tactic = TacticDetector.detect(after: state, move: move, mover: mover) {
            // Guter Zug gibt höchstens +1: Hat der Zug schon geschlagen oder Schach gegeben, gibt es kein zweites Plus.
            let alreadyRewarded = before[move.to] != nil || move.isEnPassant || state.isInCheck(mover.opponent)
            if !alreadyRewarded { state.gainMana(mover, Tactic.manaBonus, .tactic) }
            let mine = !mode.isBot || mover == humanColor
            if countsForAchievements(mover) { pendingStats.tactics += 1 }
            announce(tactic.title, alreadyRewarded ? L("Starker Zug von {0}", name(for: mover))
                                                   : L("+{0} Mana für {1}", Tactic.manaBonus, name(for: mover)), tactic.icon,
                     color: mine ? Theme.green : Theme.red)
            addEffect(.sparkle, at: move.to, duration: 1.0)
            Feedback.play(.shield, .heavyCapture)
            hadCapture = processEvents(tacticName: tactic.shortName) || hadCapture
        }

        let st = state.status()
        var entryText = text
        if case .checkmate = st {
            entryText += "#"
        } else if st == .check {
            entryText += "+"
        }
        if !st.isOver {
            if st == .check {
                Feedback.play(.check, .check)
            } else if !hadCapture {
                Feedback.play(move.castleRookFrom != nil ? .castle : .move, .move)
            }
        }
        finishAction(entry: MoveEntry(ply: before.ply, color: mover, text: entryText, card: nil,
                                      action: .move(move), manaAfter: manaSnapshot))
    }

    /// Gemeinsamer Abschluss nach jeder Aktion.
    private func finishAction(entry: MoveEntry) {
        clearSelection()
        pending = nil
        cardTargets = []
        hint = nil
        refresh()
        moves.append(entry)
        if mode.isOnline, entry.color == humanColor, let code = entry.action?.wire(ultimate: state.ultimates[entry.color]) {
            let ply = moves.count - 1
            let previous = sendChain
            sendChain = Task { [weak self] in
                await previous?.value
                await self?.sendOnline(code, ply: ply)
            }
        }

        if status.isOver {
            if case .checkmate(let winner) = status, let k = state.kingSquare(winner.opponent) {
                finisher = Finisher(square: k, winner: winner)
                Task {
                    Haptics.shared.play(.heavyCapture)
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    SoundPlayer.shared.play(.lightning)
                    Haptics.shared.play(.lightning)
                }
            }
            finish()
            return
        }
        if mode != .tutorial, isHumanTurn, let u = state.ultimates[state.current], state.mana[state.current, default: 0] >= u.cost, ultimateUsable {
            hint = L("{0} Mana – deine Ultimate ist bereit!", u.cost)
        }
        if mode == .tutorial { tutorialAfterAction(by: entry.color) }
        save()
        scheduleAIIfNeeded()
    }

    /// Wandelt Engine-Ereignisse in Effekte, Sound, Haptik und Mana-Anzeigen um. Rückgabe: Es gab einen Schlag.
    @discardableResult
    private func processEvents(tacticName: String? = nil) -> Bool {
        let events = state.events
        state.events.removeAll()
        var hadCapture = false

        for event in events {
            switch event {
            case .moved, .castle:
                break
            case .capture(let sq, let type, _):
                hadCapture = true
                if type.value >= 5 {
                    addEffect(.bigCapture, at: sq, duration: 1.0)
                    Feedback.play(.capture, .heavyCapture)
                    bumpShake()
                } else {
                    addEffect(.capture, at: sq)
                    Feedback.play(.capture, .capture)
                }
            case .destroyed:
                hadCapture = true
            case .promotion(let sq):
                addEffect(.promotion, at: sq, duration: 1.2)
            case .revived(let sq):
                addEffect(.revive, at: sq, duration: 1.1)
            case .mana(let color, let amount, let reason):
                let label = reason == .tactic ? (tacticName ?? reason.label) : reason.label
                showManaFloat(ManaFloat(color: color, amount: amount, label: label))
            }
        }
        return hadCapture
    }

    // MARK: Anzeigen

    private func showBanner(_ b: CastBanner) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { banner = b }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard let self, self.banner?.id == b.id else { return }
            withAnimation(.easeIn(duration: 0.25)) { self.banner = nil }
        }
    }

    private func announce(_ title: String, _ subtitle: String, _ icon: String, color: Color) {
        let a = Announcement(title: title, subtitle: subtitle, icon: icon, color: color)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { announcement = a }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard let self, self.announcement?.id == a.id else { return }
            withAnimation(.easeIn(duration: 0.25)) { self.announcement = nil }
        }
    }

    private func showManaFloat(_ f: ManaFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { manaFloats.append(f) }
        if f.color == handOwner { Haptics.shared.play(.mana) }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(.easeIn(duration: 0.3)) { self?.manaFloats.removeAll { $0.id == f.id } }
        }
    }

    private func delayedFeedback(_ sound: SoundKind?, _ haptic: HapticKind?) {
        Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            Feedback.play(sound, haptic)
        }
    }

    private func addEffect(_ kind: EffectKind, at sq: Square, duration: Double = 0.9) {
        let effect = BoardEffect(kind: kind, square: sq, duration: duration)
        effects.append(effect)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.2) * 1_000_000_000))
            self?.effects.removeAll { $0.id == effect.id }
        }
    }

    private func bumpShake() {
        withAnimation(.linear(duration: 0.35)) { shake += 1 }
    }

    private func clearSelection() {
        selected = nil
        legalMoves = []
    }

    private func refresh() {
        status = state.status()
        let player = state.current
        if let deck = state.decks[player] {
            playable = Set(deck.hand.indices.filter { state.canPlay(deck.hand[$0], player: player) })
        } else {
            playable = []
        }
        ultimateUsable = state.canUseUltimate(player)
        // Die Gebietskarte wird nur noch für die Brett-Tönung gebraucht – ohne Tönung sparen wir sie uns.
        if store.profile.settings.showTerritory {
            let map = state.controlMap()
            if map != control { control = map }
            territory = [.white: state.territory(.white, map: map), .black: state.territory(.black, map: map)]
        } else if control.contains(where: { $0 != nil }) {
            control = Array(repeating: nil, count: 64)
            territory = [:]
        }
    }

    static func notation(_ move: Move, in s: GameState) -> String {
        guard let p = s[move.from] else { return "" }
        if move.castleRookFrom != nil { return move.to.col == 6 ? "O-O" : "O-O-O" }
        let capture = s[move.to] != nil || move.isEnPassant
        var text = ""
        if p.type == .pawn {
            if capture { text += Square.files[move.from.col] }
        } else {
            text += p.type.letter
        }
        if capture { text += "x" }
        text += move.to.name
        if p.type == .pawn && move.to.row == p.color.promotionRow { text += "=" + (move.promotion ?? .queen).letter }
        return text
    }

    // MARK: KI

    private func scheduleAIIfNeeded() {
        guard let ai = aiColor, state.current == ai, !status.isOver, !finished, !introActive else { return }
        if mode == .tutorial {
            playTutorialReply()
            return
        }
        isThinking = true
        let snapshot = state
        let level = botLevel ?? .medium
        let ladder = mode.isLadder
        // Mit Uhr: höchstens ein Zwanzigstel der Restzeit plus der Großteil des Inkrements (v0.9.23)
        var maxSeconds: Double? = nil
        if timeControl.isTimed {
            maxSeconds = clocks[snapshot.current, default: 0] / 20 + timeControl.increment * 0.8
        }
        let budget = maxSeconds
        let pause = 0.45 + humanLikePause(snapshot)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            let decision = await Task.detached(priority: .userInitiated) {
                AIPlayer.decide(snapshot, level: level, ladder: ladder, maxSeconds: budget)
            }.value
            await self?.applyAI(decision, expectedPly: snapshot.ply)
        }
    }

    /// Kampf gegen Bots (v0.9.34): zufällige Extra-Denkzeit von 0–7 Sekunden, damit sich der Gegner wie ein Mensch anfühlt.
    /// Meist kurz, manchmal lang (Verteilung zur Null hin geneigt). Nach einer Bonuskarte nur kurz, und mit Uhr nie mehr
    /// als ein Zwölftel der Restzeit – so verliert der Bot nicht durch die künstliche Pause auf Zeit.
    /// Bot-Leiter, Übung und Tutorial: keine Extra-Pause.
    private func humanLikePause(_ snapshot: GameState) -> Double {
        guard case .bot = mode else { return 0 }
        var extra = pow(Double.random(in: 0...1), 1.5) * GameViewModel.maxHumanPause
        if snapshot.bonusActionUsed { extra = min(extra, 1.5) }
        // Die ersten beiden Züge kommen wie bei Menschen meist flott
        if snapshot.ply < 4 { extra = min(extra, 2) }
        if timeControl.isTimed {
            extra = min(extra, max(0, clocks[snapshot.current, default: 0] / 12 - 0.5))
        }
        return extra
    }

    static let maxHumanPause: Double = 7

    private func applyAI(_ decision: AIDecision?, expectedPly: Int) async {
        guard state.ply == expectedPly, !status.isOver, gameOver == nil else {
            isThinking = false
            return
        }
        isThinking = false
        switch decision {
        case .card(let card, let index, let target)?:
            applyOpponent(.card(card, target), handIndex: index)
        case .ultimate(let target)?:
            applyOpponent(.ultimate(target), handIndex: nil)
        case .move(let m)?:
            applyOpponent(.move(m), handIndex: nil)
        case .none:
            if let fallback = state.allLegalMoves(for: state.current).first { perform(fallback) }
        }
    }

    /// Gegnerzug (Bot oder Mensch) durch dieselben Wege wie ein eigener Zug – Animation, Ton, Mana.
    private func applyOpponent(_ action: ReplayAction, handIndex: Int? = nil) {
        switch action {
        case .move(let m):
            if state.legalMoves(from: m.from).contains(m) {
                perform(m)
            } else if !mode.isOnline, let fallback = state.allLegalMoves(for: state.current).first {
                perform(fallback)
            }
        case .card(let card, let target):
            let index = handIndex ?? state.decks[state.current]?.hand.firstIndex(of: card)
            if let index { play(card, handIndex: index, target: target) }
        case .ultimate(let target):
            performUltimate(target: target)
        }
    }

    // MARK: Uhr

    func startClock() {
        guard timeControl.isTimed, clockTask == nil, !status.isOver, !introActive else { return }
        lastTick = Date()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self else { return }
                self.tick()
            }
        }
    }

    func stopClock() {
        clockTask?.cancel()
        clockTask = nil
        lastTick = nil
        save()
    }

    private func tick() {
        guard !status.isOver, gameOver == nil, timeControl.isTimed else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastTick ?? now)
        lastTick = now
        let c = state.current
        let remaining = clocks[c, default: 0] - dt
        clocks[c] = max(0, remaining)

        if c == handOwner && remaining < 10 && remaining > 0 {
            let second = Int(remaining)
            if second != lastWarnedSecond {
                lastWarnedSecond = second
                Haptics.shared.play(.tick)
            }
        }
        if remaining <= 0 {
            if mode.isOnline {
                guard !timeoutClaimed else { return }
                timeoutClaimed = true
                Task { try? await self.onlineSession?.claimTimeout() }
                return
            }
            status = .timeout(winner: c.opponent)
            finish()
        }
    }

    // MARK: Ende & Speichern

    private func finish() {
        guard !finished else { return }
        finished = true
        flushStats()
        clockTask?.cancel()
        clockTask = nil
        isThinking = false
        if mode == .tutorial {
            finishTutorial()
            return
        }
        store.clearGame()

        let winner = status.winner
        let humanOnline = mode.isOnline
        let title: String
        let result: GameResultKind?
        if serverAborted {
            title = L("Abgebrochen")
            result = nil
        } else if mode.isBot || humanOnline {
            if let w = winner {
                result = w == humanColor ? .win : .loss
                if w == humanColor {
                    title = mode.isLadder ? L("{0} besiegt!", name(for: w.opponent)) : (mode.isPractice ? L("Übung gewonnen!") : L("Du hast gewonnen!"))
                } else {
                    title = L("{0} gewinnt", name(for: w))
                }
            } else {
                result = .draw
                title = L("Remis")
            }
        } else {
            if let w = winner {
                result = w == .white ? .win : .loss
                title = L("{0} gewinnt!", w.displayName)
            } else {
                result = .draw
                title = L("Remis")
            }
        }

        var replayID: UUID? = nil
        if let start = initialState, moves.contains(where: { $0.action != nil }) {
            let replay = GameReplay(date: Date(), title: title,
                                    subtitle: (mode.isBot ? L("gegen {0}", name(for: humanColor.opponent)) : L("Zu zweit")) + " · " + status.reason,
                                    humanColor: humanColor, initial: start, entries: moves)
            lastReplay = replay
            if mode != .tutorial { replayID = store.storeReplay(replay) }
        }

        heartbeatTask?.cancel()
        let chestsBefore = Set(store.profile.chests.map(\.id))
        let skinBefore = botLevel.map { store.isSkinUnlocked($0) } ?? true
        let roadBefore = Set(store.claimableRoadSteps.map(\.trophies))
        let botOnline = onlineBotPlay != nil
        let serverRated = botOnline || humanOnline
        if serverRated && !serverAborted { OnlineAccount.shared.noteFinishedOnlineGame() }
        // Übungspartien („Deck testen“) zählen nirgends – wie die Einstiegspartie.
        // Online: Trophäen nur vom Server; lokal nur Bilanz, Verlauf, XP/Truhen/Flamme.
        let delta: Int
        if mode == .tutorial || mode.isPractice || result == nil {
            delta = 0
        } else {
            delta = store.record(
                result: result ?? .draw, rated: mode.isRated && !serverRated,
                opponent: serverRated ? (onlineOpponent?.name ?? "") : (botLevel?.botName ?? "Zu zweit"),
                reason: status.reason, moves: moves.count,
                cardsPlayed: cardsPlayedByHuman, replayID: replayID,
                countsForStats: mode.isLadder || serverRated,
                opponentTrophies: botLevel?.rating)
        }
        // Zähler für Erfolge: Siegesserie und Matt-Siege (Kampf und Leiter)
        if mode.isBot && !mode.isPractice && mode != .tutorial, let result {
            switch result {
            case .win:
                store.profile.winStreak += 1
                store.profile.bestWinStreak = max(store.profile.bestWinStreak, store.profile.winStreak)
                if case .checkmate = status { store.profile.mateWins += 1 }
            case .loss:
                store.profile.winStreak = 0
            case .draw:
                break
            }
        }
        // Bot-Leiter: XP und nächster Gegner
        var ladderReward: ProfileStore.LadderReward? = nil
        if case .ladder(let level) = mode, result == .win {
            ladderReward = store.recordLadderWin(level)
        }
        // Truhen: die ersten drei Kampf-Siege des Tages, neue Arena
        var winChestsUsedUp = false
        if (mode.isRated || botOnline) && !serverAborted {
            if result == .win { winChestsUsedUp = !store.grantWinChest() }
        }
        // Tägliche Flamme: jede abgeschlossene Partie mit mindestens 10 Aktionen zählt.
        let lit = moves.count >= 10 ? store.registerActivity() : nil
        // Tagesziele gerade erfüllt (z. B. durch diesen Sieg): Die Tagestruhe kommt gleich mit.
        if mode.isBot && !mode.isPractice && store.dailyChestReady { _ = store.claimDailyChest() }
        let earned = store.profile.chests.filter { !chestsBefore.contains($0.id) }
        // Neue Stufe auf der Trophäenpfad erreicht? Abgeholt wird im Tab „Pfad“.
        let roadReady = store.claimableRoadSteps.first { !roadBefore.contains($0.trophies) }

        if mode.isBot || humanOnline {
            switch result {
            case .win: Feedback.play(.victory, .victory)
            case .loss: Feedback.play(.defeat, .defeat)
            case .draw, nil: Feedback.play(.notify, .shield)
            }
        } else {
            Feedback.play(winner == nil ? .notify : .victory, .victory)
        }

        let subtitle = serverAborted ? L("ohne Wertung") : (serverDrawAgreed ? L("durch Remis") : status.reason)
        var info = GameOverInfo(title: title, subtitle: subtitle, result: (mode.isBot || humanOnline) ? result : nil,
                                trophyDelta: pendingServerDelta ?? delta, rated: (mode.isRated || botOnline) && !serverAborted, streakLit: lit,
                                ladderXP: ladderReward?.xp, ladderUnlocked: ladderReward?.unlocked?.displayName,
                                skinUnlocked: botOnline || humanOnline || mode == .tutorial ? nil : botLevel.flatMap { !skinBefore && store.isSkinUnlocked($0) ? $0 : nil },
                                chests: earned, winChestsUsedUp: winChestsUsedUp, roadReady: roadReady,
                                hasWinner: winner != nil && !serverAborted,
                                opponent: (botOnline || humanOnline) ? nil : (mode.isBot && mode != .tutorial ? botLevel : nil),
                                disguise: onlineOpponent,
                                moveCount: moves.filter { $0.color == humanColor || !mode.isBot }.count,
                                cardsPlayed: cardsPlayedByHuman,
                                winnerColor: winner)
        let delay: UInt64 = finisher != nil ? 2_800_000_000 : 900_000_000
        Task { [weak self] in
            if botOnline, let result, let vm = self {
                let reported = await vm.reportOnlineBot(result: result)
                if let reported, reported != 0 {
                    info.trophyDelta = vm.pendingServerDelta ?? reported
                } else if reported == nil || result == .win || result == .draw {
                    // Netz weg, oder der Server hat einen Sieg nicht gutgeschrieben: dieselbe Formel wie lokal.
                    info.trophyDelta = vm.creditLocalTrophies(result)
                } else {
                    info.trophyDelta = 0
                }
            }
            if humanOnline {
                let waitUntil = Date().addingTimeInterval(2.5)
                while self?.pendingServerDelta == nil, Date() < waitUntil {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                if let pending = self?.pendingServerDelta { info.trophyDelta = pending }
            }
            try? await Task.sleep(nanoseconds: delay)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { self?.gameOver = info }
        }
    }

    /// Bot-Ersatz: Aktionen und Ergebnis an den Server. Gibt die Trophäen-Änderung des Menschen zurück,
    /// oder nil, wenn der Server nicht geantwortet hat.
    private func reportOnlineBot(result: GameResultKind) async -> Int? {
        guard let play = onlineBotPlay, let client = Backend.client, !onlineReported else { return 0 }
        onlineReported = true
        let outcome: BotMatchOutcome
        switch status {
        case .resigned: outcome = .resigned
        case .timeout: outcome = result == .loss ? .timeout : .completed
        default: outcome = .completed
        }
        let actions = matchRecord?.actions ?? []
        PendingBotReports.store(PendingBotReport(matchId: play.matchId, actions: actions, outcome: outcome.rawValue,
                                                 humanIsWhite: humanColor == .white))
        do {
            let delta = try await SupabaseBotMatchReporter(client: client)
                .finish(matchId: play.matchId, actions: actions, outcome: outcome, humanIsWhite: humanColor == .white)
            PendingBotReports.clear()
            store.profile.trophies = max(0, store.profile.trophies + delta)
            store.profile.bestTrophies = max(store.profile.bestTrophies, store.profile.trophies)
            if delta != 0, !store.profile.history.isEmpty, store.profile.history[0].trophyDelta == 0 {
                store.profile.history[0].trophyDelta = delta
            }
            OnlineAccount.shared.noteOnlineResult(result)
            OnlineAccount.shared.backupQuietly()
            Task { await OnlineAccount.shared.reload() }
            return delta
        } catch {
            return nil
        }
    }

    /// Dieselbe Trophäenformel wie `ProfileStore.record`, wenn der Server die Partie nicht gewertet hat.
    private func creditLocalTrophies(_ result: GameResultKind) -> Int {
        let opponent = botLevel?.rating ?? BotLevel.forTrophies(store.profile.trophies).rating
        let delta = TrophyStake.delta(mine: store.profile.trophies, opponent: opponent, result: result)
        guard delta != 0 else { return 0 }
        store.profile.trophies = max(0, store.profile.trophies + delta)
        store.profile.bestTrophies = max(store.profile.bestTrophies, store.profile.trophies)
        if !store.profile.history.isEmpty, store.profile.history[0].trophyDelta == 0 {
            store.profile.history[0].trophyDelta = delta
        }
        return delta
    }

    private var onlineMatchId: UUID? {
        if let id = onlineBotPlay?.matchId { return id }
        if case .online(let id) = mode { return id }
        return nil
    }

    private func startHeartbeat() {
        guard onlineMatchId != nil, Backend.client != nil else { return }
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            await self?.pingHeartbeatOnce()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(OnlineConfig.heartbeatInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.pingHeartbeatOnce()
            }
        }
    }

    /// Sofort den Server fragen (nach Hintergrund oder beim Öffnen) – nicht bis zum nächsten 10-s-Takt warten.
    func resumeOnlinePresence() {
        guard onlineMatchId != nil, !finished else { return }
        if heartbeatTask == nil { startHeartbeat() }
        else { Task { await pingHeartbeatOnce() } }
        if mode.isOnline { Task { await catchUp() } }
    }

    /// Lebenszeichen stoppen (Partie verlassen). Der Server wertet nach 45 s als Niederlage.
    func endOnlinePresence() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func pingHeartbeatOnce() async {
        guard let id = onlineMatchId, let client = Backend.client, !finished else { return }
        guard let snap = await OnlineHeartbeat.snapshot(client: client, matchId: id) else {
            noteOwnDisconnect()
            return
        }
        lastHeartbeatOK = Date()
        if mode.isOnline { onlineNotice = nil }
        if snap.status != "active" {
            if onlineBotPlay != nil { await abandonedByServer() }
            else { await pullServerFinish() }
            return
        }
        guard mode.isOnline else { return }
        if let silent = snap.opponentSilentSeconds {
            if silent >= 45, !silenceClaimed {
                silenceClaimed = true
                try? await onlineSession?.claimTimeout()
            } else if silent >= 15 {
                onlineNotice = L("Verbindung zum Gegner unterbrochen – noch {0} s", max(0, 45 - silent))
            }
        }
    }

    private func noteOwnDisconnect() {
        guard mode.isOnline, let last = lastHeartbeatOK else { return }
        let left = max(0, OnlineConfig.reconnectGrace - Date().timeIntervalSince(last))
        onlineNotice = L("Verbindung verloren – noch {0} s, um zurückzukommen", Int(left))
    }

    /// Der Server hat die Partie beendet (45 s ohne Lebenszeichen). Lokal als Niederlage anzeigen, nicht nochmal werten.
    private func abandonedByServer() async {
        guard !finished else { return }
        onlineReported = true
        PendingBotReports.clear()
        endOnlinePresence()
        let before = store.profile.trophies
        await OnlineAccount.shared.reload()
        if let p = OnlineAccount.shared.progress {
            store.profile.trophies = p.trophies
            store.profile.bestTrophies = max(store.profile.bestTrophies, p.bestTrophies)
            pendingServerDelta = p.trophies - before
        }
        status = .timeout(winner: humanColor.opponent)
        finish()
    }

    private func startOnlineSession() {
        guard let session = onlineSession else { return }
        eventsTask = Task { [weak self] in
            for await event in session.events {
                await self?.handleOnline(event)
            }
        }
        startHeartbeat()
        Task { await catchUp() }
    }

    private func explainOnlineLeave() {
        guard mode.isOnline else { return }
        let key = "rr.online.leaveOnce"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        hint = L("Verlässt du die App länger als 45 Sekunden, gilt die Partie als verloren.")
    }

    private func handleOnline(_ event: OnlineMatchEvent) async {
        switch event {
        case .action(let ply, let code, _):
            if ply < moves.count { return }
            if ply > moves.count { await rebuildFromServer(); return }
            guard let action = state.validate(code) else { await rebuildFromServer(); return }
            applyOpponent(action)
        case .clocks(let whiteMs, let blackMs, _):
            clocks[.white] = Double(whiteMs) / 1000
            clocks[.black] = Double(blackMs) / 1000
            if clocks[state.current, default: 0] > 0 { timeoutClaimed = false }
        case .drawOffered(let by):
            incomingDraw = by != humanColor
        case .drawOfferCleared:
            incomingDraw = false
        case .finished(let result, let winner, let delta):
            applyServerFinish(result: result, winner: winner, delta: delta)
        case .opponentConnected:
            break
        }
    }

    private func sendOnline(_ code: String, ply: Int, attempt: Int = 0) async {
        guard let session = onlineSession else { return }
        do {
            try await session.submit(code, ply: ply)
        } catch let error as OnlineMatchError {
            switch error {
            case .outOfSync, .illegalAction, .notYourTurn:
                hint = L("Die Stellung wurde abgeglichen.")
                await rebuildFromServer()
            case .timeout, .notActive:
                await pullServerFinish()
            case .network:
                guard attempt < 4 else { noteOwnDisconnect(); return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await sendOnline(code, ply: ply, attempt: attempt + 1)
            }
        } catch {
            guard attempt < 4 else { noteOwnDisconnect(); return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await sendOnline(code, ply: ply, attempt: attempt + 1)
        }
    }

    private func catchUp() async {
        guard let session = onlineSession, !finished else { return }
        guard let codes = try? await session.fetchActions() else { return }
        if codes.count > moves.count {
            await rebuild(codes)
        } else if codes.count < moves.count {
            for ply in codes.count..<moves.count {
                guard let action = moves[ply].action else { continue }
                let code = action.wire(ultimate: state.ultimates[moves[ply].color])
                await sendOnline(code, ply: ply)
            }
        }
    }

    private func rebuildFromServer() async {
        guard let codes = try? await onlineSession?.fetchActions() else { return }
        await rebuild(codes)
    }

    private func rebuild(_ codes: [String]) async {
        guard let session = onlineSession, !finished else { return }
        let record = MatchRecord(rulesVersion: session.info.record.rulesVersion,
                                 decks: session.info.record.decks,
                                 ultimates: session.info.record.ultimates,
                                 actions: codes)
        state = record.replay().state
        state.events = []
        moves = GameViewModel.entries(for: record)
        clearSelection()
        pending = nil
        refresh()
        if status.isOver { finish() }
    }

    private static func entries(for record: MatchRecord) -> [MoveEntry] {
        var s = record.initialState()
        var list: [MoveEntry] = []
        for (i, code) in record.actions.enumerated() {
            let color = s.current
            let action = s.validate(code)
            let card: CardType? = {
                if case .card(let c, _) = action { return c }
                return nil
            }()
            _ = s.apply(code)
            list.append(MoveEntry(ply: i, color: color, text: code, card: card, action: action))
        }
        return list
    }

    private func resignOnline() async {
        do {
            try await onlineSession?.resign()
        } catch {
            hint = L("Keine Verbindung zum Server.")
            return
        }
        if !finished {
            status = .resigned(winner: humanColor.opponent)
            finish()
        }
    }

    private func pullServerFinish() async {
        guard let id = onlineMatchId, let client = Backend.client else { return }
        guard let end = await OnlineMatches.finishState(id: id, client: client, myColor: humanColor) else { return }
        guard end.status != "active" else { return }
        applyServerFinish(result: end.result ?? end.status, winner: end.winner, delta: end.myDelta)
    }

    private func applyServerFinish(result: String, winner: PlayerColor?, delta: Int?) {
        if let delta {
            let outcome: GameResultKind = {
                guard let winner else { return .draw }
                return winner == humanColor ? .win : .loss
            }()
            applyServerTrophies(delta, result: outcome)
        }
        guard !finished else { return }
        switch result {
        case "mate":
            if let winner { status = .checkmate(winner: winner) }
        case "timeout", "abandoned":
            status = .timeout(winner: winner ?? humanColor.opponent)
        case "resigned":
            status = .resigned(winner: winner ?? humanColor.opponent)
        case "stalemate":
            status = .stalemate
        case "fifty":
            status = .drawFiftyMoves
        case "repetition":
            status = .drawRepetition
        case "draw_agreed":
            serverDrawAgreed = true
            status = .drawRepetition
        case "aborted":
            serverAborted = true
            status = .stalemate
        default:
            if let winner { status = .checkmate(winner: winner) }
            else { status = .stalemate }
        }
        finish()
    }

    private func applyServerTrophies(_ delta: Int, result: GameResultKind) {
        guard !appliedServerTrophies else { return }
        appliedServerTrophies = true
        pendingServerDelta = delta
        store.profile.trophies = max(0, store.profile.trophies + delta)
        store.profile.bestTrophies = max(store.profile.bestTrophies, store.profile.trophies)
        if var info = gameOver {
            info.trophyDelta = delta
            gameOver = info
        }
        OnlineAccount.shared.noteOnlineResult(result)
        OnlineAccount.shared.backupQuietly()
        Task { await OnlineAccount.shared.reload() }
    }

    /// Die Partie im Draht-Format (v0.9.26): Regel-Version, Decks, Ultimates und alle Aktionen.
    /// So wird sie später an den Server geschickt – und lässt sich überall mit `MatchRecord.replay()` nachprüfen.
    var matchRecord: MatchRecord? {
        guard let start = initialState else { return nil }
        var decks: [String: [String]] = [:]
        var ults: [String: String] = [:]
        for color in PlayerColor.allCases {
            let key = color == .white ? "white" : "black"
            if let d = start.decks[color] { decks[key] = (d.hand + d.queue).map(\.rawValue) }
            if let u = start.ultimates[color] { ults[key] = u.rawValue }
        }
        let actions = moves.compactMap { entry in entry.action?.wire(ultimate: start.ultimates[entry.color]) }
        return MatchRecord(rulesVersion: RulesConfig.current.version, decks: decks, ultimates: ults, actions: actions)
    }

    func save() {
        guard !finished, !status.isOver, mode != .tutorial, onlineBotPlay == nil, !mode.isOnline else { return }
        var snapshot = state
        snapshot.events = []
        store.saveGame(SavedGame(state: snapshot, mode: mode, humanColor: humanColor, timeControl: timeControl,
                                 clocks: clocks, moves: moves,
                                 cardsPlayedByHuman: cardsPlayedByHuman, startedAt: startedAt,
                                 initialState: initialState))
    }

    // MARK: Geführte erste Partie

    private var currentTutorialExpect: TutorialStep.Expect? {
        TutorialScript.steps.indices.contains(tutorialIndex) ? TutorialScript.steps[tutorialIndex].expect : nil
    }

    private func tutorialAllows(_ action: ReplayAction) -> Bool {
        guard let expect = currentTutorialExpect else { return false }
        switch (expect, action) {
        case (.move(let from, let to), .move(let m)):
            return m.from.name == from && m.to.name == to
        default:
            return false
        }
    }

    private static var nudges: [String] { [
        L("Fast! Folge dem goldenen Leuchten."),
        L("Nicht ganz – schau auf die goldenen Felder."),
        L("Probier's mit dem leuchtenden Ziel!")
    ] }

    private func tutorialNudge() {
        Feedback.play(nil, .invalid)
        questNudge += 1
        questNudgeText = GameViewModel.nudges[questNudge % GameViewModel.nudges.count]
        nudgeClearTask?.cancel()
        nudgeClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.questNudgeText = nil }
        }
    }

    private func showTutorialStep() {
        guard let step = TutorialScript.steps[safe: tutorialIndex] else { return }
        if step.fillMana {
            let before = state.mana[humanColor, default: 0]
            state.mana[humanColor] = GameState.maxMana
            if GameState.maxMana > before {
                showManaFloat(ManaFloat(color: humanColor, amount: GameState.maxMana - before, label: L("Bonus")))
            }
            refresh()
            Feedback.play(.summon, .summon)
        }
        tutorialSquares = []
        tutorialCard = nil
        tutorialUltimate = false
        switch step.expect {
        case .move(let from, let to):
            tutorialSquares = [from, to].compactMap { Square(name: $0) }
        case .card(let card, let target):
            tutorialCard = card
            tutorialSquares = target.flatMap { Square(name: $0) }.map { [$0] } ?? []
        case .ultimate(let target):
            tutorialUltimate = true
            tutorialSquares = target.flatMap { Square(name: $0) }.map { [$0] } ?? []
        }
        tutorialHighlightTerritory = step.highlightTerritory
        hint = nil
        questNudgeText = nil
        questTerritoryBefore = territory[humanColor, default: 0]
        questManaBefore = state.mana[humanColor, default: 0]
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            coach = CoachState(step: tutorialIndex, total: TutorialScript.steps.count, icon: step.icon,
                               title: step.title, text: step.text)
        }
    }

    func skipTutorial() {
        store.profile.tutorialSeen = true
        store.grantTutorialChest()   // Die erste Truhe gibt es auch beim Überspringen – sie wartet auf der Startseite.
        coach = nil
        closeRequested = true
    }

    /// Belohnungen der gerade erfüllten Aufgabe: feste Belohnung, Gebietszuwachs, Mana-Gewinn.
    private func questRewards(for step: TutorialStep) -> [QuestReward] {
        var list: [QuestReward] = []
        if let r = step.reward { list.append(r) }
        let mana = state.mana[humanColor, default: 0] - questManaBefore
        if mana > 0 {
            list.append(QuestReward(icon: "drop.fill", text: L("+{0} Mana", mana), tint: .mana))
        }
        if list.isEmpty {
            list.append(QuestReward(icon: "star.fill", text: L("Weiter so"), tint: .gold))
        }
        return Array(list.prefix(2))
    }

    /// Spieler erfüllt die Aufgabe: Jubel in der Leiste, Mila antwortet, dann geht es ohne Klick weiter.
    private func tutorialAfterAction(by color: PlayerColor) {
        if color == humanColor {
            guard let step = TutorialScript.steps[safe: tutorialIndex], var done = coach else { return }
            tutorialSquares = []
            tutorialCard = nil
            tutorialUltimate = false
            tutorialHighlightTerritory = false
            done.done = true
            done.praise = step.praise
            done.rewards = questRewards(for: step)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { coach = done }
            Feedback.play(.notify, .victory)
            if state.current == humanColor && !status.isOver {
                // Bonusaktion (Schild): Mila antwortet nicht – nach dem Jubel geht es mit dem Bonuszug weiter.
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 1_300_000_000)
                    guard let self, !self.finished else { return }
                    self.tutorialIndex += 1
                    self.showTutorialStep()
                }
            }
        } else {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard let self, !self.finished else { return }
                self.tutorialIndex += 1
                self.showTutorialStep()
            }
        }
    }

    private func playTutorialReply() {
        guard let reply = TutorialScript.steps[safe: tutorialIndex]?.reply else { return }
        isThinking = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self else { return }
            self.isThinking = false
            if let move = self.state.move(fromUCI: reply) {
                self.perform(move)
            }
        }
    }

    private func finishTutorial() {
        store.profile.tutorialSeen = true
        store.grantTutorialChest()   // zuerst: Die Erste Truhe wird als erste geöffnet
        store.addXP(50)              // Level 2 → Level-Truhe mit Ritterschlag
        let lit = store.registerActivity()
        tutorialSquares = []
        tutorialHighlightTerritory = false
        if var done = coach, let step = TutorialScript.steps.last {
            done.done = true
            done.praise = step.praise
            done.rewards = [QuestReward(icon: "sparkles", text: L("+50 XP"), tint: .mana),
                            QuestReward(icon: "shippingbox.fill", text: L("Erste Truhe"), tint: .gold)]
                + (lit != nil ? [QuestReward(icon: "flame.fill", text: L("Flamme"), tint: .gold)] : [])
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { coach = done }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_900_000_000)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { self?.tutorialComplete = (50, lit) }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Restzeiten beider Seiten. Nur die Uhr-Anzeigen beobachten dieses Objekt.
final class GameClock: ObservableObject {
    @Published var seconds: [PlayerColor: Double] = [:]
}

import Foundation

/// Richtungsvektoren (Zeile, Spalte).
enum Dir {
    static let knight: [(Int, Int)] = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
    static let king: [(Int, Int)] = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    static let rook: [(Int, Int)] = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    static let bishop: [(Int, Int)] = [(-1, -1), (-1, 1), (1, -1), (1, 1)]
}

/// Kompletter Spielzustand als Werttyp – kopierbar für Simulationen und speicherbar als JSON.
///
/// Regeln v0.6: Pro Runde genau EINE Aktion (Schachzug, Karte oder Ultimate).
/// Mana (v0.9.20): Jeder Zug lädt +1, ein guter Zug (Schlagen oder Schach) nochmal +1.
/// Das Gebiet bleibt als Anzeige auf dem Brett, bringt aber kein Mana mehr.
struct GameState: Codable {
    // Seit v0.9.26 aus `RulesConfig` (rookraid-rules.json, später vom Server aktualisierbar).
    static var maxMana: Int { RulesConfig.current.maxMana }
    /// Die Ultimate ist ab so viel Mana einsetzbar und verbraucht genau so viel – der Rest bleibt (v0.9.21).
    static var ultimateCost: Int { RulesConfig.current.ultimateCost }
    /// Mana zu Beginn jedes eigenen Zugs.
    static var manaPerTurn: Int { RulesConfig.current.manaPerTurn }
    /// Zusatz-Mana für einen guten Zug (Schlagen oder Schach) – höchstens einmal pro Zug.
    static var goodMoveBonus: Int { RulesConfig.current.goodMoveBonus }
    /// Nach dem Ausspielen lädt eine Karte so viele eigene Züge nach.
    static var cardCooldown: Int { RulesConfig.current.cardCooldown }
    static var drainGain: Int { RulesConfig.current.drainGain }
    static var focusGain: Int { RulesConfig.current.focusGain }
    static var sacrificeGain: Int { RulesConfig.current.sacrificeGain }
    static let allSquares: [Square] = (0..<8).flatMap { r in (0..<8).map { Square(row: r, col: $0) } }

    var board: [[Piece?]]
    /// Halbzug-Zähler. Gerade = Weiß am Zug, ungerade = Schwarz.
    var ply: Int = 0
    var enPassantTarget: Square? = nil
    /// Geschlagene Figuren, nach ihrer eigenen Farbe sortiert.
    var captured: [PlayerColor: [Piece]] = [.white: [], .black: []]
    var mana: [PlayerColor: Int] = [.white: 0, .black: 0]
    var lastMove: Move? = nil
    var decks: [PlayerColor: PlayerDeck] = [:]
    var ultimates: [PlayerColor: Ultimate] = [:]
    /// Abklingzeit: Halbzug, ab dem eine Karte wieder spielbar ist.
    var cardCooldowns: [PlayerColor: [CardType: Int]] = [:]

    /// Wird von der Oberfläche nach jeder Aktion ausgelesen und geleert.
    var events: [GameEvent] = []

    /// Schild oder Frost wurde in diesem Zug schon gespielt – jetzt folgt noch ein Figurzug.
    var bonusActionUsed = false
    /// Die mit Schild geschützte Figur: Sie darf im Figurzug nach der Bonusaktion nicht ziehen.
    var bonusLockedSquare: Square? = nil
    /// Nach der Festung: Der folgende Figurzug darf nicht schlagen und kein Schach (oder Matt) geben.
    var peacefulBonus = false
    /// Halbzüge seit dem letzten Bauernzug, Schlag oder Karteneinsatz (50-Züge-Regel).
    var halfmoveClock = 0
    /// Stellungsschlüssel seit der letzten unumkehrbaren Aktion (dreifache Wiederholung).
    var positionHistory: [Int] = []

    var current: PlayerColor { ply % 2 == 0 ? .white : .black }

    subscript(_ sq: Square) -> Piece? {
        get { board[sq.row][sq.col] }
        set { board[sq.row][sq.col] = newValue }
    }

    static func initial(ultimates: [PlayerColor: Ultimate], decks: [PlayerColor: [CardType]] = [:]) -> GameState {
        var board = Array(repeating: [Piece?](repeating: nil, count: 8), count: 8)
        let back: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for c in 0..<8 {
            board[0][c] = Piece(back[c], .black)
            board[1][c] = Piece(.pawn, .black)
            board[6][c] = Piece(.pawn, .white)
            board[7][c] = Piece(back[c], .white)
        }
        var state = GameState(board: board)
        for color in PlayerColor.allCases {
            state.decks[color] = PlayerDeck(cards: decks[color] ?? DeckPreset.starter.cards)
        }
        state.ultimates = ultimates
        state.beginTurn()      // Weiß erhält sein erstes Mana
        state.events = []
        state.positionHistory = [state.positionKey()]
        return state
    }

    // MARK: - Hilfsfunktionen

    func isFree(_ sq: Square) -> Bool { sq.isValid && self[sq] == nil }

    /// Kann die Figur auf diesem Feld gerade geschlagen werden?
    func canBeCaptured(_ sq: Square) -> Bool {
        guard let p = self[sq] else { return false }
        return p.type != .king && !p.isShielded(at: ply)
    }

    /// „Ungeschützt“ (Blitz, Meteor): nicht unter Schild/Bollwerk UND von keiner eigenen Figur gedeckt.
    func isUnprotected(_ sq: Square) -> Bool {
        guard let p = self[sq] else { return false }
        return canBeCaptured(sq) && !isAttacked(sq, by: p.color)
    }

    func kingSquare(_ color: PlayerColor) -> Square? {
        GameState.allSquares.first { sq in
            if let p = self[sq], p.type == .king, p.color == color { return true }
            return false
        }
    }

    func pieces(of color: PlayerColor) -> [(Square, Piece)] {
        GameState.allSquares.compactMap { sq in
            if let p = self[sq], p.color == color { return (sq, p) }
            return nil
        }
    }

    // MARK: - Angriffe & Schach

    func isInCheck(_ color: PlayerColor) -> Bool {
        guard let k = kingSquare(color) else { return false }
        return isAttacked(k, by: color.opponent)
    }

    /// Wird `target` von einer Figur der Farbe `attacker` angegriffen? (Frost ändert Bedrohungen nicht.)
    func isAttacked(_ target: Square, by attacker: PlayerColor) -> Bool {
        for dc in [-1, 1] {
            let s = target.offset(-attacker.forward, dc)
            if s.isValid, let p = self[s], p.color == attacker, p.type == .pawn { return true }
        }
        for (dr, dc) in Dir.knight {
            let s = target.offset(dr, dc)
            if s.isValid, let p = self[s], p.color == attacker, p.type == .knight { return true }
        }
        for (dr, dc) in Dir.king {
            let s = target.offset(dr, dc)
            if s.isValid, let p = self[s], p.color == attacker, p.type == .king { return true }
        }
        for (dr, dc) in Dir.rook {
            var s = target.offset(dr, dc)
            while s.isValid {
                if let p = self[s] {
                    if p.color == attacker && (p.type == .rook || p.type == .queen) { return true }
                    break
                }
                s = s.offset(dr, dc)
            }
        }
        for (dr, dc) in Dir.bishop {
            var s = target.offset(dr, dc)
            while s.isValid {
                if let p = self[s] {
                    if p.color == attacker && (p.type == .bishop || p.type == .queen) { return true }
                    break
                }
                s = s.offset(dr, dc)
            }
        }
        return false
    }

    /// Ruft `visit` für jedes Feld auf, das die Figur auf `sq` angreift (bis einschließlich der ersten Blockade).
    func forEachAttack(from sq: Square, piece p: Piece, _ visit: (Square) -> Void) {
        let dirs: [(Int, Int)]
        let sliding: Bool
        switch p.type {
        case .pawn: dirs = [(p.color.forward, -1), (p.color.forward, 1)]; sliding = false
        case .knight: dirs = Dir.knight; sliding = false
        case .bishop: dirs = Dir.bishop; sliding = true
        case .rook: dirs = Dir.rook; sliding = true
        case .queen: dirs = Dir.rook + Dir.bishop; sliding = true
        case .king: dirs = Dir.king; sliding = false
        }
        for (dr, dc) in dirs {
            var t = sq.offset(dr, dc)
            while t.isValid {
                visit(t)
                if !sliding || self[t] != nil { break }
                t = t.offset(dr, dc)
            }
        }
    }

    func attackSquares(from sq: Square) -> [Square] {
        guard let p = self[sq] else { return [] }
        var out: [Square] = []
        forEachAttack(from: sq, piece: p) { out.append($0) }
        return out
    }

    // MARK: - Gebiet

    /// Gebiet (v0.6): Jede Figur besetzt ihr eigenes Feld und alle 8 Nachbarfelder (auch diagonal).
    /// Ist ein Feld Nachbar von Figuren beider Farben oder von gar keiner Figur, ist es neutral.
    /// Index = row * 8 + col.
    func controlMap() -> [PlayerColor?] {
        var white = [Bool](repeating: false, count: 64)
        var black = [Bool](repeating: false, count: 64)
        for r in 0..<8 {
            for c in 0..<8 {
                guard let p = board[r][c] else { continue }
                for dr in -1...1 {
                    for dc in -1...1 {
                        let rr = r + dr
                        let cc = c + dc
                        guard (0..<8).contains(rr), (0..<8).contains(cc) else { continue }
                        if p.color == .white {
                            white[rr * 8 + cc] = true
                        } else {
                            black[rr * 8 + cc] = true
                        }
                    }
                }
            }
        }
        return (0..<64).map { i in
            if white[i] && !black[i] { return .white }
            if black[i] && !white[i] { return .black }
            return nil
        }
    }

    func territory(_ color: PlayerColor, map: [PlayerColor?]? = nil) -> Int {
        (map ?? controlMap()).filter { $0 == color }.count
    }

    // MARK: - Mana

    mutating func gainMana(_ color: PlayerColor, _ amount: Int, _ reason: ManaReason) {
        guard amount > 0 else { return }
        let before = mana[color, default: 0]
        let after = min(GameState.maxMana, before + amount)
        mana[color] = after
        if after > before { events.append(.mana(color, after - before, reason)) }
    }

    // MARK: - Zuggenerierung

    func pseudoMoves(from sq: Square) -> [Move] {
        guard let piece = self[sq], !piece.isFrozen(at: ply), !isBonusLocked(sq) else { return [] }
        let color = piece.color
        var moves: [Move] = []

        func capturable(_ t: Square) -> Bool {
            guard let other = self[t] else { return false }
            return other.color != color && canBeCaptured(t)
        }

        /// Fügt einen Schritt hinzu. Rückgabe true = Feld war leer (Langschrittfiguren dürfen weiter).
        @discardableResult
        func addStep(_ t: Square) -> Bool {
            guard t.isValid else { return false }
            if self[t] != nil {
                if capturable(t) { moves.append(Move(from: sq, to: t)) }
                return false
            }
            moves.append(Move(from: sq, to: t))
            return true
        }

        func slide(_ dirs: [(Int, Int)]) {
            for (dr, dc) in dirs {
                var t = sq.offset(dr, dc)
                while addStep(t) { t = t.offset(dr, dc) }
            }
        }

        switch piece.type {
        case .pawn:
            let one = sq.offset(color.forward, 0)
            let two = sq.offset(2 * color.forward, 0)
            if isFree(one) {
                moves.append(Move(from: sq, to: one))
                if !piece.hasMoved && sq.row == color.pawnStartRow && isFree(two) {
                    moves.append(Move(from: sq, to: two, isDoublePawnStep: true))
                }
            }
            for dc in [-1, 1] {
                let t = sq.offset(color.forward, dc)
                guard t.isValid else { continue }
                if self[t] != nil {
                    if capturable(t) { moves.append(Move(from: sq, to: t)) }
                } else if t == enPassantTarget {
                    let victimSq = Square(row: sq.row, col: t.col)
                    if let victim = self[victimSq], victim.type == .pawn, victim.color != color, canBeCaptured(victimSq) {
                        moves.append(Move(from: sq, to: t, isEnPassant: true))
                    }
                }
            }
        case .knight:
            for (dr, dc) in Dir.knight { addStep(sq.offset(dr, dc)) }
        case .bishop:
            slide(Dir.bishop)
        case .rook:
            slide(Dir.rook)
        case .queen:
            slide(Dir.rook + Dir.bishop)
        case .king:
            for (dr, dc) in Dir.king { addStep(sq.offset(dr, dc)) }
            moves += castlingMoves(from: sq, king: piece)
        }
        return moves
    }

    private func castlingMoves(from sq: Square, king: Piece) -> [Move] {
        let color = king.color
        let enemy = color.opponent
        guard !king.hasMoved, sq == Square(row: color.homeRow, col: 4), !isAttacked(sq, by: enemy) else { return [] }
        var result: [Move] = []

        let rookShort = Square(row: sq.row, col: 7)
        if let rook = self[rookShort], rook.type == .rook, rook.color == color, !rook.hasMoved, !isBonusLocked(rookShort),
           isFree(sq.offset(0, 1)), isFree(sq.offset(0, 2)),
           !isAttacked(sq.offset(0, 1), by: enemy), !isAttacked(sq.offset(0, 2), by: enemy) {
            result.append(Move(from: sq, to: sq.offset(0, 2), castleRookFrom: rookShort, castleRookTo: sq.offset(0, 1)))
        }
        let rookLong = Square(row: sq.row, col: 0)
        if let rook = self[rookLong], rook.type == .rook, rook.color == color, !rook.hasMoved, !isBonusLocked(rookLong),
           isFree(sq.offset(0, -1)), isFree(sq.offset(0, -2)), isFree(sq.offset(0, -3)),
           !isAttacked(sq.offset(0, -1), by: enemy), !isAttacked(sq.offset(0, -2), by: enemy) {
            result.append(Move(from: sq, to: sq.offset(0, -2), castleRookFrom: rookLong, castleRookTo: sq.offset(0, -1)))
        }
        return result
    }

    /// Nach Schild bleibt die geschützte Figur im folgenden Figurzug stehen (auch nicht als Rochade-Turm).
    func isBonusLocked(_ sq: Square) -> Bool {
        bonusActionUsed && bonusLockedSquare == sq
    }

    func legalMoves(from sq: Square) -> [Move] {
        guard let piece = self[sq] else { return [] }
        let peaceful = bonusActionUsed && peacefulBonus
        return pseudoMoves(from: sq).filter { move in
            // Festung: Im Bonuszug weder schlagen noch Schach geben
            if peaceful && (self[move.to] != nil || move.isEnPassant) { return false }
            var copy = self
            copy.applyBoardMove(move)
            if copy.isInCheck(piece.color) { return false }
            if peaceful && copy.isInCheck(piece.color.opponent) { return false }
            return true
        }
    }

    func allLegalMoves(for color: PlayerColor) -> [Move] {
        var result: [Move] = []
        for sq in GameState.allSquares where self[sq]?.color == color {
            result += legalMoves(from: sq)
        }
        return result
    }

    func hasAnyLegalMove(for color: PlayerColor) -> Bool {
        for sq in GameState.allSquares where self[sq]?.color == color {
            if !legalMoves(from: sq).isEmpty { return true }
        }
        return false
    }

    // MARK: - Züge ausführen

    /// Führt den Zug auf dem Brett aus (ohne Seitenwechsel). Wird auch für Simulationen genutzt.
    mutating func applyBoardMove(_ move: Move) {
        guard var piece = self[move.from] else { return }
        let mover = piece.color

        var victimSq: Square? = nil
        if move.isEnPassant {
            victimSq = Square(row: move.from.row, col: move.to.col)
        } else if self[move.to] != nil {
            victimSq = move.to
        }

        self[move.from] = nil
        piece.hasMoved = true

        if let vs = victimSq, let victim = self[vs] {
            self[vs] = nil
            events.append(.capture(vs, victim.type, by: mover))
            captured[victim.color, default: []].append(victim)
            gainMana(mover, GameState.goodMoveBonus, .capture)
        } else {
            events.append(.moved(move.to))
        }

        if piece.type == .pawn && move.to.row == mover.promotionRow {
            piece.type = move.promotion ?? .queen
            // Eine neue Figur übernimmt keinen Schild (Schild, Bollwerk oder Festung) vom Bauern (v0.9.31)
            piece.shieldedUntil = -1
            events.append(.promotion(move.to))
        }

        self[move.to] = piece

        if let rf = move.castleRookFrom, let rt = move.castleRookTo, var rook = self[rf] {
            self[rf] = nil
            rook.hasMoved = true
            self[rt] = rook
            events.append(.castle(rt))
        }

        enPassantTarget = move.isDoublePawnStep
            ? Square(row: (move.from.row + move.to.row) / 2, col: move.from.col)
            : nil
        lastMove = move
    }

    /// Vollständiger Schachzug: Brett ändern, Schach-Bonus, Seite wechseln, Zugbeginn des Gegners.
    mutating func makeMove(_ move: Move) {
        let mover = current
        let isCapture = self[move.to] != nil || move.isEnPassant
        let irreversible = self[move.from]?.type == .pawn || isCapture || move.castleRookFrom != nil
        applyBoardMove(move)
        // Guter Zug: Schlagen hat schon +1 gebracht – Schach gibt nur dann +1, wenn nichts geschlagen wurde.
        if !isCapture && isInCheck(mover.opponent) { gainMana(mover, GameState.goodMoveBonus, .check) }
        ply += 1
        bonusActionUsed = false
        bonusLockedSquare = nil
        peacefulBonus = false
        if irreversible {
            halfmoveClock = 0
            positionHistory = []
        } else {
            halfmoveClock += 1
        }
        positionHistory.append(positionKey())
        beginTurn()
    }

    /// Zugwechsel nach einer Karte oder Ultimate. Karteneinsätze gelten als unumkehrbar.
    mutating func passTurn() {
        enPassantTarget = nil
        ply += 1
        bonusActionUsed = false
        bonusLockedSquare = nil
        peacefulBonus = false
        halfmoveClock = 0
        positionHistory = [positionKey()]
        beginTurn()
    }

    /// Deterministischer Schlüssel der Stellung (Figuren, Seite am Zug, Rochaderechte, En passant).
    func positionKey() -> Int {
        var h: UInt64 = 1_469_598_103_934_665_603
        func mix(_ v: Int) { h = (h ^ UInt64(truncatingIfNeeded: v)) &* 1_099_511_628_211 }
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = board[r][c] {
                    let typeCode: Int
                    switch p.type {
                    case .pawn: typeCode = 1
                    case .knight: typeCode = 2
                    case .bishop: typeCode = 3
                    case .rook: typeCode = 4
                    case .queen: typeCode = 5
                    case .king: typeCode = 6
                    }
                    // Unbewegte Könige und Türme tragen die Rochaderechte
                    let castle = (p.type == .king || p.type == .rook) && !p.hasMoved ? 16 : 0
                    mix(typeCode + (p.color == .white ? 0 : 8) + castle)
                } else {
                    mix(0)
                }
            }
        }
        mix(current == .white ? 1 : 2)
        mix(enPassantTarget.map { $0.index + 100 } ?? 99)
        return Int(truncatingIfNeeded: h)
    }

    var repetitionCount: Int {
        guard let last = positionHistory.last else { return 0 }
        return positionHistory.filter { $0 == last }.count
    }

    mutating func beginTurn() {
        let c = current
        gainMana(c, GameState.manaPerTurn, .turn)
        // Tauwetter: Kann ein Spieler (nicht im Schach) nur wegen Frost nicht ziehen, tauen seine Figuren sofort auf –
        // Frost erzwingt nie ein Patt. Ein Matt mit Hilfe von Frost bleibt ein Matt.
        let frozen = pieces(of: c).filter { $0.1.isFrozen(at: ply) }
        if !frozen.isEmpty && !isInCheck(c) && !hasAnyLegalMove(for: c) {
            for (sq, var p) in frozen {
                p.frozenUntil = -1
                self[sq] = p
            }
        }
    }

    func status() -> GameStatus {
        let inCheck = isInCheck(current)
        if !hasAnyLegalMove(for: current) {
            return inCheck ? .checkmate(winner: current.opponent) : .stalemate
        }
        if halfmoveClock >= 100 { return .drawFiftyMoves }
        if repetitionCount >= 3 { return .drawRepetition }
        return inCheck ? .check : .ongoing
    }

    /// Materialbilanz aus Sicht von `color` (für die „+2“-Anzeige).
    func materialBalance(for color: PlayerColor) -> Int {
        var sum = 0
        for sq in GameState.allSquares {
            if let p = self[sq] {
                sum += p.color == color ? p.type.points : -p.type.points
            }
        }
        return sum
    }
}

// MARK: - Tolerantes Laden (Spielstände aus älteren Versionen)

extension GameState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        board = try c.decode([[Piece?]].self, forKey: .board)
        ply = try c.decodeIfPresent(Int.self, forKey: .ply) ?? 0
        enPassantTarget = try c.decodeIfPresent(Square.self, forKey: .enPassantTarget)
        captured = try c.decodeIfPresent([PlayerColor: [Piece]].self, forKey: .captured) ?? [.white: [], .black: []]
        mana = try c.decodeIfPresent([PlayerColor: Int].self, forKey: .mana) ?? [.white: 0, .black: 0]
        lastMove = try c.decodeIfPresent(Move.self, forKey: .lastMove)
        decks = (try? c.decodeIfPresent([PlayerColor: PlayerDeck].self, forKey: .decks)) ?? nil ?? [:]
        cardCooldowns = (try? c.decodeIfPresent([PlayerColor: [CardType: Int]].self, forKey: .cardCooldowns)) ?? nil ?? [:]
        // Ultimates tolerant: unbekannte Werte aus alten Versionen werden übersprungen
        var ults: [PlayerColor: Ultimate] = [:]
        if let raw = try? c.decodeIfPresent([PlayerColor: String].self, forKey: .ultimates) {
            for (k, v) in raw { if let u = Ultimate(rawValue: v) { ults[k] = u } }
        }
        ultimates = ults
        events = []
        bonusActionUsed = try c.decodeIfPresent(Bool.self, forKey: .bonusActionUsed) ?? false
        bonusLockedSquare = try c.decodeIfPresent(Square.self, forKey: .bonusLockedSquare)
        peacefulBonus = try c.decodeIfPresent(Bool.self, forKey: .peacefulBonus) ?? false
        halfmoveClock = try c.decodeIfPresent(Int.self, forKey: .halfmoveClock) ?? 0
        positionHistory = try c.decodeIfPresent([Int].self, forKey: .positionHistory) ?? []
    }
}

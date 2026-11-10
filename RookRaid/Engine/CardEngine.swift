import Foundation

// MARK: - Karten

extension GameState {

    func bestRevivableIndex(for player: PlayerColor, includeQueen: Bool) -> Int? {
        let list = captured[player] ?? []
        var best: Int? = nil
        for (i, p) in list.enumerated() {
            let allowed = p.type == .rook || p.type == .bishop || p.type == .knight || (includeQueen && p.type == .queen)
            guard allowed else { continue }
            if let b = best {
                if p.type.value > list[b].type.value { best = i }
            } else {
                best = i
            }
        }
        return best
    }

    /// Rohe Kandidaten (vor Prüfung der Schutzregeln).
    func candidateSquares(for card: CardType, player: PlayerColor) -> [Square] {
        let opp = player.opponent
        func own(_ filter: (Square, Piece) -> Bool) -> [Square] {
            GameState.allSquares.filter { sq in
                guard let p = self[sq], p.color == player else { return false }
                return filter(sq, p)
            }
        }
        switch card {
        case .shield:
            return own { _, p in p.type != .king }
        case .freeze:
            // König und Dame sind immun gegen Frost
            return GameState.allSquares.filter { sq in
                guard let p = self[sq] else { return false }
                return p.color == opp && p.type != .king && p.type != .queen
            }
        case .lightning:
            return GameState.allSquares.filter { sq in
                guard let p = self[sq] else { return false }
                // Seit v0.9.24: nur gegnerische Bauern, die in deine Hälfte vorgerückt sind (nicht unter Schild oder Bollwerk)
                return p.color == opp && p.type == .pawn && player.ownsHalf(sq) && canBeCaptured(sq)
            }
        case .knighting:
            return own { _, p in p.type == .pawn }
        case .sprint:
            return own { sq, p in
                let one = sq.offset(player.forward, 0)
                let two = sq.offset(2 * player.forward, 0)
                return p.type == .pawn && isFree(one) && isFree(two) && two.row != player.promotionRow
            }
        case .reinforce:
            return (0..<8).map { Square(row: player.pawnStartRow, col: $0) }.filter { isFree($0) }
        case .revive:
            guard bestRevivableIndex(for: player, includeQueen: false) != nil else { return [] }
            return (0..<8).map { Square(row: player.homeRow, col: $0) }.filter { isFree($0) }
        case .bishopize, .sacrifice:
            return own { _, p in p.type == .pawn }
        case .swap:
            return own { _, p in p.type != .king && p.type != .pawn }
        case .retreat:
            // Ziel ist das freie Feld, auf das ein eigener Bauer zurückweicht (nicht die eigene Grundreihe)
            return GameState.allSquares.filter { sq in
                isFree(sq) && sq.row != player.homeRow && retreatOrigin(for: player, to: sq) != nil
            }
        case .bulwark, .advance, .drain, .focus:
            return []
        }
    }

    /// Rückzug (v0.9.34): Der eigene Bauer, der auf das freie Feld `dest` zurückweichen kann – ein oder zwei Felder
    /// weiter vorn in derselben Linie, dazwischen frei. Weil der Weg frei sein muss, gibt es höchstens einen.
    func retreatOrigin(for player: PlayerColor, to dest: Square) -> Square? {
        for k in 1...2 {
            let sq = dest.offset(k * player.forward, 0)
            guard sq.isValid else { return nil }
            if let p = self[sq] { return p.color == player && p.type == .pawn ? sq : nil }
        }
        return nil
    }

    /// Vormarsch: Welche Bauern würden vorrücken? (vorderste zuerst, damit hintere nachrücken können)
    func advancingPawns(for player: PlayerColor) -> [Square] {
        var copy = self
        var moved: [Square] = []
        let pawns = pieces(of: player).filter { $0.1.type == .pawn }.map { $0.0 }
            .sorted { player == .white ? $0.row < $1.row : $0.row > $1.row }
        for sq in pawns {
            let dest = sq.offset(player.forward, 0)
            if dest.isValid && dest.row != player.promotionRow && copy.isFree(dest), let p = copy[sq] {
                copy[sq] = nil
                copy[dest] = p
                moved.append(sq)
            }
        }
        return moved
    }

    /// Restliche Abklingzeit einer Karte in eigenen Zügen (0 = bereit).
    func cooldownRemaining(_ card: CardType, player: PlayerColor) -> Int {
        guard let ready = cardCooldowns[player]?[card], ready > ply else { return 0 }
        return (ready - ply + 1) / 2
    }

    /// Welche Figur nach der Bonuskarte stehen bleiben muss (Schild: die geschützte, Sturmlauf: der vorgerückte Bauer).
    func bonusLock(for card: CardType, target: Square?, player: PlayerColor) -> Square? {
        guard let target else { return nil }
        if card.locksTarget { return target }
        if card.locksMovedPawn { return target.offset(2 * player.forward, 0) }
        return nil
    }

    /// Gültige Ziele (alle Schutzregeln geprüft).
    func targets(for card: CardType, player: PlayerColor) -> [Square] {
        guard card.targeting == .single else { return [] }
        return candidateSquares(for: card, player: player).filter { sq in
            isValidAction(player: player, { state, target in
                state.applyCardEffect(card, player: player, target: target)
            }, target: sq, keepsTurn: card.keepsTurn, lock: bonusLock(for: card, target: sq, player: player))
        }
    }

    func canPlay(_ card: CardType, player: PlayerColor) -> Bool {
        guard !bonusActionUsed, mana[player, default: 0] >= card.cost,
              cooldownRemaining(card, player: player) == 0 else { return false }
        switch card.targeting {
        case .none:
            switch card {
            case .bulwark:
                guard pieces(of: player).contains(where: { $0.1.type == .pawn }) else { return false }
            case .advance:
                guard !advancingPawns(for: player).isEmpty else { return false }
            case .drain:
                guard mana[player.opponent, default: 0] >= 2 else { return false }
            case .focus:
                guard mana[player, default: 0] < GameState.maxMana else { return false }
            default:
                break
            }
            return isValidAction(player: player, { state, target in
                state.applyCardEffect(card, player: player, target: target)
            }, target: nil, keepsTurn: card.keepsTurn)
        case .single:
            return !targets(for: card, player: player).isEmpty
        }
    }

    /// Schutzregeln für Karten und Ultimates: kein Schach geben, eigenen König nicht im Schach lassen,
    /// dem Gegner muss ein legaler Zug bleiben.
    /// Bonusaktionen (Schild, Frost) ändern das Brett nicht – nach ihnen folgt noch ein Figurzug.
    /// Deshalb dürfen sie auch gespielt werden, wenn der eigene König im Schach steht.
    /// Nach Schild muss ein Figurzug mit einer anderen Figur möglich sein (`lock`).
    func isValidAction(player: PlayerColor, _ effect: (inout GameState, Square?) -> Void, target: Square?,
                       keepsTurn: Bool = false, lock: Square? = nil, peaceful: Bool = false) -> Bool {
        var copy = self
        effect(&copy, target)
        if copy.isInCheck(player.opponent) { return false }
        if keepsTurn {
            copy.bonusActionUsed = true
            copy.bonusLockedSquare = lock
            copy.peacefulBonus = peaceful
            guard copy.hasAnyLegalMove(for: player) else { return false }
            copy.bonusActionUsed = false
            copy.bonusLockedSquare = nil
            copy.peacefulBonus = false
            return copy.hasAnyLegalMove(for: player.opponent)
        }
        if copy.isInCheck(player) { return false }
        return copy.hasAnyLegalMove(for: player.opponent)
    }

    /// Karte ausspielen: bezahlen, Abklingzeit starten, Effekt anwenden – danach ist der Gegner am Zug
    /// (bei Bonusaktionen erst nach dem folgenden Figurzug).
    mutating func playCard(_ card: CardType, handIndex: Int, target: Square?) {
        let player = current
        mana[player] = mana[player, default: 0] - card.cost
        decks[player]?.play(at: handIndex)
        if card.cooldown > 0 {
            // Bereit ab dem Halbzug nach `cooldown` übersprungenen eigenen Zügen
            cardCooldowns[player, default: [:]][card] = ply + 2 * card.cooldown + 2
        }
        let lock = bonusLock(for: card, target: target, player: player)
        applyCardEffect(card, player: player, target: target)
        if card.keepsTurn {
            // Bonusaktion: Der Spieler bleibt am Zug und muss noch eine Figur ziehen.
            // Eine mit Schild geschützte Figur (oder der vorgestürmte Bauer) bleibt dabei stehen.
            bonusActionUsed = true
            bonusLockedSquare = lock
        } else {
            passTurn()
        }
    }

    mutating func applyCardEffect(_ card: CardType, player: PlayerColor, target t: Square?) {
        // Zeitliche Effekte gelten bis zum Ende des nächsten gegnerischen Zuges.
        let until = ply + 1
        switch card {
        case .shield:
            if let t, var p = self[t] {
                p.shieldedUntil = until
                self[t] = p
            }
        case .bulwark:
            for sq in GameState.allSquares {
                if var p = self[sq], p.color == player, p.type == .pawn {
                    p.shieldedUntil = until
                    self[sq] = p
                }
            }
        case .freeze:
            if let t, var p = self[t] {
                p.frozenUntil = max(p.frozenUntil, until)
                self[t] = p
            }
        case .lightning:
            if let t, let p = self[t] {
                self[t] = nil
                captured[p.color, default: []].append(p)
                events.append(.destroyed(t))
            }
        case .knighting:
            if let t, var p = self[t] {
                p.type = .knight
                self[t] = p
            }
        case .sprint:
            if let t, var p = self[t] {
                let dest = t.offset(2 * player.forward, 0)
                self[t] = nil
                p.hasMoved = true
                self[dest] = p
                events.append(.moved(dest))
            }
        case .reinforce:
            if let t {
                self[t] = Piece(.pawn, player)
                events.append(.revived(t))
            }
        case .revive:
            if let t, let idx = bestRevivableIndex(for: player, includeQueen: false) {
                var list = captured[player] ?? []
                let old = list.remove(at: idx)
                captured[player] = list
                var revived = Piece(old.type, player)
                revived.hasMoved = true
                self[t] = revived
                events.append(.revived(t))
            }
        case .bishopize:
            if let t, var p = self[t] {
                p.type = .bishop
                self[t] = p
            }
        case .advance:
            for sq in advancingPawns(for: player) {
                let dest = sq.offset(player.forward, 0)
                if var p = self[sq] {
                    p.hasMoved = true
                    self[sq] = nil
                    self[dest] = p
                    events.append(.moved(dest))
                }
            }
        case .swap:
            if let t, let k = kingSquare(player), var piece = self[t], var king = self[k] {
                king.hasMoved = true
                piece.hasMoved = true
                self[t] = king
                self[k] = piece
                events.append(.moved(t))
                events.append(.moved(k))
            }
        case .drain:
            // Der Gegner verliert die Hälfte seines Manas (abgerundet), du erhältst 2
            let opp = player.opponent
            let m = mana[opp, default: 0]
            mana[opp] = m - m / 2
            gainMana(player, GameState.drainGain, .card)
        case .focus:
            gainMana(player, GameState.focusGain, .card)
        case .sacrifice:
            if let t, let p = self[t] {
                self[t] = nil
                captured[p.color, default: []].append(p)
                events.append(.destroyed(t))
                gainMana(player, GameState.sacrificeGain, .card)
            }
        case .retreat:
            if let t, let from = retreatOrigin(for: player, to: t), var p = self[from] {
                self[from] = nil
                p.hasMoved = true
                self[t] = p
                events.append(.moved(t))
            }
        }
    }
}

// MARK: - Ultimates

extension GameState {

    func ultimateTargets(_ player: PlayerColor) -> [Square] {
        guard let u = ultimates[player], u.needsTarget else { return [] }
        let candidates: [Square]
        switch u {
        case .meteor:
            candidates = GameState.allSquares.filter { sq in
                guard let p = self[sq] else { return false }
                return p.color != player && p.type != .king && p.type != .queen
            }
        case .coronation:
            // Mit eigener Dame nur Bauern in der gegnerischen Hälfte, ohne Dame jeder Bauer
            let hasQueen = pieces(of: player).contains(where: { $0.1.type == .queen })
            candidates = GameState.allSquares.filter { sq in
                guard let p = self[sq], p.color == player, p.type == .pawn else { return false }
                return !hasQueen || player.rank(of: sq) >= 5
            }
        default:
            candidates = []
        }
        return candidates.filter { sq in
            isValidAction(player: player, { state, target in
                state.applyUltimate(u, player: player, target: target)
            }, target: sq, keepsTurn: u.keepsTurn)
        }
    }

    func canUseUltimate(_ player: PlayerColor) -> Bool {
        guard !bonusActionUsed, let u = ultimates[player], mana[player, default: 0] >= u.cost else { return false }
        if u.needsTarget { return !ultimateTargets(player).isEmpty }
        if u == .rebirth {
            guard bestRevivableIndex(for: player, includeQueen: true) != nil,
                  rebirthSquare(for: player) != nil else { return false }
        }
        return isValidAction(player: player, { state, target in
            state.applyUltimate(u, player: player, target: target)
        }, target: nil, keepsTurn: u.keepsTurn, peaceful: u == .fortress)
    }

    private func rebirthSquare(for player: PlayerColor) -> Square? {
        let order = [3, 4, 2, 5, 1, 6, 0, 7]
        return order.map { Square(row: player.homeRow, col: $0) }.first { isFree($0) }
    }

    /// Ultimate einsetzen: verbraucht ihre Kosten (8, Festung 6 – was darüber liegt, bleibt) und ersetzt den Zug.
    mutating func useUltimate(target: Square?) {
        let player = current
        guard let u = ultimates[player] else { return }
        mana[player] = max(0, mana[player, default: 0] - u.cost)
        applyUltimate(u, player: player, target: target)
        if u.keepsTurn {
            // Festung: Danach folgt noch ein Figurzug (wie bei Bonuskarten) – ohne Schlagen und ohne Schach
            bonusActionUsed = true
            bonusLockedSquare = nil
            peacefulBonus = u == .fortress
        } else {
            passTurn()
        }
    }

    mutating func applyUltimate(_ u: Ultimate, player: PlayerColor, target: Square?) {
        let until = ply + 1
        switch u {
        case .meteor:
            if let t = target, let p = self[t] {
                self[t] = nil
                captured[p.color, default: []].append(p)
                events.append(.destroyed(t))
                // Einschlag: ungeschützte gegnerische Bauern direkt daneben (ungedeckt, ohne Schild)
                // sind zwei Züge lang betäubt – wie bei der Eiszeit.
                for (dr, dc) in Dir.king {
                    let n = t.offset(dr, dc)
                    if n.isValid, var q = self[n], q.color == p.color, q.type == .pawn, isUnprotected(n) {
                        q.frozenUntil = max(q.frozenUntil, until + 2)
                        self[n] = q
                    }
                }
            }
        case .iceAge:
            // Zwei gegnerische Züge lang (Tauwetter verhindert ein Patt, siehe beginTurn)
            for sq in GameState.allSquares {
                if var p = self[sq], p.color != player, p.type != .king {
                    p.frozenUntil = max(p.frozenUntil, until + 2)
                    self[sq] = p
                }
            }
        case .fortress:
            // Schutz bis zum Ende des nächsten gegnerischen Zuges – danach folgt noch ein eigener Figurzug
            for sq in GameState.allSquares {
                if var p = self[sq], p.color == player, p.type != .king {
                    p.shieldedUntil = until
                    self[sq] = p
                }
            }
        case .coronation:
            if let t = target, var p = self[t] {
                p.type = .queen
                self[t] = p
                events.append(.promotion(t))
            }
        case .rebirth:
            if let idx = bestRevivableIndex(for: player, includeQueen: true), let sq = rebirthSquare(for: player) {
                var list = captured[player] ?? []
                let old = list.remove(at: idx)
                captured[player] = list
                var revived = Piece(old.type, player)
                revived.hasMoved = true
                self[sq] = revived
                events.append(.revived(sq))
            }
        }
    }
}

// MARK: - Taktik-Erkennung

enum Tactic: Equatable {
    case doubleCheck, discoveredCheck, fork(count: Int), skewer, pin

    static let manaBonus = 1

    var title: String {
        switch self {
        case .doubleCheck: return L("DOPPELSCHACH!")
        case .discoveredCheck: return L("ABZUGSSCHACH!")
        case .fork(let n): return n >= 3 ? L("MEGA-GABEL!") : L("GABEL!")
        case .skewer: return L("SPIESS!")
        case .pin: return L("FESSELUNG!")
        }
    }

    var icon: String {
        switch self {
        case .doubleCheck: return "bolt.horizontal.fill"
        case .discoveredCheck: return "eye.fill"
        case .fork: return "arrow.triangle.branch"
        case .skewer: return "arrow.right.to.line"
        case .pin: return "pin.fill"
        }
    }
}

enum TacticDetector {
    /// Prüft die Stellung nach einem Schachzug von `mover` auf eine Taktik.
    static func detect(after s: GameState, move: Move, mover: PlayerColor) -> Tactic? {
        let opp = mover.opponent
        guard let piece = s[move.to] else { return nil }

        // Doppel- oder Abzugsschach
        if let king = s.kingSquare(opp) {
            let checkers = s.pieces(of: mover).filter { s.attackSquares(from: $0.0).contains(king) }.map { $0.0 }
            if checkers.count >= 2 { return .doubleCheck }
            if checkers.count == 1 && checkers[0] != move.to { return .discoveredCheck }
        }

        // Gabel: greift mindestens zwei lohnende Ziele gleichzeitig an
        let targets = s.attackSquares(from: move.to).filter { t in
            guard let p = s[t], p.color == opp else { return false }
            if p.type == .king { return true }
            if p.type.value > piece.type.value + 0.5 { return true }
            return p.type.value >= 3 && !s.isAttacked(t, by: opp)
        }
        if targets.count >= 2 { return .fork(count: targets.count) }

        // Spieß und Fesselung (nur Langschrittfiguren)
        let dirs: [(Int, Int)]
        switch piece.type {
        case .bishop: dirs = Dir.bishop
        case .rook: dirs = Dir.rook
        case .queen: dirs = Dir.rook + Dir.bishop
        default: dirs = []
        }
        for (dr, dc) in dirs {
            var t = move.to.offset(dr, dc)
            var first: Piece? = nil
            while t.isValid {
                if let p = s[t] {
                    if p.color != opp { break }
                    if let a = first {
                        let frontIsBig = a.type == .king || a.type == .queen
                        let backIsWorth = p.type != .king && p.type.value >= 3 && (a.type == .king || p.type.value < a.type.value)
                        if frontIsBig && backIsWorth { return .skewer }
                        if a.type != .king && (p.type == .king || p.type.value > a.type.value + 1) { return .pin }
                        break
                    }
                    first = p
                }
                t = t.offset(dr, dc)
            }
        }
        return nil
    }
}

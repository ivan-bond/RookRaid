import Foundation

// MARK: - Aktionen im Draht-Format (v0.9.26)

/// Jede Aktion einer Partie als kurze Zeichenkette – dasselbe Format wie in den Puzzles und im Regel-Port (JavaScript):
/// - Schachzug: `e2e4`, Umwandlung `e7e8q` (q, r, b, n)
/// - Karte: `card:freeze@f6`, ohne Ziel `card:bulwark`
/// - Ultimate: `ult:meteor@d8`, ohne Ziel `ult:iceAge`
/// So lassen sich Partien speichern, übers Netz schicken und auf dem Server nachprüfen.
extension ReplayAction {
    func wire(ultimate: Ultimate?, in state: GameState? = nil) -> String {
        switch self {
        case .move(let m):
            var code = m.from.name + m.to.name
            if let promo = m.promotion ?? promotionDefault(m, state) { code += promo.wireLetter }
            return code
        case .card(let c, let t):
            return "card:" + c.rawValue + (t.map { "@" + $0.name } ?? "")
        case .ultimate(let t):
            return "ult:" + (ultimate?.rawValue ?? "?") + (t.map { "@" + $0.name } ?? "")
        }
    }

    /// Bauer auf der letzten Reihe ohne gewählte Figur: Dame (wie in der Engine).
    private func promotionDefault(_ m: Move, _ state: GameState?) -> PieceType? {
        guard let state, let p = state[m.from], p.type == .pawn, m.to.row == p.color.promotionRow else { return nil }
        return .queen
    }
}

extension PieceType {
    var wireLetter: String {
        switch self {
        case .queen: return "q"
        case .rook: return "r"
        case .bishop: return "b"
        case .knight: return "n"
        case .king: return "k"
        case .pawn: return "p"
        }
    }

    init?(wireLetter: Character) {
        switch wireLetter {
        case "q": self = .queen
        case "r": self = .rook
        case "b": self = .bishop
        case "n": self = .knight
        default: return nil
        }
    }
}

extension GameState {
    /// Prüft eine Aktion im Draht-Format gegen die Regeln und liefert sie, wenn sie jetzt erlaubt ist.
    func validate(_ code: String) -> ReplayAction? {
        let player = current
        if code.hasPrefix("card:") {
            let body = code.dropFirst(5).split(separator: "@").map(String.init)
            guard let card = CardType(rawValue: body.first ?? ""), canPlay(card, player: player),
                  decks[player]?.hand.contains(card) == true else { return nil }
            let target = body.count > 1 ? Square(name: body[1]) : nil
            if card.targeting == .single {
                guard let target, targets(for: card, player: player).contains(target) else { return nil }
            } else if target != nil {
                return nil
            }
            return .card(card, target)
        }
        if code.hasPrefix("ult:") {
            let body = code.dropFirst(4).split(separator: "@").map(String.init)
            guard let u = ultimates[player], u.rawValue == body.first, canUseUltimate(player) else { return nil }
            let target = body.count > 1 ? Square(name: body[1]) : nil
            if u.needsTarget {
                guard let target, ultimateTargets(player).contains(target) else { return nil }
            } else if target != nil {
                return nil
            }
            return .ultimate(target)
        }
        guard code.count == 4 || code.count == 5,
              let from = Square(name: String(code.prefix(2))),
              let to = Square(name: String(code.dropFirst(2).prefix(2))),
              self[from]?.color == player,
              var move = legalMoves(from: from).first(where: { $0.to == to }) else { return nil }
        if code.count == 5, let letter = code.last {
            guard let promo = PieceType(wireLetter: letter) else { return nil }
            move.promotion = promo
        }
        return .move(move)
    }

    /// Aktion ausführen, wenn sie erlaubt ist. Gibt `false` zurück und ändert nichts, wenn nicht.
    @discardableResult
    mutating func apply(_ code: String) -> Bool {
        guard let action = validate(code) else { return false }
        switch action {
        case .move(let m):
            makeMove(m)
        case .card(let c, let t):
            guard let idx = decks[current]?.hand.firstIndex(of: c) else { return false }
            playCard(c, handIndex: idx, target: t)
        case .ultimate(let t):
            useUltimate(target: t)
        }
        return true
    }

    /// Figurenstellung als FEN-Teil (für Regeltests und Abgleich mit dem Server).
    var placementFEN: String {
        var rows: [String] = []
        for r in 0..<8 {
            var row = ""
            var empty = 0
            for c in 0..<8 {
                if let p = self[Square(row: r, col: c)] {
                    if empty > 0 { row += "\(empty)"; empty = 0 }
                    let l = p.type.wireLetter
                    row += p.color == .white ? l.uppercased() : l
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += "\(empty)" }
            rows.append(row)
        }
        return rows.joined(separator: "/")
    }

    /// Kurzname des Partiestands wie im Regel-Port: ongoing, check, mate, stalemate, fifty, repetition.
    var statusCode: String {
        switch status() {
        case .ongoing: return "ongoing"
        case .check: return "check"
        case .checkmate: return "mate"
        case .stalemate: return "stalemate"
        case .drawFiftyMoves: return "fifty"
        case .drawRepetition: return "repetition"
        case .timeout: return "timeout"
        case .resigned: return "resigned"
        }
    }
}

// MARK: - Partieprotokoll

/// Alles, was man braucht, um eine Partie überall exakt nachzuspielen: Regel-Version, Decks, Ultimates und die Aktionen.
struct MatchRecord: Codable, Equatable {
    var rulesVersion: Int
    /// Decks nach Farbe („white“/„black“) als Karten-Rohwerte
    var decks: [String: [String]]
    var ultimates: [String: String]
    var actions: [String]

    /// Startstellung aus dem Protokoll (Grundstellung mit den Decks und Ultimates).
    func initialState() -> GameState {
        var ults: [PlayerColor: Ultimate] = [:]
        var deckCards: [PlayerColor: [CardType]] = [:]
        for color in PlayerColor.allCases {
            let key = color == .white ? "white" : "black"
            if let raw = ultimates[key], let u = Ultimate(rawValue: raw) { ults[color] = u }
            if let raw = decks[key] { deckCards[color] = raw.compactMap(CardType.init(rawValue:)) }
        }
        return GameState.initial(ultimates: ults, decks: deckCards)
    }

    /// Nachspielen. `failedAt` ist der Index der ersten ungültigen Aktion (nil = alles gültig).
    func replay() -> (state: GameState, failedAt: Int?) {
        var s = initialState()
        for (i, code) in actions.enumerated() where !s.apply(code) {
            return (s, i)
        }
        return (s, nil)
    }
}

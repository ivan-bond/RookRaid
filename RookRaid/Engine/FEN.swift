import Foundation

extension Square {
    /// Feld aus Schachnotation, z. B. "e4".
    init?(name: String) {
        let chars = Array(name)
        guard chars.count == 2,
              let file = Square.files.firstIndex(of: String(chars[0])),
              let rank = Int(String(chars[1])), (1...8).contains(rank) else { return nil }
        self.init(row: 8 - rank, col: file)
    }
}

extension Move {
    /// UCI-Schreibweise, z. B. "e2e4" oder "c7c8q" (Umwandlung ist im Prototyp immer eine Dame).
    func uci(in state: GameState) -> String {
        var text = from.name + to.name
        if let p = state[from], p.type == .pawn, to.row == p.color.promotionRow {
            switch promotion ?? .queen {
            case .rook: text += "r"
            case .bishop: text += "b"
            case .knight: text += "n"
            default: text += "q"
            }
        }
        return text
    }
}

extension GameState {
    /// Stellung aus einer FEN-Zeichenkette (für Puzzles). Ohne Karten, Ultimates und Mana.
    static func fromFEN(_ fen: String) -> GameState? {
        let parts = fen.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }
        let rows = parts[0].split(separator: "/").map(String.init)
        guard rows.count == 8 else { return nil }

        var board = Array(repeating: [Piece?](repeating: nil, count: 8), count: 8)
        for (r, row) in rows.enumerated() {
            var c = 0
            for ch in row {
                if let n = ch.wholeNumberValue {
                    c += n
                    continue
                }
                guard c < 8 else { return nil }
                let color: PlayerColor = ch.isUppercase ? .white : .black
                let type: PieceType
                switch ch.lowercased() {
                case "p": type = .pawn
                case "n": type = .knight
                case "b": type = .bishop
                case "r": type = .rook
                case "q": type = .queen
                case "k": type = .king
                default: return nil
                }
                var piece = Piece(type, color)
                // Bauern auf der Grundreihe dürfen noch doppelt ziehen, alle anderen gelten als bewegt.
                piece.hasMoved = type == .pawn ? r != color.pawnStartRow : true
                board[r][c] = piece
                c += 1
            }
        }

        // Rochaderechte: König und betroffene Türme gelten als unbewegt.
        let castling = parts.count > 2 ? parts[2] : "-"
        for color in PlayerColor.allCases {
            let r = color.homeRow
            let short: Character = color == .white ? "K" : "k"
            let long: Character = color == .white ? "Q" : "q"
            let hasShort = castling.contains(short)
            let hasLong = castling.contains(long)
            if (hasShort || hasLong), board[r][4]?.type == .king { board[r][4]?.hasMoved = false }
            if hasShort, board[r][7]?.type == .rook { board[r][7]?.hasMoved = false }
            if hasLong, board[r][0]?.type == .rook { board[r][0]?.hasMoved = false }
        }

        var state = GameState(board: board)
        state.ply = parts[1] == "b" ? 1 : 0
        if parts.count > 3, parts[3] != "-" { state.enPassantTarget = Square(name: parts[3]) }
        state.mana = [.white: 0, .black: 0]
        return state
    }

    /// Findet den legalen Zug zu einer UCI-Angabe.
    func move(fromUCI text: String) -> Move? {
        guard text.count >= 4,
              let from = Square(name: String(text.prefix(2))),
              let to = Square(name: String(text.dropFirst(2).prefix(2))) else { return nil }
        guard var move = legalMoves(from: from).first(where: { $0.to == to }) else { return nil }
        if text.count == 5 {
            switch text.last {
            case "r": move.promotion = .rook
            case "b": move.promotion = .bishop
            case "n": move.promotion = .knight
            default: break
            }
        }
        return move
    }
}

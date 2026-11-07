import Foundation

// MARK: - Spieler

enum PlayerColor: String, Codable, CaseIterable, Hashable {
    case white, black

    var opponent: PlayerColor { self == .white ? .black : .white }
    /// Zeilenrichtung „vorwärts“ (Zeile 0 = Reihe 8 oben, Zeile 7 = Reihe 1 unten).
    var forward: Int { self == .white ? -1 : 1 }
    var homeRow: Int { self == .white ? 7 : 0 }
    /// Liegt das Feld in der eigenen Brett-Hälfte (Weiß: Reihen 1–4, Schwarz: Reihen 5–8)?
    func ownsHalf(_ sq: Square) -> Bool { self == .white ? sq.row >= 4 : sq.row <= 3 }
    var pawnStartRow: Int { self == .white ? 6 : 1 }
    var promotionRow: Int { self == .white ? 0 : 7 }
    var displayName: String { self == .white ? L("Weiß") : L("Schwarz") }

    /// Reihe aus Sicht dieses Spielers (1 = eigene Grundreihe, 8 = gegnerische Grundreihe).
    func rank(of sq: Square) -> Int { self == .white ? 8 - sq.row : sq.row + 1 }
}

// MARK: - Figuren

enum PieceType: String, Codable, CaseIterable {
    case king, queen, rook, bishop, knight, pawn

    /// Materialwert (für KI und Anzeige).
    var value: Double {
        switch self {
        case .king: return 0
        case .queen: return 9
        case .rook: return 5
        case .bishop: return 3.2
        case .knight: return 3
        case .pawn: return 1
        }
    }

    /// Ganzzahliger Wert für die Materialanzeige (+2 usw.).
    var points: Int {
        switch self {
        case .king: return 0
        case .queen: return 9
        case .rook: return 5
        case .bishop, .knight: return 3
        case .pawn: return 1
        }
    }

    /// Deutsche Notation (K, D, T, L, S).
    var letter: String {
        switch self {
        case .king: return "K"
        case .queen: return "D"
        case .rook: return "T"
        case .bishop: return "L"
        case .knight: return "S"
        case .pawn: return ""
        }
    }

    var assetLetter: String {
        switch self {
        case .king: return "K"
        case .queen: return "Q"
        case .rook: return "R"
        case .bishop: return "B"
        case .knight: return "N"
        case .pawn: return "P"
        }
    }

    var displayName: String {
        switch self {
        case .king: return L("König")
        case .queen: return L("Dame")
        case .rook: return L("Turm")
        case .bishop: return L("Läufer")
        case .knight: return L("Springer")
        case .pawn: return L("Bauer")
        }
    }
}

struct Piece: Identifiable, Codable, Equatable {
    var id: UUID
    var type: PieceType
    var color: PlayerColor
    var hasMoved: Bool = false

    // Zeitlich begrenzte Effekte – jeweils der letzte Halbzug (ply), in dem sie gelten.
    var shieldedUntil: Int = -1
    var frozenUntil: Int = -1

    init(_ type: PieceType, _ color: PlayerColor) {
        self.id = UUID()
        self.type = type
        self.color = color
    }

    func isShielded(at ply: Int) -> Bool { shieldedUntil >= ply }
    func isFrozen(at ply: Int) -> Bool { frozenUntil >= ply }
}

// MARK: - Brett

struct Square: Hashable, Codable {
    var row: Int
    var col: Int

    var isValid: Bool { (0..<8).contains(row) && (0..<8).contains(col) }
    func offset(_ dr: Int, _ dc: Int) -> Square { Square(row: row + dr, col: col + dc) }
    var isLight: Bool { (row + col) % 2 == 0 }
    var index: Int { row * 8 + col }

    static let files = ["a", "b", "c", "d", "e", "f", "g", "h"]
    var name: String { "\(Square.files[col])\(8 - row)" }
}

struct Move: Equatable, Codable {
    var from: Square
    var to: Square
    var isEnPassant: Bool = false
    var castleRookFrom: Square? = nil
    var castleRookTo: Square? = nil
    var isDoublePawnStep: Bool = false
    /// Gewählte Figur bei der Umwandlung (nil = Dame).
    var promotion: PieceType? = nil
}

enum GameStatus: Codable, Equatable {
    case ongoing
    case check
    case checkmate(winner: PlayerColor)
    case stalemate
    case timeout(winner: PlayerColor)
    case resigned(winner: PlayerColor)
    /// Remis durch dreifache Stellungswiederholung.
    case drawRepetition
    /// Remis durch die 50-Züge-Regel.
    case drawFiftyMoves

    var isOver: Bool {
        switch self {
        case .ongoing, .check: return false
        default: return true
        }
    }

    var winner: PlayerColor? {
        switch self {
        case .checkmate(let w), .timeout(let w), .resigned(let w): return w
        default: return nil
        }
    }

    var reason: String {
        switch self {
        case .checkmate: return L("durch Schachmatt")
        case .stalemate: return L("durch Patt")
        case .timeout: return L("durch Zeitüberschreitung")
        case .resigned: return L("durch Aufgabe")
        case .drawRepetition: return L("durch dreifache Stellungswiederholung")
        case .drawFiftyMoves: return L("durch die 50-Züge-Regel")
        case .ongoing, .check: return ""
        }
    }

    /// Derselbe Text unübersetzt – so steht er im Verlauf (App und Browser gleich).
    var reasonKey: String {
        switch self {
        case .checkmate: return "durch Schachmatt"
        case .stalemate: return "durch Patt"
        case .timeout: return "durch Zeitüberschreitung"
        case .resigned: return "durch Aufgabe"
        case .drawRepetition: return "durch dreifache Stellungswiederholung"
        case .drawFiftyMoves: return "durch die 50-Züge-Regel"
        case .ongoing, .check: return ""
        }
    }
}

/// Warum Mana gutgeschrieben wurde (für die Anzeige an der Mana-Leiste).
enum ManaReason: String, Codable {
    /// `territory` bleibt nur, damit alte Spielstände lesbar sind (bis v0.9.19 gab es Mana aus dem Gebiet).
    case turn, territory, capture, check, tactic, card

    var label: String {
        switch self {
        case .turn: return L("Zug")
        case .territory: return L("Gebiet")
        case .capture: return L("Schlag")
        case .check: return L("Schach")
        case .tactic: return L("Taktik")
        case .card: return L("Karte")
        }
    }
}

/// Ereignisse, die die Engine meldet – die Oberfläche macht daraus Effekte, Sound und Haptik.
enum GameEvent: Codable, Equatable {
    case moved(Square)
    case capture(Square, PieceType, by: PlayerColor)
    case destroyed(Square)
    case promotion(Square)
    case castle(Square)
    case revived(Square)
    case mana(PlayerColor, Int, ManaReason)
}

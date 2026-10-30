import Foundation

/// Regeltests (v0.9.26): dieselben Fälle wie im JavaScript-Regel-Port (`Tools/rules-js`), Erwartungen aus
/// `rookraid-golden.json`. Stimmen Swift und JavaScript überein, kann der Server später jeden Zug genauso prüfen.
/// Aufruf in Debug-Builds unter Einstellungen → Regeltests.
enum RulesSelfTest {
    struct Expect: Codable, Equatable {
        struct Mana: Codable, Equatable { var w: Int; var b: Int }
        var placement: String
        var side: String
        var mana: Mana
        var status: String
        var rejectedAt: Int?
    }

    struct Case: Codable {
        struct Sides<T: Codable>: Codable { var w: T?; var b: T? }
        var name: String
        /// Stellung als FEN – oder `start: "initial"` mit `decks` und `ults`: Grundstellung wie in einer echten Partie (v0.9.34)
        var fen: String?
        var start: String?
        var decks: Sides<[String]>?
        var mana: Sides<Int>?
        var hand: Sides<[String]>?
        var ults: Sides<String>?
        var captured: Sides<[String]>?
        var actions: [String]
        var expect: Expect
    }

    struct File: Codable {
        var rulesVersion: Int
        var cases: [Case]
    }

    struct Result: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let detail: String
    }

    static func loadFile() -> File? {
        guard let url = Bundle.main.url(forResource: "rookraid-golden", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }

    static func run() -> [Result] {
        guard let file = loadFile() else {
            return [Result(name: "rookraid-golden.json", passed: false, detail: "Datei fehlt oder ist ungültig")]
        }
        var results: [Result] = []
        if file.rulesVersion != RulesConfig.current.version {
            results.append(Result(name: "Regel-Version", passed: false,
                                  detail: "Tests für v\(file.rulesVersion), App nutzt v\(RulesConfig.current.version)"))
        }
        for c in file.cases {
            results.append(check(c))
        }
        return results
    }

    private static func pieceType(_ s: String) -> PieceType? {
        switch s {
        case "p": return .pawn
        case "n": return .knight
        case "b": return .bishop
        case "r": return .rook
        case "q": return .queen
        case "k": return .king
        default: return nil
        }
    }

    static func check(_ c: Case) -> Result {
        guard var s = start(for: c) else { return Result(name: c.name, passed: false, detail: "FEN ungültig") }
        if c.start != "initial" { setUp(&s, c) }
        return compare(c, &s)
    }

    /// Ganze Partie aus der Grundstellung (dieselbe Funktion wie MatchRecord.initialState) oder Stellung aus der FEN.
    private static func start(for c: Case) -> GameState? {
        if c.start == "initial" {
            var ults: [PlayerColor: Ultimate] = [:]
            if let u = c.ults?.w.flatMap(Ultimate.init(rawValue:)) { ults[.white] = u }
            if let u = c.ults?.b.flatMap(Ultimate.init(rawValue:)) { ults[.black] = u }
            let decks: [PlayerColor: [CardType]] = [
                .white: (c.decks?.w ?? []).compactMap(CardType.init(rawValue:)),
                .black: (c.decks?.b ?? []).compactMap(CardType.init(rawValue:))
            ]
            return GameState.initial(ultimates: ults, decks: decks)
        }
        guard let fen = c.fen else { return nil }
        return GameState.fromFEN(fen)
    }

    private static func setUp(_ s: inout GameState, _ c: Case) {
        s.mana[.white] = c.mana?.w ?? 0
        s.mana[.black] = c.mana?.b ?? 0
        s.decks[.white] = PlayerDeck(hand: (c.hand?.w ?? []).compactMap(CardType.init(rawValue:)), queue: [])
        s.decks[.black] = PlayerDeck(hand: (c.hand?.b ?? []).compactMap(CardType.init(rawValue:)), queue: [])
        if let u = c.ults?.w.flatMap(Ultimate.init(rawValue:)) { s.ultimates[.white] = u }
        if let u = c.ults?.b.flatMap(Ultimate.init(rawValue:)) { s.ultimates[.black] = u }
        s.captured[.white] = (c.captured?.w ?? []).compactMap(pieceType).map { Piece($0, .white) }
        s.captured[.black] = (c.captured?.b ?? []).compactMap(pieceType).map { Piece($0, .black) }
    }

    private static func compare(_ c: Case, _ s: inout GameState) -> Result {
        var rejectedAt: Int?
        for (i, code) in c.actions.enumerated() where !s.apply(code) {
            rejectedAt = i
            break
        }
        let got = Expect(placement: s.placementFEN, side: s.current == .white ? "white" : "black",
                         mana: .init(w: s.mana[.white, default: 0], b: s.mana[.black, default: 0]),
                         status: s.statusCode, rejectedAt: rejectedAt)
        if got == c.expect { return Result(name: c.name, passed: true, detail: "") }
        var diff: [String] = []
        if got.rejectedAt != c.expect.rejectedAt {
            diff.append("abgelehnt bei \(got.rejectedAt.map(String.init) ?? "–") statt \(c.expect.rejectedAt.map(String.init) ?? "–")")
        }
        if got.placement != c.expect.placement { diff.append("Stellung \(got.placement) statt \(c.expect.placement)") }
        if got.side != c.expect.side { diff.append("am Zug \(got.side) statt \(c.expect.side)") }
        if got.mana != c.expect.mana { diff.append("Mana \(got.mana.w)/\(got.mana.b) statt \(c.expect.mana.w)/\(c.expect.mana.b)") }
        if got.status != c.expect.status { diff.append("Status \(got.status) statt \(c.expect.status)") }
        return Result(name: c.name, passed: false, detail: diff.joined(separator: " · "))
    }
}

import Foundation
import Supabase

/// Ob online gespielt werden darf (Schritt 10). Lokale Partien bleiben immer möglich.
enum OnlineRulesLock: Equatable {
    case open
    /// Server hat eine neuere Fassung mit einer Karte, die diese App nicht kennt.
    case updateAvailable
    /// Diese App ist neuer als jede aktive Server-Fassung.
    case serverBehind

    var title: String? {
        switch self {
        case .open: return nil
        case .updateAvailable: return L("Update verfügbar")
        case .serverBehind: return L("Online gerade nicht verfügbar")
        }
    }

    var detail: String? {
        switch self {
        case .open: return nil
        case .updateAvailable: return L("Bitte aktualisiere Rook Raid, um online zu spielen.")
        case .serverBehind: return L("Diese Fassung ist neuer als der Server. Online geht wieder, sobald der Server nachgezogen hat.")
        }
    }
}

/// Beim Start `active_rules()` holen und mit `RulesConfig.current` vergleichen.
/// Höhere Server-Fassung mit bekannten Karten wird übernommen – nicht während einer laufenden Partie.
/// Eine unbekannte Karte sperrt online („Update verfügbar“), außer die eigene Version ist noch aktiv
/// (Übergang, alte Versionen bleiben aktiv). Ist die App neuer als der Server, bleibt online zu.
@MainActor
final class OnlineRules: ObservableObject {
    static let shared = OnlineRules()

    @Published private(set) var lock: OnlineRulesLock = .open
    /// Neuere bekannte Fassung, die erst nach der laufenden Partie gilt.
    private var pending: RulesConfig?
    private var chain: Task<Void, Never>?

    private init() {}

    /// Fragt den Server. `deferAdopt` lässt die geltenden Regeln stehen (laufende oder gespeicherte Partie).
    func refresh(deferAdopt: Bool) async {
        let previous = chain
        let next = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await self.load(deferAdopt: deferAdopt)
        }
        chain = next
        await next.value
    }

    /// Übernimmt eine aufgeschobene Fassung, sobald keine Partie mehr davon abhängt.
    func applyPending(deferAdopt: Bool) {
        guard !deferAdopt, let config = pending else { return }
        RulesConfig.adopt(config)
        pending = nil
        lock = .open
    }

    private func load(deferAdopt: Bool) async {
        guard OnlineConfig.isLive, let client = Backend.client else {
            lock = .open
            pending = nil
            return
        }
        let fetched: Fetch
        do {
            fetched = try await Self.fetch(client)
        } catch {
            return
        }
        switch fetched {
        case .unreadable:
            return
        case .none:
            pending = nil
            lock = .serverBehind
            return
        case .rules(let rows):
            guard let newest = rows.max(by: { $0.version < $1.version }) else {
                pending = nil
                lock = .serverBehind
                return
            }
            await apply(newest: newest, client: client, deferAdopt: deferAdopt)
        }
    }

    private func apply(newest: (version: Int, config: RulesConfig?), client: SupabaseClient, deferAdopt: Bool) async {
        let local = RulesConfig.current.version
        let server = max(newest.version, newest.config?.version ?? 0)
        if server == local {
            pending = nil
            lock = .open
            return
        }
        if server > local {
            if let config = newest.config, config.version > local, config.isKnownToThisApp {
                if deferAdopt {
                    pending = config
                } else {
                    RulesConfig.adopt(config)
                    pending = nil
                }
                lock = .open
                return
            }
            // Neue Karte oder unlesbare Fassung. Solange die eigene Version noch aktiv ist, weiter damit spielen.
            let still = (try? await Self.versionIsActive(client, local)) ?? true
            pending = nil
            lock = still ? .open : .updateAvailable
            return
        }
        pending = nil
        lock = .serverBehind
    }

    private enum Fetch {
        case unreadable
        case none
        case rules([(version: Int, config: RulesConfig?)])
    }

    private static func fetch(_ client: SupabaseClient) async throws -> Fetch {
        let response: PostgrestResponse<Void> = try await client.rpc(OnlineConfig.Endpoint.activeRules).execute()
        guard let rows = parse(response.data) else { return .unreadable }
        return rows.isEmpty ? .none : .rules(rows)
    }

    /// `nil`, wenn die Antwort kein Regel-JSON ist (dann bleibt die letzte Entscheidung stehen).
    private static func parse(_ data: Data) -> [(version: Int, config: RulesConfig?)]? {
        guard let json = jsonObject(data) else { return nil }
        guard let array = json as? [Any] else { return nil }
        return array.compactMap { item in
            guard let dict = item as? [String: Any], let version = int(dict["version"]) else { return nil }
            return (version: version, config: config(dict["config"]))
        }
    }

    private static func jsonObject(_ data: Data) -> Any? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        if let text = json as? String, let inner = text.data(using: .utf8) {
            return try? JSONSerialization.jsonObject(with: inner)
        }
        return json
    }

    private static func config(_ raw: Any?) -> RulesConfig? {
        let data: Data?
        if let dict = raw as? [String: Any] {
            data = try? JSONSerialization.data(withJSONObject: dict)
        } else if let text = raw as? String {
            data = text.data(using: .utf8)
        } else {
            data = nil
        }
        guard let data else { return nil }
        return try? JSONDecoder().decode(RulesConfig.self, from: data)
    }

    private static func int(_ value: Any?) -> Int? {
        switch value {
        case let n as Int: return n
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s)
        default: return nil
        }
    }

    private static func versionIsActive(_ client: SupabaseClient, _ version: Int) async throws -> Bool {
        struct Row: Decodable { let version: Int }
        let rows: [Row] = try await client.from("rules_config")
            .select("version")
            .eq("version", value: version)
            .eq("active", value: true)
            .limit(1)
            .execute().value
        return !rows.isEmpty
    }
}

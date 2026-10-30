import Foundation

// MARK: - Sprachen
//
// Eigenes Übersetzungssystem: Schlüssel ist der deutsche Text, die Übersetzungen liegen als JSON im Bundle
// (Localization/en.json usw.). Platzhalter {0}, {1} … erlauben eine andere Wortstellung je Sprache.
// Fehlt eine Übersetzung, erscheint der deutsche Text. Die Sprache lässt sich in den Einstellungen wechseln;
// beim ersten Start gilt die Systemsprache (sonst Englisch).

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case de, en, fr, es, it, zh, ru
    var id: String { rawValue }

    /// Name in der eigenen Sprache (für die Auswahl)
    var nativeName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        case .fr: return "Français"
        case .es: return "Español"
        case .it: return "Italiano"
        case .zh: return "中文"
        case .ru: return "Русский"
        }
    }

    var flag: String {
        switch self {
        case .de: return "🇩🇪"
        case .en: return "🇬🇧"
        case .fr: return "🇫🇷"
        case .es: return "🇪🇸"
        case .it: return "🇮🇹"
        case .zh: return "🇨🇳"
        case .ru: return "🇷🇺"
        }
    }

    var locale: Locale { Locale(identifier: rawValue == "zh" ? "zh-Hans" : rawValue) }

    /// Sprache des Geräts, falls unterstützt – sonst Englisch.
    static var system: AppLanguage {
        for id in Locale.preferredLanguages {
            let code = String(id.prefix(2)).lowercased()
            if let lang = AppLanguage(rawValue: code) { return lang }
        }
        return .en
    }
}

final class Localizer {
    static let shared = Localizer()

    private(set) var language: AppLanguage = .de
    private var table: [String: String] = [:]
    private let lock = NSLock()

    private init() {}

    func set(_ lang: AppLanguage) {
        lock.lock()
        defer { lock.unlock() }
        guard lang != language || table.isEmpty else { return }
        language = lang
        table = [:]
        guard lang != .de,
              let url = Bundle.main.url(forResource: lang.rawValue, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        table = dict
    }

    func lookup(_ key: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return table[key] ?? key
    }
}

/// Übersetzt einen deutschen Text in die gewählte Sprache.
func L(_ key: String) -> String {
    Localizer.shared.lookup(key)
}

/// Übersetzt und setzt Werte für {0}, {1} … ein.
func L(_ key: String, _ args: Any...) -> String {
    var s = Localizer.shared.lookup(key)
    for (i, a) in args.enumerated() {
        s = s.replacingOccurrences(of: "{\(i)}", with: "\(a)")
    }
    return s
}

extension ProfileStore {
    /// Gegnername aus dem Verlauf (dort deutsch gespeichert) in der gewählten Sprache.
    nonisolated static func displayOpponent(_ stored: String) -> String {
        if stored == "Zu zweit" { return L("Zu zweit") }
        if let level = BotLevel.allCases.first(where: { $0.botName == stored }) { return "Bot " + level.displayName }
        return stored
    }
}

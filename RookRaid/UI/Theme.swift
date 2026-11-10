import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Rook Raid: Farben aus dem Logo – tiefes Marineblau als Grund, Blau (du) gegen Rot (Gegner),
/// Kartencreme, Gold für die Ultimate und Violett für Mana.
enum Theme {
    static let background = Color(hex: 0x0F1A2E)
    static let backgroundDeep = Color(hex: 0x0A1424)
    static let panel = Color(hex: 0x0C1628)
    static let panelRaised = Color(hex: 0x18263F)
    static let panelHighlight = Color(hex: 0x27395B)
    static let textPrimary = Color(hex: 0xFFF4DC)
    static let textSecondary = Color(hex: 0xA9B4C8)
    static let textMuted = Color(hex: 0x7E8AA3)
    static let cream = Color(hex: 0xFFF4DC)
    static let navy = Color(hex: 0x0B1B33)

    /// Blau – eigene Seite und Primäraktionen.
    static let blue = Color(hex: 0x2F6FE4)
    static let blueDark = Color(hex: 0x1C3F86)
    static let blueLight = Color(hex: 0x6E9BF0)
    /// Rot – Gegner und Warnungen.
    static let red = Color(hex: 0xE0413A)
    static let redLight = Color(hex: 0xF07A72)

    /// Frühere Primärfarbe – zeigt jetzt auf Blau, damit alle Stellen das neue Design übernehmen.
    static let green = blue
    static let greenDark = blueDark

    static let gold = Color(hex: 0xF2C14E)
    static let mana = Color(hex: 0x8B5CF6)
    static let manaLight = Color(hex: 0xB9A2FF)
    static let manaDark = Color(hex: 0x5B37C2)
    static let manaText = Color(hex: 0x12082A)

    static let clockActive = Color(hex: 0xFFF4DC)
    static let clockInactive = Color(hex: 0x18263F)
}

/// Brettfarben inklusive Gebiet als Farbton (Variante 1e):
/// Felder des eigenen Gebiets werden heller und frischer, gegnerische etwas gedeckter und wärmer.
struct BoardColors {
    let light: Color
    let dark: Color
    let lightMine: Color
    let darkMine: Color
    let lightTheirs: Color
    let darkTheirs: Color

    func color(light isLight: Bool, mine: Bool?) -> Color {
        switch mine {
        case .some(true): return isLight ? lightMine : darkMine
        case .some(false): return isLight ? lightTheirs : darkTheirs
        case .none: return isLight ? light : dark
        }
    }

    /// Mischt zwei Hex-Farben (t = 0 → a, t = 1 → b).
    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func ch(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        let r = ch(a, 16) + (ch(b, 16) - ch(a, 16)) * t
        let g = ch(a, 8) + (ch(b, 8) - ch(a, 8)) * t
        let bl = ch(a, 0) + (ch(b, 0) - ch(a, 0)) * t
        return Color(.sRGB, red: r, green: g, blue: bl, opacity: 1)
    }

    /// Leitet die Gebietsfarben aus den beiden Grundfarben ab.
    static func derived(light: UInt32, dark: UInt32) -> BoardColors {
        BoardColors(light: Color(hex: light), dark: Color(hex: dark),
                    lightMine: mix(light, 0xFFFFFF, 0.6), darkMine: mix(dark, 0xFFFFFF, 0.2),
                    lightTheirs: mix(light, 0x8C2620, 0.12), darkTheirs: mix(dark, 0x3A1A2A, 0.25))
    }

    static func forTheme(_ theme: BoardTheme) -> BoardColors {
        switch theme {
        case .green:
            // Standardbrett „Rook Raid“: Creme und Taubenblau. Eigenes Gebiet heller und blauer,
            // gegnerisches gedeckter und wärmer (rötlich) – passend zu den Logofarben.
            return BoardColors(light: Color(hex: 0xF1E8D4), dark: Color(hex: 0x6F87B0),
                               lightMine: Color(hex: 0xF8F3E8), darkMine: Color(hex: 0x88A3CF),
                               lightTheirs: Color(hex: 0xE8D2C8), darkTheirs: Color(hex: 0x76708F))
        case .brown:
            return derived(light: 0xF0D9B5, dark: 0xB58863)
        case .blue:
            return derived(light: 0xEAE9D2, dark: 0x4B7399)
        case .purple:
            return derived(light: 0xEFEFEF, dark: 0x8877B7)
        case .lava:
            return derived(light: 0xF6DCC8, dark: 0xB4513A)
        case .emerald:
            return derived(light: 0xE4F0DE, dark: 0x3E8A62)
        case .midnight:
            return derived(light: 0xC9D2E6, dark: 0x34406A)
        }
    }
}

/// Bewusst reduzierte Farbwelt: Karten neutral, Ultimate gold, Mana violett.
enum CardStyle {
    static let face = Color(hex: 0x1E2E4C)
    static let faceTop = Color(hex: 0x27395B)
    static let border = Color(hex: 0x34486F)
    static let ultimateTop = Color(hex: 0xFFE08A)
    static let ultimate = Color(hex: 0xF2C14E)
    static let ultimateDeep = Color(hex: 0xB8892B)
}

// MARK: - Buttons

/// Großer „3D“-Button mit dunklerer Unterkante.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.green
    var shadow: Color = Theme.greenDark
    var height: CGFloat = 58
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .heavy, design: .rounded))
            .foregroundColor(textColor)
            .shadow(color: .black.opacity(0.25), radius: 0, y: 1)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(shadow).offset(y: configuration.isPressed ? 1 : 4)
                    RoundedRectangle(cornerRadius: 12).fill(color).offset(y: configuration.isPressed ? 1 : 0)
                }
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(Theme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(configuration.isPressed ? Theme.panelHighlight : Theme.panelRaised)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Theme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Figur als Bild aus dem Asset-Katalog.
struct PieceImage: View {
    let type: PieceType
    let color: PlayerColor
    /// Figurenset eines Bots (helle Variante für Weiß, dunkle für Schwarz); nil = Standardfiguren
    var skin: BotLevel? = nil
    var body: some View {
        Image(skin.map { "skin-\($0.rawValue)-" + (color == .white ? "w" : "b") + type.assetLetter }
              ?? (color == .white ? "w" : "b") + type.assetLetter)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
    }
}

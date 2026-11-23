import SwiftUI

// MARK: - Design system (menu redesign V2 · list style)
//
// One set of tokens and components for the four main tabs (Puzzles · Play · Deck · Profile).
// Rules: exactly one gold-filled button per screen (the main action); everything else is a list row,
// a secondary button or a text link. Colours carry meaning: purple = mana/XP, orange = flame,
// blue = shards/shop, green = done, gold = main action, trophies and ultimates.
// The web version uses the same values (web/src/screens.css, section "Design system").

enum DS {
    // Surfaces
    static let bg = Color(hex: 0x0F1726)
    static let group = Color(hex: 0x162034)
    static let divider = Color(hex: 0x1E2A40)
    static let iconTile = Color(hex: 0x22314F)

    // Text
    static let text = Color(hex: 0xFFF4DC)
    static let textMuted = Color(hex: 0x9AA6BF)
    static let sectionLabel = Color(hex: 0x7F8BA5)
    static let chevron = Color(hex: 0x5F6B85)

    // Meaning
    static let gold = Color(hex: 0xF2C14E)
    static let goldEdge = Color(hex: 0xB8892A)
    static let goldLabel = Color(hex: 0x1A1405)
    static let purple = Color(hex: 0xA78BFA)
    static let flame = Color(hex: 0xFF8A3D)
    static let gem = Color(hex: 0x5CC8FF)
    static let green = Color(hex: 0x4ADE80)

    // Tab bar
    static let tabBar = Color(hex: 0x121A2B)
    static let tabPill = Color(hex: 0x3D6FE0)
    static let tabUnderline = Color(hex: 0x4F80F0)
    static let tabInactive = Color(hex: 0x8B93A7)

    // Metrics
    static let side: CGFloat = 16
    static let groupRadius: CGFloat = 16
    static let tileRadius: CGFloat = 10
    static let rowHeight: CGFloat = 64
    static let compactRowHeight: CGFloat = 52

    // Type: headings and numbers rounded heavy (Nunito-like), body in the system font
    static func heading(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static let screenTitle = heading(30)
    static let rowTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let rowSubtitle = Font.system(size: 14)
    static let number = heading(18)
}

// MARK: Section label

/// Small caps label above a group ("MORE WAYS TO TRAIN").
struct SectionLabel: View {
    let text: String
    var trailing: String? = nil
    var trailingColor: Color = DS.purple
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    init(_ text: String, trailing: String? = nil, trailingColor: Color = DS.purple,
         actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.text = text
        self.trailing = trailing
        self.trailingColor = trailingColor
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(1.4)
                .foregroundColor(DS.sectionLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(trailingColor)
                    .lineLimit(1)
            }
            if let action, let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(DS.text)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.side)
    }
}

// MARK: Resource pills

/// Capsule with an icon and a number (flame, shards, trophies).
struct ResourcePill<Icon: View>: View {
    let value: String
    var onArt = false
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        HStack(spacing: 4) {
            icon()
                .frame(width: 21, height: 21)
            Text(value)
                .font(DS.number)
                .monospacedDigit()
                .foregroundColor(DS.text)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 40)
        .background(Capsule().fill(onArt ? Color(red: 11 / 255, green: 18 / 255, blue: 32 / 255).opacity(0.7) : DS.group))
        .overlay(Capsule().strokeBorder(onArt ? Color.clear : DS.iconTile, lineWidth: 1))
        .contentShape(Capsule())
    }
}

/// The three pills every tab shows on the right: flame streak · shards (opens the shop) · trophies (trophy road).
/// The sheets are presented by RootView (one presenter for the whole app): a page that presents its own sheet
/// can silently fail when it is not the page on screen.
struct ResourcePills: View {
    @ObservedObject private var store = ProfileStore.shared
    var onArt = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                Haptics.shared.play(.select)
                NotificationCenter.default.post(name: .showFlame, object: nil)
            } label: {
                ResourcePill(value: "\(store.currentStreak)", onArt: onArt) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(store.flameLitToday ? DS.flame : FlameStyle.off)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Flamme, {0} Tage in Folge", store.currentStreak))
            .accessibilityAddTraits(.isButton)

            Button {
                Haptics.shared.play(.select)
                NotificationCenter.default.post(name: .showShardShop, object: nil)
            } label: {
                ResourcePill(value: ShardPill.short(store.profile.shards), onArt: onArt) {
                    Image(systemName: "bag")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(DS.gem)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Laden, {0} Splitter", store.profile.shards))
            .accessibilityAddTraits(.isButton)

            Button {
                Haptics.shared.play(.select)
                NotificationCenter.default.post(name: .showTrophyRoad, object: nil)
            } label: {
                ResourcePill(value: "\(store.profile.trophies)", onArt: onArt) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(DS.gold)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("Trophäenpfad, {0} Trophäen", store.profile.trophies))
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: Screen header

/// Same header on every tab: title left, resource pills right, optional settings gear.
/// On narrow screens the title shrinks first; numbers are never truncated.
struct ScreenHeader<Accessory: View>: View {
    let title: String
    var showsGear = false
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(DS.screenTitle)
                .foregroundColor(DS.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
                .layoutPriority(-1)
            accessory()
            Spacer(minLength: 4)
            ResourcePills()
            if showsGear {
                Button {
                    Haptics.shared.play(.select)
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 21, weight: .regular))
                        .foregroundColor(DS.text)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Einstellungen"))
            }
        }
        .padding(.horizontal, DS.side)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

extension ScreenHeader where Accessory == EmptyView {
    init(title: String, showsGear: Bool = false) {
        self.init(title: title, showsGear: showsGear) { EmptyView() }
    }
}

// MARK: Primary (gold) button

/// The one gold button per screen. Pinned at the bottom with `.primaryAction { … }`.
struct PrimaryButton: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.play(.select)
            action()
        } label: {
            PrimaryLabel(title: title, subtitle: subtitle, icon: icon, enabled: enabled)
        }
        .buttonStyle(GoldButtonStyle(enabled: enabled))
        .disabled(!enabled)
    }
}

/// Label of the gold button – also used for a gold `ShareLink` ("Invite a friend").
struct PrimaryLabel: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var enabled = true

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon).font(.system(size: 18, weight: .black))
            }
            Text(title)
                .font(DS.heading(20, .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .bold))
                    .opacity(0.7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundColor(enabled ? DS.goldLabel : DS.textMuted)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 58)
        .contentShape(Rectangle())
    }
}

struct GoldButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(enabled ? DS.goldEdge : DS.divider)
                    RoundedRectangle(cornerRadius: 14).fill(enabled ? DS.gold : DS.iconTile)
                        .padding(.bottom, pressed ? 1 : 3)
                }
            )
            .offset(y: pressed ? 2 : 0)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension View {
    /// Pins the screen's gold button above the tab bar (10 pt gap). Content scrolls above it and is never covered.
    func primaryAction<B: View>(@ViewBuilder _ button: () -> B) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                button()
                    .padding(.horizontal, DS.side)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [DS.bg.opacity(0), DS.bg, DS.bg], startPoint: .top, endPoint: .bottom)
            )
        }
    }
}

// MARK: List group and rows

/// Rounded container for list rows; rows add their own separators.
struct ListGroup<Content: View>: View {
    var inset = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: DS.groupRadius).fill(DS.group))
            .clipShape(RoundedRectangle(cornerRadius: DS.groupRadius))
            .padding(.horizontal, inset ? DS.side : 0)
    }
}

/// 44 pt icon tile with an SF Symbol in a meaning colour.
struct IconTile: View {
    let symbol: String
    var tint: Color = DS.text
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: DS.tileRadius).fill(DS.iconTile))
    }
}

/// What a row shows on the right.
enum RowTrailing {
    case chevron
    case value(String, chevron: Bool = true)
    case done
    case none
}

/// A full-width row: icon, title and subtitle, trailing value or chevron. 64 pt, or 52 pt when compact.
struct ListRow<Icon: View, Extra: View>: View {
    let title: String
    var subtitle: String? = nil
    var trailing: RowTrailing = .chevron
    var compact = false
    var showsDivider = true
    var titleColor: Color = DS.text
    @ViewBuilder let icon: () -> Icon
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        HStack(spacing: 14) {
            icon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.rowTitle)
                    .foregroundColor(titleColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(DS.rowSubtitle)
                        .foregroundColor(DS.textMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                extra()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingView
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: compact ? DS.compactRowHeight : DS.rowHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle().fill(DS.divider).frame(height: 1).padding(.leading, compact ? 14 : 72)
            }
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .chevron:
            chevron
        case .value(let v, let showChevron):
            HStack(spacing: 10) {
                Text(v)
                    .font(DS.number)
                    .monospacedDigit()
                    .foregroundColor(DS.text)
                    .lineLimit(1)
                    .fixedSize()
                if showChevron { chevron }
            }
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(DS.green)
                .accessibilityLabel(L("Erledigt"))
        case .none:
            EmptyView()
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(DS.chevron)
            .accessibilityHidden(true)
    }
}

extension ListRow where Extra == EmptyView {
    init(title: String, subtitle: String? = nil, trailing: RowTrailing = .chevron, compact: Bool = false,
         showsDivider: Bool = true, titleColor: Color = DS.text, @ViewBuilder icon: @escaping () -> Icon) {
        self.init(title: title, subtitle: subtitle, trailing: trailing, compact: compact, showsDivider: showsDivider,
                  titleColor: titleColor, icon: icon) { EmptyView() }
    }
}

/// Plain button style for rows: a light highlight while pressed.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.white.opacity(0.05) : Color.clear)
    }
}

/// Thin progress bar (gold for rewards, purple for XP).
struct DSProgressBar: View {
    let fraction: Double
    var tint: Color = DS.gold
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.iconTile)
                Capsule().fill(tint)
                    .frame(width: max(fraction > 0 ? height : 0, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Segmented filter in group style; the selected segment is an icon-tile fill (not gold or blue).
struct DSSegmented<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(items, id: \.0) { item in
                    let active = item.0 == selection
                    Button {
                        Haptics.shared.play(.select)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = item.0 }
                    } label: {
                        Text(item.1)
                            .font(.system(size: 14, weight: active ? .heavy : .semibold, design: .rounded))
                            .foregroundColor(active ? DS.text : DS.textMuted)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(active ? DS.iconTile : Color.clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
            .padding(3)
        }
        .blocksPagerSwipe()
        .background(RoundedRectangle(cornerRadius: 11).fill(DS.group))
        .padding(.horizontal, DS.side)
    }
}

// MARK: Trophy road as a sheet

/// The trophy road (formerly the Path tab) opened from the Magic Chest bar or the trophy pill.
struct TrophyRoadSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TrophyRoadView(onClose: { dismiss() })
            .environment(\.liveAnimations, true)
            .preferredColorScheme(.dark)
    }
}

#Preview("Design system") {
    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            ScreenHeader(title: "Puzzles", showsGear: true)
            SectionLabel("More ways to train")
            ListGroup {
                ListRow(title: "Puzzle Rush", subtitle: "3 minutes, 3 lives", trailing: .value("26")) {
                    IconTile(symbol: "bolt.fill", tint: DS.flame)
                }
                ListRow(title: "Daily Puzzle", subtitle: "Done for today", trailing: .done, showsDivider: false) {
                    IconTile(symbol: "calendar", tint: DS.gold)
                }
            }
        }
    }
    .background(DS.bg)
    .primaryAction { PrimaryButton(title: "Solve puzzles", icon: "play.fill") {} }
    .preferredColorScheme(.dark)
}

// MARK: - Previews of the four redesigned tabs (data from the shared profile store)

#Preview("Play") {
    HomeView(session: .constant(nil), puzzleSession: .constant(nil), tab: .constant(.play))
        .preferredColorScheme(.dark)
}

#Preview("Puzzles") {
    PuzzleHubView(session: .constant(nil))
        .preferredColorScheme(.dark)
}

#Preview("Deck") {
    DeckView()
        .preferredColorScheme(.dark)
}

#Preview("Profile") {
    ProfileView()
        .preferredColorScheme(.dark)
}

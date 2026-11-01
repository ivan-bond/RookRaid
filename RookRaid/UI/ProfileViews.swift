import SwiftUI

struct ProfileView: View {
    @ObservedObject var store = ProfileStore.shared
    @State var showSettings = false
    @State var showStats = false
    @State var showStyle = false
    @State var styleTab: StyleSheet.StyleTab = .avatars
    @State var showAllAchievements = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                // Leichter Blau-Rot-Schimmer oben, wie im Logo
                LinearGradient(colors: [Theme.blueDark.opacity(0.55), Color(hex: 0x4A1E2C).opacity(0.25), .clear],
                               startPoint: .topLeading, endPoint: .center)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        topBar
                        ProfileHeroCard(onAvatar: { styleTab = .avatars; showStyle = true })
                        HallOfFameRow(onAchievements: { showAllAchievements = true })
                        BotConquestCard()
                        CollectionRingsCard(onStyle: { t in styleTab = t; showStyle = true })
                        AchievementShowcase(onShowAll: { showAllAchievements = true })
                        Button {
                            Haptics.shared.play(.select)
                            showStats = true
                        } label: { statsRow }
                            .buttonStyle(PressScaleStyle())
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showStats) {
            NavigationStack { StatisticsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStyle) { StyleSheet(tab: styleTab) }
        .sheet(isPresented: $showAllAchievements) { AchievementListSheet() }
        .onChange(of: store.profile.settings) { newValue in
            Feedback.apply(settings: newValue)
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Kopf im Stil von Puzzles und Deck: schräges Symbol mit Verlauf und großer Titel
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Theme.redLight, Theme.red], startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(-10))
            Text(L("Profil"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            ShardPill()
            Button { NotificationCenter.default.post(name: .openSettings, object: nil) } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Theme.panelRaised))
            }
            .accessibilityLabel(L("Einstellungen"))
        }
        .padding(.top, 8)
    }

    /// Kurzfassung der Bilanz mit der Form der letzten Partien; die ganze Statistik liegt auf einer eigenen Seite.
    private var statsRow: some View {
        let p = store.profile
        let games = p.wins + p.losses + p.draws
        let rate = games == 0 ? 0 : Int((Double(p.wins) / Double(games) * 100).rounded())
        let form = Array(p.history.filter { $0.opponent != "Zu zweit" }.prefix(8).reversed().map(\.result))
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Theme.blue, Theme.blueDark], startPoint: .top, endPoint: .bottom))
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Statistik & Verlauf"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(games == 0 ? L("Noch keine Partien") : L("{0} S · {1} N · {2} R · {3} % Siege", p.wins, p.losses, p.draws, rate))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                if !form.isEmpty { FormDots(results: form) }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Theme.blueDark.opacity(0.6), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.blueLight.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Erfolge (Vitrine)

/// Die drei Erfolge, die am nächsten dran sind – mit Fortschritt und Belohnung.
struct AchievementShowcase: View {
    @ObservedObject var store = ProfileStore.shared
    let onShowAll: () -> Void

    var body: some View {
        let all = store.achievements
        let done = all.filter(\.unlocked)
        let next = all.filter { !$0.unlocked }.sorted { $0.fraction > $1.fraction }.prefix(3)
        let claimable = all.filter { $0.unlocked && !store.isClaimed($0) }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardTitle(icon: "rosette", title: L("Erfolge"))
                Text("\(done.count)/\(all.count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.gold)
                Spacer()
                Button(L("Alle"), action: onShowAll)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.blueLight)
            }
            if !claimable.isEmpty {
                ClaimAllButton(achievements: claimable)
            }
            if !done.isEmpty {
                // Vitrine: errungene Medaillen auf einem leuchtenden Regalbrett
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(done) { a in
                            AchievementMedal(achievement: a, size: 38)
                                .accessibilityLabel(a.title)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                }
                .background(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [Color(hex: 0x8A5A2B), Color(hex: 0x5A3518)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 8)
                        .shadow(color: Theme.gold.opacity(0.35), radius: 8, y: -2)
                }
            }
            if next.isEmpty {
                Text(L("Alle Erfolge geschafft – Respekt!"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.gold)
            }
            ForEach(Array(next)) { a in
                HStack(spacing: 12) {
                    AchievementMedal(achievement: a, size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(a.title)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text("\(min(a.progress, a.goal))/\(a.goal)")
                                .font(.system(size: 11, weight: .heavy).monospacedDigit())
                                .foregroundColor(Theme.gold)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule()
                                    .fill(LinearGradient(colors: [Theme.gold, Color(hex: 0xFFB648)], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(4, geo.size.width * a.fraction))
                            }
                        }
                        .frame(height: 6)
                        Text("\(a.detail) · \(a.fullRewardText)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                            .lineLimit(2)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0x3A2A12).opacity(0.7), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Erfolge: Liste und Abholen

/// Medaille eines Erfolgs: Ring in Bronze, Silber oder Gold, grau solange gesperrt.
struct AchievementMedal: View {
    let achievement: Achievement
    var size: CGFloat = 44

    static func tierColors(_ tier: Int) -> [Color] {
        switch tier {
        case 1: return [Color(hex: 0xF0B07A), Color(hex: 0xA8642F)]
        case 2: return [Color(hex: 0xF4F7FB), Color(hex: 0x9AA6B8)]
        case 3: return [CardStyle.ultimateTop, Theme.gold]
        default: return [Theme.blueLight, Theme.blue]
        }
    }

    var body: some View {
        let colors = AchievementMedal.tierColors(achievement.tier)
        ZStack {
            Circle()
                .fill(achievement.unlocked
                      ? AnyShapeStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Theme.panel))
            Circle()
                .strokeBorder(achievement.unlocked ? Color.white.opacity(0.5) : Theme.panelHighlight, lineWidth: 1.5)
            Image(systemName: achievement.icon)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(achievement.unlocked ? Theme.navy : Theme.textMuted.opacity(0.7))
        }
        .frame(width: size, height: size)
        .shadow(color: achievement.unlocked ? colors[1].opacity(0.45) : .clear, radius: size * 0.15)
    }
}

/// „X Erfolge abholen“: alle auf einmal, mit Splitter-Regen in der Anzeige oben.
struct ClaimAllButton: View {
    @ObservedObject var store = ProfileStore.shared
    let achievements: [Achievement]

    var body: some View {
        let total = achievements.reduce(0) { $0 + $1.shards }
        Button {
            var sum = 0
            for a in achievements { sum += store.claim(a) }
            if sum > 0 {
                Haptics.shared.play(.chestBigReveal)
                SoundPlayer.shared.play(.rewardBig)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                Text(achievements.count == 1 ? L("Erfolg abholen") : L("{0} Erfolge abholen", achievements.count))
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    Image(systemName: "diamond.fill").font(.system(size: 11, weight: .black))
                    Text("+\(total)").font(.system(size: 15, weight: .black, design: .rounded))
                }
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 50, textColor: Theme.navy))
        .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
        .modifier(PulseGlow(color: Theme.gold, active: true))
    }
}

/// Alle Erfolge nach Bereich – mit Fortschritt, Belohnung und Abholen-Knopf.
struct AchievementListSheet: View {
    @ObservedObject var store = ProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State var justClaimed: String?

    var body: some View {
        let all = store.achievements
        let claimable = all.filter { $0.unlocked && !store.isClaimed($0) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
                            Circle()
                                .trim(from: 0, to: Double(all.filter(\.unlocked).count) / Double(max(1, all.count)))
                                .stroke(Theme.gold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: "rosette")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Theme.gold)
                        }
                        .frame(width: 62, height: 62)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("{0} von {1} Erfolgen", all.filter(\.unlocked).count, all.count))
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text(L("Jeder Erfolg bringt Splitter – manche auch Titel oder Rahmen."))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer(minLength: 0)
                        ShardPill()
                    }
                    if !claimable.isEmpty {
                        ClaimAllButton(achievements: claimable)
                    }
                    ForEach(AchievementCategory.allCases) { cat in
                        let items = all.filter { $0.category == cat }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(cat.name, systemImage: cat.icon)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text("\(items.filter(\.unlocked).count)/\(items.count)")
                                    .font(.system(size: 12, weight: .heavy).monospacedDigit())
                                    .foregroundColor(Theme.gold)
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { idx, a in
                                    if idx > 0 { Rectangle().fill(Theme.panelHighlight).frame(height: 1).padding(.leading, 62) }
                                    row(a)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Erfolge"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ a: Achievement) -> some View {
        let claimed = store.isClaimed(a)
        return HStack(spacing: 12) {
            AchievementMedal(achievement: a, size: 42)
                .scaleEffect(justClaimed == a.id ? 1.2 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(a.title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(a.unlocked ? Theme.textPrimary : Theme.textSecondary)
                Text(a.detail)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                if !a.unlocked {
                    ProgressPill(fraction: a.fraction, text: "\(min(a.progress, a.goal))/\(a.goal)")
                        .padding(.horizontal, -6)
                        .frame(maxWidth: 160)
                }
                Text(a.fullRewardText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(claimed ? Theme.textMuted : ShardStyle.color)
            }
            Spacer(minLength: 4)
            if claimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.green)
            } else if a.unlocked {
                Button {
                    if store.claim(a) > 0 {
                        Haptics.shared.play(.chestReveal)
                        SoundPlayer.shared.play(.reward)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { justClaimed = a.id }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            withAnimation(.spring()) { justClaimed = nil }
                        }
                    }
                } label: {
                    Text(L("Abholen"))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Capsule().fill(Theme.gold))
                        .shadow(color: Theme.gold.opacity(0.6), radius: 6)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Garderobe: Avatar, Rahmen, Titel & Figuren

/// Garderobe im Stil des Splitter-Ladens: oben die Bühne mit deinem Avatar, Titel und Figurenset,
/// darunter Reiter für Avatare, Rahmen, Titel und Figurensets – jede Kachel zeigt, wie man sie bekommt.
/// Figurensets gehören dir, sobald du den jeweiligen Bot besiegt hast.
struct StyleSheet: View {
    @ObservedObject var store = ProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State var buyAvatar: Avatar?
    @State var buyBoard: BoardTheme?
    @State var tab: StyleTab = .avatars
    @State var pop = false

    enum StyleTab: CaseIterable, Identifiable {
        case avatars, frames, titles, pieces, boards
        var id: Self { self }
        var title: String {
            switch self {
            case .avatars: return L("Avatare")
            case .frames: return L("Rahmen")
            case .titles: return L("Titel")
            case .pieces: return L("Figuren")
            case .boards: return L("Bretter")
            }
        }
        var icon: String {
            switch self {
            case .avatars: return "person.fill"
            case .frames: return "circle.dashed"
            case .titles: return "rosette"
            case .pieces: return "crown.fill"
            case .boards: return "square.grid.2x2.fill"
            }
        }
    }

    private let grid3 = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    private let grid2 = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    showcase
                    tabBar
                    Group {
                        switch tab {
                        case .avatars: avatarsTab
                        case .frames: framesTab
                        case .titles: titlesTab
                        case .pieces: piecesTab
                        case .boards: boardsTab
                        }
                    }
                    .id(tab)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.background
                    RadialGradient(colors: [Theme.blue.opacity(0.35), .clear], center: .top, startRadius: 10, endRadius: 420)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(L("Garderobe"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
        }
        .confirmationDialog(buyAvatar.map { L("Avatar „{0}“ kaufen?", $0.name) } ?? "",
                            isPresented: Binding(get: { buyAvatar != nil }, set: { if !$0 { buyAvatar = nil } }),
                            titleVisibility: .visible) {
            if let a = buyAvatar {
                Button(L("Für {0} Splitter kaufen", a.price)) {
                    if store.buy(.avatar(a), price: a.price) != nil {
                        Haptics.shared.play(.chestBigReveal)
                        SoundPlayer.shared.play(.rewardBig)
                        store.profile.selectedAvatar = a.rawValue
                        celebrate()
                    } else {
                        Haptics.shared.play(.invalid)
                    }
                    buyAvatar = nil
                }
                Button(L("Abbrechen"), role: .cancel) { buyAvatar = nil }
            }
        } message: {
            if let a = buyAvatar {
                Text(store.profile.shards >= a.price ? L("{0} · auch aus Truhen ziehbar", a.rarity.name) : L("Dir fehlen noch {0} Splitter.", a.price - store.profile.shards))
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Bühne

    private var owned: (avatars: Int, frames: Int, titles: Int, pieces: Int, boards: Int) {
        (Avatar.allCases.filter { store.isOwned($0) }.count,
         store.unlockedFrames.count,
         store.unlockedTitles.count + 1,
         store.unlockedSkinCount + 1,
         BoardTheme.allCases.filter { store.isOwned($0) }.count)
    }

    private func total(_ t: StyleTab) -> Int {
        switch t {
        case .avatars: return Avatar.allCases.count
        case .frames: return AvatarFrame.allCases.count
        case .titles: return store.achievements.filter { $0.rewardTitle != nil }.count + ChestTitle.all.count + 1
        case .pieces: return BotLevel.allCases.count + 1
        case .boards: return BoardTheme.allCases.count
        }
    }

    private func have(_ t: StyleTab) -> Int {
        let o = owned
        switch t {
        case .avatars: return o.avatars
        case .frames: return o.frames
        case .titles: return o.titles
        case .pieces: return o.pieces
        case .boards: return o.boards
        }
    }

    private var showcase: some View {
        let sum = StyleTab.allCases.reduce(0) { $0 + have($1) }
        let all = StyleTab.allCases.reduce(0) { $0 + total($1) }
        return VStack(spacing: 10) {
            ZStack {
                LightRays(colors: [Theme.blueLight, Theme.redLight, Theme.gold], count: 12, speed: 0.25)
                    .frame(width: 220, height: 150)
                    .clipShape(Ellipse())
                    .opacity(0.5)
                PlayerAvatar(size: 104)
                    .scaleEffect(pop ? 1.14 : 1)
                    .modifier(RoadBob(active: true, amplitude: 2.5, speed: 2))
            }
            .frame(height: 136)
            Text(store.profile.name)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text((store.activeTitle ?? ProfileStore.rank(for: store.level)).uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Theme.navy)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 20)
                .background(RibbonShape().fill(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom)))
            // Dein Figurenset auf einer Reihe deines Bretts (v0.9.24: Brett-Design gehört jetzt zur Garderobe)
            let board = BoardColors.forTheme(store.profile.settings.boardTheme)
            HStack(spacing: 0) {
                ForEach(Array([PieceType.rook, .knight, .bishop, .queen, .king, .pawn].enumerated()), id: \.offset) { i, t in
                    ZStack {
                        Rectangle().fill(i % 2 == 0 ? board.light : board.dark)
                        PieceImage(type: t, color: .white, skin: store.activeSkin)
                            .padding(3)
                    }
                    .frame(width: 36, height: 36)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
            .scaleEffect(pop ? 1.08 : 1)
            VStack(spacing: 4) {
                HStack {
                    Text(L("Sammlung"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(sum)/\(all)")
                        .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(Theme.gold)
                }
                ShopProgressBar(fraction: Double(sum) / Double(max(1, all)), tint: Theme.gold)
                    .frame(height: 7)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            ZStack {
                LinearGradient(colors: [Theme.blueDark, Color(hex: 0x1A2342), Color(hex: 0x4A1E2C)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                TwinkleField(count: 16, colors: [.white, Theme.gold, Theme.blueLight])
                    .opacity(0.6)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: Reiter

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(StyleTab.allCases) { t in
                Button {
                    guard t != tab else { return }
                    Haptics.shared.play(.select)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: t.icon).font(.system(size: 14, weight: .black))
                        Text(t.title)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(have(t))/\(total(t))")
                            .font(.system(size: 9, weight: .black, design: .rounded).monospacedDigit())
                            .opacity(0.75)
                    }
                    .foregroundColor(t == tab ? Theme.navy : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised)
                            RoundedRectangle(cornerRadius: 14)
                                .fill(LinearGradient(colors: [.white, Theme.blueLight], startPoint: .top, endPoint: .bottom))
                                .shadow(color: Theme.blueLight.opacity(0.6), radius: 8)
                                .opacity(t == tab ? 1 : 0)
                                .scaleEffect(t == tab ? 1 : 0.85)
                        }
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: tab)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Kachel

    private func tile<Preview: View>(selected: Bool, owned: Bool, accent: Color, title: String, footer: String, footerColor: Color,
                                     action: @escaping () -> Void, @ViewBuilder preview: () -> Preview) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                preview()
                    .frame(height: 66)
                Text(title)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(owned ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(footer)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(footerColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .frame(minHeight: 24, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [accent.opacity(owned ? 0.28 : 0.1), Theme.panelRaised], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Theme.green : accent.opacity(owned ? 0.45 : 0.18), lineWidth: selected ? 2.5 : 1))
            .shadow(color: selected ? Theme.green.opacity(0.5) : .clear, radius: 8)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.green)
                        .background(Circle().fill(Theme.background))
                        .offset(x: 5, y: -5)
                } else if !owned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.panelHighlight))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(PressScaleStyle())
    }

    private func celebrate() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { pop = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(.spring()) { pop = false }
        }
    }

    private func select(_ apply: () -> Void) {
        apply()
        Haptics.shared.play(.chestReveal)
        celebrate()
    }

    // MARK: Avatare

    private var avatarsTab: some View {
        LazyVGrid(columns: grid3, spacing: 12) {
            ForEach(Avatar.allCases) { a in
                let isOwned = store.isOwned(a)
                let affordable = store.profile.shards >= a.price
                tile(selected: store.activeAvatar == a, owned: isOwned, accent: Color(hex: a.rarity.colorHex),
                     title: a.name,
                     footer: isOwned ? a.rarity.name : L("{0} Splitter", a.price),
                     footerColor: isOwned ? Color(hex: a.rarity.colorHex) : (affordable ? ShardStyle.color : Theme.textMuted),
                     action: {
                         if isOwned {
                             select { store.profile.selectedAvatar = a == .knight ? nil : a.rawValue }
                         } else {
                             Haptics.shared.play(.select)
                             buyAvatar = a
                         }
                     }) {
                    PlayerAvatar(size: 62, frame: AvatarFrame.none, avatar: a)
                        .saturation(isOwned ? 1 : 0.15)
                        .opacity(isOwned ? 1 : 0.6)
                }
                .accessibilityLabel(a.name + (isOwned ? "" : L(", gesperrt, {0} Splitter", a.price)))
            }
        }
    }

    // MARK: Rahmen

    private var framesTab: some View {
        let achievements = store.achievements
        return LazyVGrid(columns: grid3, spacing: 12) {
            ForEach(AvatarFrame.allCases) { f in
                let isOwned = store.unlockedFrames.contains(f)
                let source = achievements.first { $0.rewardFrame == f }
                let footer: String = isOwned ? L("Freigeschaltet")
                    : (f.isShopFrame ? L("Laden · {0}", ProfileStore.shopFramePrice) : (source?.title ?? ""))
                tile(selected: store.activeFrame == f, owned: isOwned, accent: Color(hex: f.colors.first ?? 0x5B7FC7),
                     title: f.name, footer: footer,
                     footerColor: isOwned ? Theme.textMuted : (f.isShopFrame ? ShardStyle.color : Theme.textMuted),
                     action: {
                         guard isOwned else { Haptics.shared.play(.invalid); return }
                         select { store.profile.selectedFrame = f == .none ? nil : f.rawValue }
                     }) {
                    PlayerAvatar(size: 62, frame: f)
                        .opacity(isOwned ? 1 : 0.35)
                }
            }
        }
    }

    // MARK: Titel

    private var titlesTab: some View {
        let achievements = store.achievements
        return LazyVGrid(columns: grid2, spacing: 12) {
            titleTile(ProfileStore.rank(for: store.level), hint: L("Rang nach Level"), owned: true, value: nil)
            ForEach(achievements.filter { $0.rewardTitle != nil }) { a in
                titleTile(a.rewardTitle ?? "", hint: a.unlocked ? a.title : "\(a.detail) (\(min(a.progress, a.goal))/\(a.goal))",
                          owned: a.unlocked, value: a.rewardTitle)
            }
            ForEach(ChestTitle.all, id: \.title) { t in
                titleTile(t.title, hint: L("{0} · aus Truhen", t.rarity.name),
                          owned: store.profile.chestTitles.contains(t.title), value: t.title)
            }
        }
    }

    private func titleTile(_ title: String, hint: String, owned: Bool, value: String?) -> some View {
        let active = value == nil ? !(store.profile.selectedTitle.map { store.unlockedTitles.contains($0) } ?? false)
                                  : store.profile.selectedTitle == value && owned
        return tile(selected: active, owned: owned, accent: Theme.gold, title: L(title), footer: hint, footerColor: Theme.textMuted,
                    action: {
                        guard owned else { Haptics.shared.play(.invalid); return }
                        select { store.profile.selectedTitle = value }
                    }) {
            Text(L(title).uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundColor(owned ? Theme.navy : Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 14)
                .frame(height: 24)
                .background(RibbonShape().fill(owned
                                               ? AnyShapeStyle(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom))
                                               : AnyShapeStyle(Theme.panelHighlight)))
                .padding(.horizontal, 4)
        }
    }

    // MARK: Figurensets

    private var piecesTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Besiege einen Bot – in der Leiter oder im Kampf – und sein Figurenset gehört dir. Du spielst dann mit diesen Figuren."))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: grid2, spacing: 12) {
                tile(selected: store.activeSkin == nil, owned: true, accent: Theme.blueLight,
                     title: L("Standard"), footer: L("Die klassischen Figuren"), footerColor: Theme.textMuted,
                     action: { select { store.profile.selectedSkin = nil } }) {
                    setPreview(nil, owned: true)
                }
                ForEach(BotLevel.allCases) { bot in
                    let isOwned = store.isSkinUnlocked(bot)
                    tile(selected: store.activeSkin == bot, owned: isOwned, accent: Color(hex: bot.colorHex),
                         title: bot.skinName,
                         footer: isOwned ? L("von {0}", bot.displayName) : L("Besiege {0} (Stufe {1})", bot.displayName, bot.tier),
                         footerColor: isOwned ? Color(hex: bot.colorHex) : Theme.textMuted,
                         action: {
                             guard isOwned else { Haptics.shared.play(.invalid); return }
                             select { store.profile.selectedSkin = bot.rawValue }
                         }) {
                        setPreview(bot, owned: isOwned)
                    }
                    .accessibilityLabel(bot.skinName + (isOwned ? "" : L(", gesperrt")))
                }
            }
        }
    }

    // MARK: Bretter

    /// Brett-Designs (v0.9.24 aus den Einstellungen hierher umgezogen): vier Grundbretter, drei Sammelbretter.
    private var boardsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Sammelbretter (Lava, Smaragd, Mitternacht) kommen aus Magischen und Legendären Truhen oder kosten {0} Splitter.", BoardTheme.collectiblePrice))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: grid2, spacing: 12) {
                ForEach(BoardTheme.allCases) { theme in
                    let isOwned = store.isOwned(theme)
                    let affordable = store.profile.shards >= BoardTheme.collectiblePrice
                    let colors = BoardColors.forTheme(theme)
                    tile(selected: store.profile.settings.boardTheme == theme, owned: isOwned, accent: colors.dark,
                         title: theme.name,
                         footer: isOwned ? (theme.isCollectible ? L("Sammelbrett") : L("Freigeschaltet")) : L("{0} Splitter", BoardTheme.collectiblePrice),
                         footerColor: isOwned ? Theme.textMuted : (affordable ? ShardStyle.color : Theme.textMuted),
                         action: {
                             if isOwned {
                                 select { store.profile.settings.boardTheme = theme }
                             } else {
                                 Haptics.shared.play(.select)
                                 buyBoard = theme
                             }
                         }) {
                        boardPreview(theme, owned: isOwned)
                    }
                    .accessibilityLabel(isOwned ? theme.name : L("{0}, gesperrt, {1} Splitter", theme.name, BoardTheme.collectiblePrice))
                }
            }
        }
        .confirmationDialog(buyBoard.map { L("Brett „{0}“ kaufen?", $0.name) } ?? "",
                            isPresented: Binding(get: { buyBoard != nil }, set: { if !$0 { buyBoard = nil } }),
                            titleVisibility: .visible) {
            if let b = buyBoard {
                Button(L("Für {0} Splitter kaufen", BoardTheme.collectiblePrice)) {
                    if store.buy(b) {
                        Haptics.shared.play(.chestBigReveal)
                        SoundPlayer.shared.play(.rewardBig)
                        store.profile.settings.boardTheme = b
                        celebrate()
                    } else {
                        Haptics.shared.play(.invalid)
                    }
                    buyBoard = nil
                }
                Button(L("Abbrechen"), role: .cancel) { buyBoard = nil }
            }
        } message: {
            if buyBoard != nil {
                Text(store.profile.shards >= BoardTheme.collectiblePrice ? L("Auch aus Magischen und Legendären Truhen")
                     : L("Dir fehlen noch {0} Splitter.", BoardTheme.collectiblePrice - store.profile.shards))
            }
        }
    }

    /// 4 × 3 Felder des Bretts mit König und Springer aus deinem Figurenset; gesperrte gedämpft.
    private func boardPreview(_ theme: BoardTheme, owned: Bool) -> some View {
        let colors = BoardColors.forTheme(theme)
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { c in
                        ZStack {
                            Rectangle().fill((r + c) % 2 == 0 ? colors.light : colors.dark)
                            if r == 1 && c == 1 {
                                PieceImage(type: .king, color: .white, skin: store.activeSkin).padding(1)
                            } else if r == 1 && c == 2 {
                                PieceImage(type: .knight, color: .black, skin: nil).padding(2)
                            }
                        }
                        .frame(width: 22, height: 22)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
        .saturation(owned ? 1 : 0.2)
        .opacity(owned ? 1 : 0.6)
    }

    /// Drei Figuren eines Sets nebeneinander; gesperrte als Schatten.
    private func setPreview(_ skin: BotLevel?, owned: Bool) -> some View {
        HStack(spacing: -6) {
            ForEach([PieceType.knight, .king, .queen], id: \.self) { t in
                PieceImage(type: t, color: .white, skin: skin)
                    .frame(width: t == .king ? 52 : 42, height: t == .king ? 52 : 42)
                    .colorMultiply(owned ? .white : Color(hex: 0x10182E))
                    .opacity(owned ? 1 : 0.85)
            }
        }
        .overlay {
            if !owned {
                Text("?")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Statistik

struct StatisticsView: View {
    @ObservedObject var store = ProfileStore.shared
    @State var replayToShow: GameReplay?

    var body: some View {
        let stats = ProfileStats(store: store)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BalanceCard(profile: store.profile, stats: stats)
                TrophyTrendCard(series: stats.trophySeries)
                StatGrid(stats: stats)
                BotRecordCard(bots: stats.bots)
                PuzzleProgressCard(stats: stats)
                history
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 30)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("Statistik"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .fullScreenCover(item: $replayToShow) { r in ReplayView(replay: r) }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: L("Letzte Partien"))
            if store.profile.history.isEmpty {
                Text(L("Noch keine Partien gespielt."))
                    .font(.footnote)
                    .foregroundColor(Theme.textMuted)
            }
            ForEach(store.profile.history.prefix(20)) { record in
                Button {
                    if let r = store.replay(for: record.replayID) { replayToShow = r }
                } label: {
                HStack(spacing: 10) {
                    Text(record.result.label)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 78, height: 24)
                        .background(RoundedRectangle(cornerRadius: 5).fill(color(for: record.result)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("vs. {0}", ProfileStore.displayOpponent(record.opponent)))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Text(L("{0} · {1} Züge · {2} Karten", record.reason, record.moves, record.cardsPlayed))
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        if record.trophyDelta != 0 {
                            Text(record.trophyDelta > 0 ? "+\(record.trophyDelta)" : "\(record.trophyDelta)")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(record.trophyDelta > 0 ? Theme.green : Theme.red)
                        }
                        Text(record.date, style: .date)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textMuted)
                    }
                    if store.replay(for: record.replayID) != nil {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.blue)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.panelRaised))
                }
                .buttonStyle(.plain)
                .disabled(store.replay(for: record.replayID) == nil)
            }
        }
    }

    private func color(for result: GameResultKind) -> Color {
        switch result {
        case .win: return Theme.greenDark
        case .loss: return Color(hex: 0x9E2B25)
        case .draw: return Theme.panelHighlight
        }
    }

}

// MARK: - Einstellungen

struct SettingsSheet: View {
    @ObservedObject var store = ProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State var showReset = false
    @State var showRules = false
    @State var editLocalName = false
    @ObservedObject private var account = OnlineAccount.shared

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let b = (info["CFBundleVersion"] as? String) ?? "?"
        return L("Rook Raid {0} (Build {1})", v, b)
    }

    /// Konto-Bereich: sobald online an ist – in Debug-Builds schon vorher zum Testen gegen den Server.
    private var showAccount: Bool { OnlineConfig.isLive }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    settingsGroup(L("Spiel")) {
                        if !(showAccount && account.hasAccount) {
                            Button { editLocalName = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(Theme.blueLight)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(L("Spielername"))
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(store.profile.name)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Theme.textMuted)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Theme.textMuted)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            divider
                        }
                        toggleRow(L("Haptik"), "iphone.radiowaves.left.and.right", $store.profile.settings.haptics)
                        divider
                        toggleRow(L("Sound"), "speaker.wave.2.fill", $store.profile.settings.sound)
                        divider
                        Button {
                            dismiss()
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 450_000_000)
                                NotificationCenter.default.post(name: .startHotSeat, object: nil)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(Theme.green)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("Zu zweit an einem Gerät spielen"))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                    Text(L("Ohne Trophäen"))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Theme.textMuted)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(L("Anzeige")) {
                        toggleRow(L("Gebiet auf dem Brett zeigen"), "square.grid.3x3.fill", $store.profile.settings.showTerritory)
                        divider
                        toggleRow(L("Bots mit eigenem Figurenset"), "crown.fill", $store.profile.settings.botSkins)
                        divider
                        toggleRow(L("Koordinaten anzeigen"), "number", $store.profile.settings.showCoordinates)
                        #if DEBUG
                        divider
                        toggleRow(L("Testmodus: alle Karten frei"), "lock.open.fill", $store.profile.settings.unlockAll)
                        #endif
                    }

                    settingsGroup(L("Sprache")) {
                        NavigationLink {
                            LanguageListView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .foregroundColor(Theme.green)
                                    .frame(width: 22)
                                Text(L("Sprache"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(store.profile.settings.language.flag + " " + store.profile.settings.language.nativeName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.textMuted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }

                    if showAccount { AccountSection() }

                    #if DEBUG
                    // Nur für Entwickler: Regeltests (Abgleich mit dem JavaScript-Regel-Port) und Online-Vorbereitung
                    NavigationLink {
                        DeveloperView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill").foregroundColor(Theme.gold).frame(width: 22)
                            Text("Entwickler: Regeltests & Online")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(Theme.textMuted)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
                    }
                    .buttonStyle(.plain)
                    #endif

                    settingsGroup(L("Hilfe")) {
                        Button { showRules = true } label: {
                            settingsLink(L("Regeln & Karten erklärt"), "book.fill", Theme.gold)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button {
                            dismiss()
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 450_000_000)
                                NotificationCenter.default.post(name: .startTutorial, object: nil)
                            }
                        } label: {
                            settingsLink(L("Erste Schlacht erneut spielen"), "graduationcap.fill", Theme.blueLight)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(L("Daten")) {
                        Text(L("Alle Daten liegen nur lokal auf diesem iPhone: Profil, Fortschritt, Verlauf und die laufende Partie."))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        divider
                        Button { showReset = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash")
                                    .foregroundColor(Theme.red)
                                    .frame(width: 22)
                                Text(L("Fortschritt zurücksetzen"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.red)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(version)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showRules) { RulesView() }
        .sheet(isPresented: $editLocalName) { LocalNameSheet() }
        .confirmationDialog(L("Gesamten Fortschritt löschen?"), isPresented: $showReset, titleVisibility: .visible) {
            Button(L("Zurücksetzen"), role: .destructive) { store.resetProgress() }
            Button(L("Abbrechen"), role: .cancel) {}
        } message: {
            Text(L("Trophäen, Statistik, XP, gelöste Puzzles, Flammen und Verlauf werden zurückgesetzt. Einstellungen bleiben erhalten."))
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
        }
    }

    private func settingsLink(_ title: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(tint)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle().fill(Theme.panelHighlight).frame(height: 1).padding(.leading, 46)
    }

    private func toggleRow(_ title: String, _ icon: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.green)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .tint(Theme.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

}

/// Sprachliste: Ein Tipp wechselt sofort die Sprache der ganzen App.
struct LanguageListView: View {
    @ObservedObject var store = ProfileStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { i, lang in
                    let active = store.profile.settings.language == lang
                    Button {
                        guard !active else { return }
                        Haptics.shared.play(.select)
                        store.profile.settings.language = lang
                    } label: {
                        HStack(spacing: 12) {
                            Text(lang.flag).font(.system(size: 24))
                            Text(lang.nativeName)
                                .font(.system(size: 16, weight: active ? .heavy : .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            if active {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Theme.green)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(lang.nativeName + (active ? ", " + L("aktiv") : ""))
                    if i < AppLanguage.allCases.count - 1 {
                        Rectangle().fill(Theme.panelHighlight).frame(height: 1).padding(.leading, 56)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("Sprache"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Regeln

struct RulesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {
                    goalBanner
                    chapter(L("Ablauf eines Zuges"), Theme.blueLight, RulesSceneTurn()) {
                        note(L("Zu Beginn deines Zuges bekommst du +1 Mana."))
                        note(L("Dann wählst du genau eine Aktion: einen Schachzug, eine Karte oder – ab {0} Mana – deine Ultimate.", GameState.ultimateCost))
                    }
                    chapter(L("Gebiet"), Theme.green, RulesSceneTerritory()) {
                        line("square.grid.3x3.fill", L("Besetzt"), L("Jede Figur besetzt ihr Feld und alle 8 Nachbarfelder, auch diagonal. Grenzt ein Feld an Figuren beider Seiten oder an gar keine, ist es neutral."))
                        line("circle.lefthalf.filled", L("Anzeige"), L("Dein Gebiet ist heller und frischer getönt, das gegnerische gedeckter. Es zeigt, wo deine Figuren das Brett beherrschen – Mana bringt es nicht."))
                    }
                    chapter(L("Mana (maximal {0})", GameState.maxMana), Theme.manaLight, RulesSceneMana()) {
                        line("arrow.clockwise", L("Jeder Zug"), L("+1 Mana zu Beginn deines Zuges"))
                        line("star.fill", L("Guter Zug"), L("+1 extra für Schlagen, Schach oder eine Taktik (Gabel, Fesselung, Spieß, Abzugs- oder Doppelschach) – höchstens +1 pro Zug"))
                        line("drop.fill", L("Mana-Karten"), L("Konzentration, Manaraub und Bauernopfer bringen zusätzlich Mana."))
                    }
                    chapter(L("Deck"), Theme.blueLight, RulesSceneDeck()) {
                        line("rectangle.stack.fill", L("4 Karten + 1 Ultimate"), L("Vor der Partie stellst du im Tab „Deck“ dein Deck zusammen. Die vier Karten bleiben die ganze Partie auf der Hand – es wird nicht nachgezogen. Beide Decks sind offen."))
                        line("hourglass", L("Abklingzeit"), L("Nach dem Ausspielen lädt eine Karte {0} eigene Züge nach (Blitz {1}), bevor du sie wieder spielen kannst.", GameState.cardCooldown, CardType.lightning.cooldown))
                        line("lock.open.fill", L("Freischalten"), L("4 Startkarten hast du sofort, 10 weitere kommen aus Truhen. Jeder Levelaufstieg bringt eine Truhe, der Level-Pfad garantiert die wichtigsten Karten. Gesperrte Karten lassen sich auch mit Splittern kaufen (Gewöhnlich 500, Selten 1.500, Episch 3.000). Seltene Karten gibt es ab Level 5, epische ab Level 10."))
                        line("square.stack.3d.up.fill", L("Vorlagen"), L("Sechs fertige Decks für sechs Strategien – ein Tipp übernimmt Karten und Ultimate."))
                    }
                    chapter(L("Ultimate"), Theme.gold, RulesSceneIcon(icon: "sparkles", tint: Theme.gold)) {
                        line("sparkles", L("Teil deines Decks"), L("Einsetzbar ab {0} Mana, die Festung schon ab {1} (dann leuchtet die Mana-Leiste golden). Verbraucht so viel Mana – der Rest bleibt – und ersetzt deinen Zug (Festung: danach noch ein Figurzug ohne Schlagen und ohne Schach). Der Gegner sieht deine Wahl.", GameState.ultimateCost, Ultimate.fortress.cost))
                    }
                    chapter(L("Bots"), Theme.redLight, RulesSceneIcon(icon: "person.3.fill", tint: Theme.redLight)) {
                        line("bolt.fill", L("Kampf!"), L("Im Kampf triffst du dieselben zwölf Charaktere wie in der Bot-Leiter, jeweils mit ihrem Deck. Welcher es ist, richtet sich nach deinen Trophäen: alle 200 Trophäen wartet ein stärkerer. Siege bringen 30 Trophäen."))
                        line("figure.stairs", L("Bot-Leiter"), L("Zwölf Charaktere von Bruno bis zur Turmkönigin. Besiege sie der Reihe nach: Der erste Sieg bringt 30 bis 200 XP und schaltet den nächsten frei, jede Revanche 10 XP. Keine Trophäen."))
                        line("timer", L("Denkzeit"), L("Die Bots rechnen höchstens 0,4 bis 8 Sekunden pro Zug – je stärker, desto länger und tiefer. Ab Sir Konrad nutzen sie eine verbesserte Suche mit Stellungsgedächtnis."))
                    }
                    chapter(L("Truhen"), Color(hex: 0xC084FC), RulesSceneChests()) {
                        line("shippingbox.fill", L("Woher"), L("Erste Schlacht, die ersten 3 Kampf-Siege des Tages, alle Tagesziele, jeder erste Leiter-Sieg, jedes 5. gelöste Puzzle, jeder Levelaufstieg, der Trophäenpfad, Flammen-Meilensteine und der Splitter-Laden."))
                        line("trophy.fill", L("Trophäenpfad"), L("Alle 50 bis 150 Trophäen wartet eine Belohnung: Truhen, Splitter, Sammelbretter und an jeder neuen Arena eine Magische oder Legendäre Truhe. Abgerechnet wird nach deinem Rekord – wer abrutscht, behält seine Stufen."))
                        line("hand.tap.fill", L("Öffnen"), L("Drei Taps laden die Truhe auf – jeder Tap kann sie zu einer besseren machen (Holz → Silber → Gold → Magisch → Legendär). Der vierte Tap sprengt sie auf. Danach läuft alles von selbst weiter, Tippen beschleunigt; wartende Truhen folgen direkt."))
                        line("gift.fill", L("Inhalt"), L("XP und Splitter, mit Glück eine neue Karte, ein Sammelbrett, ein Avatar, ein Rahmen oder ein Titel. Spätestens nach 12 Truhen ohne neue Karte ist eine dabei. Wer alle Karten hat, bekommt stattdessen einen Splitter-Fund (150)."))
                    }
                    chapter(L("Puzzles & XP"), Theme.gold, RulesSceneIcon(icon: "puzzlepiece.fill", tint: Theme.gold)) {
                        line("puzzlepiece.fill", L("Puzzles"), L("Rook Raid: erst Karte oder Ultimate, dann Matt. Klassisch: Matt in 1, 2 oder 3 und Materialgewinn. Bei Matt-Aufgaben zählt jedes Matt."))
                        line("star.fill", L("XP"), L("Leicht 10 · Mittel 20 · Schwer 35 XP beim ersten Lösen. Mit Fehler oder Hinweis gibt es die Hälfte, nach „Lösung“ keine XP."))
                        line("calendar", L("Tagespuzzle"), L("Jeden Tag ein neues – einmal am Tag +15 XP Bonus."))
                        line("flame.fill", L("Serie"), L("Jede Lösung ohne Fehler und ohne Hinweis verlängert deine Puzzle-Serie. Ein Fehler, ein Hinweis oder „Lösung“ setzt sie zurück."))
                        line("bolt.circle.fill", L("Puzzle-Rausch"), L("3 Minuten, 3 Leben: so viele Puzzles wie möglich, erst leicht, dann schwerer. Jedes gelöste bringt 3 XP – jage deinen Bestwert."))
                    }
                    chapter(L("Tägliche Flammen"), Color(hex: 0xFF8A3D), RulesSceneIcon(icon: "flame.fill", tint: Color(hex: 0xFF8A3D))) {
                        line("flame.fill", L("Flamme entzünden"), L("Löse ein Puzzle oder beende eine Partie (mindestens 10 Züge). Pro Tag zählt eine Flamme."))
                        line("calendar.badge.exclamationmark", L("Serie"), L("Lässt du einen Tag aus, beginnt die Serie wieder bei 1 – außer ein Flammenschutz springt ein."))
                        line("snowflake", L("Flammenschutz"), L("Höchstens 2 auf Vorrat. Verpasst du einen Tag, friert ein Schutz deine Flamme automatisch ein: Die Serie bleibt, wächst an diesem Tag aber nicht. Kostet 200 Splitter, gratis bei 7, 30, 100 und 365 Tagen."))
                        line("rosette", L("Meilensteine"), L("3 Tage: 25 Splitter · 7: Goldtruhe + Schutz · 14: 100 Splitter · 30: Magische Truhe + Schutz · 50: 250 Splitter · 100: Legendäre Truhe + Schutz · 365: Legendäre Truhe + 1000 Splitter."))
                    }
                    chapter(L("Splitter & Laden"), Color(hex: 0x7FE3FF), RulesSceneIcon(icon: "diamond.fill", tint: Color(hex: 0x7FE3FF))) {
                        line("diamond.fill", L("Sammeln"), L("Aus Truhen, dem Trophäenpfad, Flammen-Meilensteinen und jedem Erfolg (10 bis 400 Splitter beim Abholen)."))
                        line("bag.fill", L("Ausgeben"), L("Karten (500 / 1.500 / 3.000, ab ihrer Levelgrenze), Avatare (250 bis 2.000), Flammenschutz (200), Sammelbretter (300), Laden-Rahmen (500) und Truhen. Jeden Tag drei Tagesangebote mit Rabatt."))
                        line("star.fill", L("Sparziel"), L("Markiere im Laden einen Artikel mit dem Stern – der Fortschritt erscheint auf der Startseite."))
                    }
                    chapter(L("Erfolge"), Theme.gold, RulesSceneIcon(icon: "rosette", tint: Theme.gold)) {
                        line("rosette", L("63 Erfolge"), L("In neun Bereichen von Kampf bis Level, viele in Stufen (Bronze, Silber, Gold). Jeder bringt Splitter, manche zusätzlich einen Titel oder Avatar-Rahmen."))
                    }
                    chapter(L("Karten"), Theme.redLight, RulesSceneRoles()) {
                        note(L("{0} Zauber in fünf Rollen: Angriff, Kontrolle, Verteidigung, Mana und Comeback. Zeitliche Effekte gelten bis zum Ende des nächsten gegnerischen Zuges.", CardType.allCases.count))
                        line("figure.walk", L("Bonusaktionen"), L("Schild, Frost, Bollwerk, Sturmlauf, Bauernopfer, Vormarsch und Leibwache ersetzen deinen Zug nicht: Danach machst du noch einen Figurzug. Die Figur unter dem Schild und der vorgestürmte Bauer bleiben dabei stehen (goldenes Schloss). Eine weitere Karte oder die Ultimate geht in diesem Zug nicht mehr."))
                    }
                    chapter(L("Schutzregeln"), Theme.blueLight, RulesSceneShield()) {
                        note(L("Der König ist immun gegen Karten und Ultimates. Die Dame ist immun gegen Frost und Meteor."))
                        note(L("Karten und Ultimates geben kein Schach und lassen den eigenen König nicht im Schach."))
                        note(L("Dem Gegner muss danach ein legaler Zug bleiben."))
                        note(L("„Ungeschützt“ (Meteor) heißt: von keiner eigenen Figur gedeckt und nicht unter Schild oder Bollwerk. Blitz trifft jeden gegnerischen Bauern in deiner Hälfte, der nicht unter Schild oder Bollwerk steht."))
                        note(L("Eingefrorene Figuren bedrohen weiterhin Felder."))
                        note(L("Tauwetter: Kann ein Spieler, der nicht im Schach steht, nur wegen Frost nicht ziehen, tauen seine Figuren sofort auf. Frost erzwingt also nie ein Patt – ein Matt mit Hilfe von Frost bleibt ein Matt."))
                    }
                    chapter(L("Prototyp-Hinweise"), Theme.textMuted, RulesSceneIcon(icon: "info.circle.fill", tint: Theme.textSecondary)) {
                        note(L("Remis durch Patt, dreifache Stellungswiederholung und die 50-Züge-Regel. Karteneinsätze setzen den 50-Züge-Zähler zurück."))
                        note(L("Alle Daten werden nur lokal auf dem iPhone gespeichert."))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle(L("Regeln"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
        }
        .background(
            ZStack {
                Theme.background.ignoresSafeArea()
                RadialGradient(colors: [Color(hex: 0x6B4FD8).opacity(0.28), .clear], center: .top, startRadius: 10, endRadius: 480)
                    .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.dark)
    }

    private var goalBanner: some View {
        VStack(spacing: 12) {
            RulesSceneMate()
            Text(L("Ziel"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(L("Setze den gegnerischen König matt. Mit Uhr verliert auch, wessen Zeit abläuft."))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(hex: 0x2A2366), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5))
    }

    private func chapter<Art: View, Lines: View>(_ title: String, _ tint: Color, _ art: Art, @ViewBuilder lines: () -> Lines) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            art
                .frame(maxWidth: .infinity)
            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            lines()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.4), lineWidth: 1))
    }

    private func line(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(Theme.gold)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.black.opacity(0.28)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kleines Mattbild: der König in der Ecke, eine Dame schneidet ihm den Weg ab.
private struct RulesSceneMate: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { col in
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { row in
                        ZStack {
                            Rectangle().fill((row + col).isMultiple(of: 2) ? Color(hex: 0xF0D9A8) : Color(hex: 0xB58863))
                            piece(row: row, col: col)
                        }
                        .frame(height: 28)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.35), lineWidth: 2))
        .frame(height: 112)
    }

    @ViewBuilder private func piece(row: Int, col: Int) -> some View {
        if row == 0 && col == 4 {
            Image(systemName: "crown.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(Color(hex: 0x9E2B25))
        } else if row == 2 && col == 2 {
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(Theme.navy)
        }
    }
}

/// Drei Aktionen, von denen genau eine dran ist.
private struct RulesSceneTurn: View {
    var body: some View {
        HStack(spacing: 10) {
            choice("crown.fill", Theme.navy, Color(hex: 0xF0D9A8))
            choice("rectangle.stack.fill", .white, Theme.blue)
            choice("sparkles", Theme.navy, Theme.gold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func choice(_ icon: String, _ ink: Color, _ fill: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 22, weight: .black))
            .foregroundColor(ink)
            .frame(width: 64, height: 64)
            .background(RoundedRectangle(cornerRadius: 16).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

/// Eine Figur und die acht Felder um sie herum.
private struct RulesSceneTerritory: View {
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { col in
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(row == 1 && col == 1 ? Theme.gold : Theme.green.opacity(0.55))
                            if row == 1 && col == 1 {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(Theme.navy)
                            }
                        }
                        .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

/// Mana füllt sich Zug für Zug, höchstens bis zum Maximum.
private struct RulesSceneMana: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<GameState.maxMana, id: \.self) { i in
                Circle()
                    .fill(i < 4 ? Theme.manaLight : Color.white.opacity(0.12))
                    .frame(width: 14, height: 14)
                    .overlay {
                        if i == 3 {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(Theme.navy)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

/// Vier Karten und eine goldene Ultimate.
private struct RulesSceneDeck: View {
    private let colors: [Color] = [Color(hex: 0xE85D4C), Theme.blueLight, Theme.green, Theme.manaLight]
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 8)
                    .fill(colors[i])
                    .frame(width: 36, height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            }
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                .frame(width: 42, height: 58)
                .overlay(Image(systemName: "sparkles").font(.system(size: 16, weight: .black)).foregroundColor(Theme.navy))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

private struct RulesSceneChests: View {
    var body: some View {
        GeometryReader { geo in
            let bases: [CGFloat] = [48, 52, 56, 60, 66]
            let spacing: CGFloat = 8
            let gaps = spacing * CGFloat(bases.count - 1)
            let natural = bases.reduce(0, +) * 1.2
            let scale = min(1, max(0, geo.size.width - gaps) / max(natural, 1))
            let sizes = bases.map { $0 * scale }
            let rarities: [ChestRarity] = [.wood, .silver, .gold, .magic, .legendary]
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(rarities.enumerated()), id: \.offset) { i, rarity in
                    ChestView(rarity: rarity, size: sizes[i])
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
}

private struct RulesSceneRoles: View {
    private let roles: [(String, Color)] = [
        ("burst.fill", Color(hex: 0xE85D4C)),
        ("snowflake", Theme.blueLight),
        ("shield.fill", Theme.green),
        ("drop.fill", Theme.manaLight),
        ("arrow.uturn.backward", Theme.gold)
    ]
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<roles.count, id: \.self) { i in
                Image(systemName: roles[i].0)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(Theme.navy)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(roles[i].1))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

private struct RulesSceneShield: View {
    var body: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Theme.blueLight, Theme.blueDark], startPoint: .top, endPoint: .bottom))
            Image(systemName: "crown.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(Theme.gold)
                .offset(y: 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
    }
}

private struct RulesSceneIcon: View {
    var icon: String
    var tint: Color
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 36, weight: .black))
            .foregroundStyle(LinearGradient(colors: [.white, tint], startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
    }
}

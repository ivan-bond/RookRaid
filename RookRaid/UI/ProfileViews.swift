import SwiftUI

struct ProfileView: View {
    @ObservedObject var store = ProfileStore.shared
    @State var showSettings = false
    @State var showStats = false
    @State var showStyle = false
    @State var styleTab: StyleSheet.StyleTab = .avatars
    @State var showAllAchievements = false
    @State var showFeedback = false

    var body: some View {
        // Ohne eigenen NavigationStack: Das Profil schiebt keine Seiten, und ein Stack in einer TabView-Seite
        // kann nach Sheets oder einem Neuaufbau leer bleiben.
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
                    if OnlineAccount.shared.status != .unavailable {
                        FriendsCard { NotificationCenter.default.post(name: .showFriends, object: nil) }
                    }
                    HallOfFameRow(onAchievements: { showAllAchievements = true })
                    BotConquestCard()
                    CollectionRingsCard(onStyle: { t in styleTab = t; showStyle = true })
                    AchievementShowcase(onShowAll: { showAllAchievements = true })
                    Button {
                        Haptics.shared.play(.select)
                        showStats = true
                    } label: { statsRow }
                        .buttonStyle(PressScaleStyle())
                    Button {
                        Haptics.shared.play(.select)
                        showFeedback = true
                    } label: { feedbackRow }
                        .buttonStyle(PressScaleStyle())
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showStats) {
            NavigationStack { StatisticsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStyle) { StyleSheet(tab: styleTab) }
        .sheet(isPresented: $showAllAchievements) { AchievementListSheet() }
        .sheet(isPresented: $showFeedback) { FeedbackView() }
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

    /// Feedback an Ivan: Bugs, Balance, Ideen (Beta).
    private var feedbackRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(hex: 0xFF7A5C), Color(hex: 0xB23A2A)], startPoint: .top, endPoint: .bottom))
                Image(systemName: "envelope.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Feedback senden"))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(L("Bugs, Balance, Ideen – Rook Raid ist in der Beta."))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0x7A2E1E).opacity(0.6), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0xFF8A6B).opacity(0.25), lineWidth: 1))
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
            ForEach(store.profile.history) { record in
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
                        Text(L("{0} · {1} Züge · {2} Karten", L(record.reason), record.moves, record.cardsPlayed))
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
    @State var legalPage: LegalPage?
    @State var editLocalName = false
    @ObservedObject private var account = OnlineAccount.shared

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let b = (info["CFBundleVersion"] as? String) ?? "?"
        return L("Rook Raid {0} (Build {1})", "\(v) \(Self.stage)", b)
    }
    /// Release stage shown next to the version (App Store versions must be plain numbers like 1.0.0). Same as APP_STAGE on the web.
    static let stage = "Beta"

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

                    settingsGroup(L("Rechtliches")) {
                        Button { legalPage = .privacy } label: {
                            settingsLink(L("Datenschutz"), "hand.raised.fill", Theme.blueLight)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button { legalPage = .imprint } label: {
                            settingsLink(L("Impressum"), "building.columns.fill", Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button { legalPage = .terms } label: {
                            settingsLink(L("Nutzungsbedingungen"), "doc.text.fill", Theme.gold)
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(L("Daten")) {
                        Text(L("Profil, Fortschritt, Verlauf und die laufende Partie liegen auf diesem iPhone. Online liegen Konto, Trophäen und Partien zusätzlich auf dem Server in Frankfurt. Mehr dazu im Datenschutz."))
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
        .fullScreenCover(item: $legalPage) { LegalDocumentView(page: $0) }
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
                // Gerätesprache: folgt dem iPhone (auch der nur für Rook Raid gewählten Sprache in den iOS-Einstellungen)
                let followsDevice = store.profile.settings.appLanguage == nil
                Button {
                    guard !followsDevice else { return }
                    Haptics.shared.play(.select)
                    store.profile.settings.appLanguage = nil
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "iphone")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Theme.blueLight)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("Gerätesprache"))
                                .font(.system(size: 16, weight: followsDevice ? .heavy : .semibold))
                                .foregroundColor(.white)
                            Text(AppLanguage.system.flag + " " + AppLanguage.system.nativeName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        if followsDevice {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Theme.green)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Gerätesprache") + (followsDevice ? ", " + L("aktiv") : ""))
                Rectangle().fill(Theme.panelHighlight).frame(height: 1).padding(.leading, 56)
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element) { i, lang in
                    let active = store.profile.settings.appLanguage == lang
                    Button {
                        guard !active else { return }
                        Haptics.shared.play(.select)
                        store.profile.settings.appLanguage = lang
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

/// Regeln: vier ruhige Reiter (Grundlagen, Karten, Kampf, Fortschritt) wie `Rules.tsx` im Web. Selten gebrauchte
/// Regeln liegen eingeklappt unter „Gut zu wissen“, damit die erste Seite nur zeigt, was neue Spieler brauchen.
/// Jede Zahl ist gegen Engine, Profil-Logik und Server (trophy_delta, maintain_matches) geprüft.
struct RulesView: View {
    @Environment(\.dismiss) var dismiss
    @State private var detail: DetailItem?
    @State private var tab: Tab = .basics
    @State private var open: String?

    private enum Tab: CaseIterable { case basics, cards, battle, progress }
    private enum Visual { case turn, mana, deck }
    private struct Line { let title: String; let text: String }
    private struct Chapter: Identifiable {
        let id: String; let title: String; let icon: String; let tint: Color
        var visual: Visual? = nil; var steps: [String] = []; var lines: [Line] = []
    }
    private struct Fold: Identifiable { let id: String; let title: String; let icon: String; let tint: Color; let notes: [String] }
    private struct Tile: Identifiable { var id: String { title }; let icon: String; let tint: Color; let title: String; let text: String }

    private func label(_ t: Tab) -> (String, String) {
        switch t {
        case .basics: return (L("Grundlagen"), "book.fill")
        case .cards: return (L("Karten"), "rectangle.stack.fill")
        case .battle: return (L("Kampf"), "bolt.fill")
        case .progress: return (L("Fortschritt"), "trophy.fill")
        }
    }

    private var basics: [Chapter] {
        [
            Chapter(id: "turn", title: L("Ablauf eines Zuges"), icon: "arrow.clockwise", tint: Theme.blueLight, visual: .turn, steps: [
                L("Zu Beginn deines Zuges bekommst du +1 Mana."),
                L("Dann wählst du eine Aktion: Schachzug, Karte oder Ultimate."),
                L("Bonuskarten und die Festung beenden deinen Zug nicht – danach folgt noch ein Figurzug.")
            ]),
            Chapter(id: "mana", title: L("Mana (maximal {0})", GameState.maxMana), icon: "drop.fill", tint: Theme.manaLight, visual: .mana, lines: [
                Line(title: L("Jeder Zug"), text: L("+1 Mana zu Beginn deines Zuges")),
                Line(title: L("Guter Zug"), text: L("+1 extra für Schlagen oder Schach – höchstens +1 pro Zug"))
            ]),
            Chapter(id: "deck", title: L("Deck"), icon: "rectangle.stack.fill", tint: Theme.blueLight, visual: .deck, lines: [
                Line(title: L("4 Karten + 1 Ultimate"), text: L("Bleiben die ganze Partie auf der Hand – es wird nicht nachgezogen.")),
                Line(title: L("Abklingzeit"), text: L("Nach dem Ausspielen lädt eine Karte {0} eigene Züge nach (Blitz {1}), bevor du sie wieder spielen kannst.", GameState.cardCooldown, CardType.lightning.cooldown))
            ])
        ]
    }

    private var more: [Fold] {
        [
            Fold(id: "territory", title: L("Gebiet"), icon: "square.grid.3x3.fill", tint: Theme.green, notes: [
                L("Jede Figur beherrscht ihr Feld und die 8 Nachbarfelder. Dein Gebiet ist heller getönt – Mana bringt es nicht.")
            ]),
            Fold(id: "safety", title: L("Schutzregeln"), icon: "shield.fill", tint: Theme.blueLight, notes: [
                L("Der König ist immun gegen Karten und Ultimates. Die Dame ist immun gegen Frost und Meteor."),
                L("Karten und Ultimates geben kein Schach."),
                L("Frost erzwingt nie ein Patt.")
            ]),
            Fold(id: "draw", title: L("Remis"), icon: "equal", tint: Color(hex: 0x8DA0C4), notes: [
                L("Durch Patt, dreifache Wiederholung, die 50-Züge-Regel oder ein angenommenes Angebot.")
            ])
        ]
    }

    private var battleTiles: [Tile] {
        [
            Tile(icon: "person.2.fill", tint: Theme.redLight, title: L("Kampf"), text: L("Ein Online-Gegner mit ähnlich vielen Trophäen. 5 Minuten pro Spieler.")),
            Tile(icon: "trophy.fill", tint: Theme.gold, title: L("Trophäen"), text: L("Gegen Stärkere gewinnst du mehr, gegen Schwächere weniger.")),
            Tile(icon: "figure.stairs", tint: Color(hex: 0xC084FC), title: L("Bot-Leiter"), text: L("Zwölf Bots der Reihe nach besiegen – für XP und Truhen."))
        ]
    }

    private var progressTiles: [Tile] {
        [
            Tile(icon: "shippingbox.fill", tint: Color(hex: 0xC084FC), title: L("Truhen"), text: L("Aus Siegen, Tageszielen, Levels und dem Trophäenpfad. Jeder Tap kann sie aufwerten.")),
            Tile(icon: "puzzlepiece.fill", tint: Theme.gold, title: L("Puzzles & XP"), text: L("Jedes gelöste Puzzle bringt XP, das Tagespuzzle einen Bonus.")),
            Tile(icon: "flame.fill", tint: Color(hex: 0xFF8A3D), title: L("Tägliche Flammen"), text: L("Ein Puzzle oder eine Partie pro Tag hält deine Serie am Leben.")),
            Tile(icon: "diamond.fill", tint: Color(hex: 0x7FE3FF), title: L("Splitter & Laden"), text: L("Sammeln und im Laden gegen Karten, Avatare und Truhen tauschen."))
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear.frame(height: 0).id("top")
                        switch tab {
                        case .basics: basicsPage { pick(.cards, proxy) }
                        case .cards: cardsPage
                        case .battle: tilesPage(battleTiles) { RulesSceneTrophies() }
                        case .progress: tilesPage(progressTiles) { RulesSceneChests() }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .id(tab)
                    .transition(.opacity)
                }
                .safeAreaInset(edge: .top, spacing: 0) { tabBar(proxy) }
            }
            .navigationTitle(L("Regeln"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
            .background(Theme.background.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .sheet(item: $detail) { item in DetailSheet(item: item) }
    }

    private func pick(_ t: Tab, _ proxy: ScrollViewProxy) {
        guard t != tab else { return }
        Haptics.shared.play(.select)
        withAnimation(.easeOut(duration: 0.2)) { tab = t }
        proxy.scrollTo("top", anchor: .top)
    }

    // MARK: Reiter (bleiben oben stehen)

    private func tabBar(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { t in
                let on = t == tab
                let (text, icon) = label(t)
                Button { pick(t, proxy) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(on ? Theme.gold : Theme.textMuted)
                        Text(text)
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundColor(on ? .white : Theme.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(on ? Theme.panelRaised : .clear)
                            .shadow(color: .black.opacity(on ? 0.35 : 0), radius: 4, y: 2)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        .frame(maxWidth: 720)
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    // MARK: Grundlagen

    @ViewBuilder private func basicsPage(showCards: @escaping () -> Void) -> some View {
        goal
        ForEach(basics) { chapterCard($0) }
        card {
            head("sparkles", L("Ultimate"), Theme.gold)
            Text(L("Lädt sich mit Mana auf und ersetzt deinen Zug. Neue Ultimates gibt es in neuen Arenen."))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: showCards) {
                HStack(spacing: 4) {
                    Text(L("Alle Karten ansehen"))
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .black))
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.blueLight)
            }
            .buttonStyle(.plain)
        }
        sectionTitle(L("Gut zu wissen"))
        VStack(spacing: 0) {
            ForEach(Array(more.enumerated()), id: \.element.id) { i, f in
                if i > 0 { Divider().overlay(Color.white.opacity(0.06)) }
                foldRow(f)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var goal: some View {
        HStack(spacing: 16) {
            RulesSceneMate()
                .rotationEffect(.degrees(-5))
                .shadow(color: .black.opacity(0.4), radius: 0, y: 5)
            VStack(alignment: .leading, spacing: 5) {
                Text(L("Ziel").uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.6)
                    .foregroundColor(Theme.gold)
                Text(L("Setze den gegnerischen König matt."))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("Schach mit Karten, Mana und Ultimates."))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(hex: 0x2A1F55), Color(hex: 0x172443)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1))
    }

    private func chapterCard(_ ch: Chapter) -> some View {
        card {
            head(ch.icon, ch.title, ch.tint)
            if let v = ch.visual {
                Group {
                    switch v {
                    case .turn: RulesSceneTurn()
                    case .mana: RulesSceneMana()
                    case .deck: RulesSceneDeck()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.15)))
            }
            ForEach(Array(ch.steps.enumerated()), id: \.offset) { i, text in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(ch.tint)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(ch.tint.opacity(0.2)))
                    Text(text)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            ForEach(ch.lines.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1).fill(ch.tint.opacity(0.55)).frame(width: 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ch.lines[i].title)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text(ch.lines[i].text)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func foldRow(_ f: Fold) -> some View {
        let on = open == f.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.shared.play(.select)
                withAnimation(.easeOut(duration: 0.2)) { open = on ? nil : f.id }
            } label: {
                HStack(spacing: 10) {
                    icon(f.icon, f.tint)
                    Text(f.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .rotationEffect(.degrees(on ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(on ? .isSelected : [])
            if on {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(f.notes, id: \.self) { n in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(f.tint).frame(width: 5, height: 5).offset(y: -2)
                            Text(n)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.leading, 54)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
    }

    // MARK: Karten

    @ViewBuilder private var cardsPage: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill").foregroundColor(Theme.blueLight)
                Text(L("Tippe auf eine Karte für alle Details."))
            }
            HStack(spacing: 6) {
                RulesBonusBadge()
                Text(L("Danach noch ein Zug"))
            }
        }
        .font(.system(size: 12.5, weight: .bold))
        .foregroundColor(Theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.blue.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.blue.opacity(0.25), lineWidth: 1))
        RulesSceneCards(onTap: { detail = .card($0) })
        sectionTitle(L("Ultimates"))
        card {
            Text(L("Lädt sich mit Mana auf und ersetzt deinen Zug. Neue Ultimates gibt es in neuen Arenen."))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            RulesSceneUlts(onTap: { detail = .ultimate($0) })
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: Kampf und Fortschritt

    @ViewBuilder private func tilesPage<V: View>(_ tiles: [Tile], @ViewBuilder banner: () -> V) -> some View {
        banner()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(RadialGradient(colors: [Theme.gold.opacity(0.14), Theme.panelRaised], center: .bottom, startRadius: 4, endRadius: 220)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        VStack(spacing: 0) {
            ForEach(Array(tiles.enumerated()), id: \.element.id) { i, x in
                if i > 0 { Divider().overlay(Color.white.opacity(0.06)) }
                HStack(spacing: 12) {
                    icon(x.icon, x.tint, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(x.title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(.white)
                        Text(x.text).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: Bausteine

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func head(_ symbol: String, _ title: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            icon(symbol, tint)
            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
        }
    }

    private func icon(_ symbol: String, _ tint: Color, size: CGFloat = 30) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3).fill(tint.opacity(0.18)))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(1.4)
            .foregroundColor(Theme.textMuted)
            .padding(.horizontal, 2)
            .padding(.top, 8)
    }
}

/// „Danach noch ein Zug“-Abzeichen (Karten, die den Zug nicht beenden).
private struct RulesBonusBadge: View {
    var body: some View {
        Image(systemName: "figure.walk")
            .font(.system(size: 8, weight: .black))
            .foregroundColor(.white)
            .frame(width: 17, height: 17)
            .background(Circle().fill(Theme.blue))
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.2))
    }
}

/// Sieg, Remis, Niederlage gegen einen gleich starken Gegner.
private struct RulesSceneTrophies: View {
    var body: some View {
        HStack(spacing: 8) {
            tile("trophy.fill", "+20", L("Sieg"), [Color(hex: 0x2F7D4A), Color(hex: 0x1D5A33)], Color(hex: 0x7CF0A2))
            tile("equal", "±0", L("Remis"), [Color(hex: 0x3B4A6B), Color(hex: 0x283350)], .white)
            tile("heart.slash.fill", "−20", L("Niederlage"), [Color(hex: 0x7D2F36), Color(hex: 0x5A1D22)], Color(hex: 0xFF8A92))
        }
        .frame(maxWidth: 300)
    }
    private func tile(_ icon: String, _ value: String, _ label: String, _ bg: [Color], _ ink: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon).font(.system(size: 15, weight: .black)).foregroundColor(.white.opacity(0.85))
            Text(value).font(.system(size: 28, weight: .black, design: .rounded)).foregroundColor(ink)
            Text(label).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundColor(.white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient(colors: bg, startPoint: .top, endPoint: .bottom)).shadow(color: .black.opacity(0.3), radius: 0, y: 3))
    }
}

/// Alle Ultimates mit Arena – antippen öffnet die Details.
private struct RulesSceneUlts: View {
    let onTap: (Ultimate) -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(Ultimate.allCases.sorted { $0.arena < $1.arena }) { u in
                Button { onTap(u) } label: {
                    CardArtImage(name: "art-ult-\(u.rawValue)", thumb: true)
                        .aspectRatio(0.78, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.gold, lineWidth: 2))
                        .shadow(color: Theme.gold.opacity(0.35), radius: 6)
                        .overlay(alignment: .bottom) {
                            Text(L("Arena {0}", u.arena))
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundColor(Theme.gold)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Theme.navy))
                                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
                                .offset(y: 7)
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(u.name)
            }
        }
        .frame(maxWidth: 320)
        .padding(.bottom, 8)
    }
}

/// Alle Karten nach Rolle sortiert, als kleine Zeilen – antippen öffnet die Details.
private struct RulesSceneCards: View {
    let onTap: (CardType) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(CardRole.allCases, id: \.self) { role in
                let cards = CardType.allCases.filter { $0.role == role }
                if !cards.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Image(systemName: role.icon).font(.system(size: 10, weight: .black))
                            Text(role.name.uppercased()).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1.1)
                        }
                        .foregroundColor(Color(hex: role.colorHex))
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            ForEach(cards) { c in row(c, roleColor: Color(hex: role.colorHex)) }
                        }
                    }
                }
            }
        }
    }
    private func row(_ c: CardType, roleColor: Color) -> some View {
        Button { onTap(c) } label: {
            HStack(spacing: 8) {
                CardArtImage(name: "art-card-\(c.rawValue)", thumb: true)
                    .frame(width: 32, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(hex: c.tier.colorHex), lineWidth: 1.5))
                    .overlay(alignment: .topLeading) { ManaDrop(text: "\(c.cost)", size: 17).offset(x: -6, y: -6) }
                Text(c.name)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if c.keepsTurn { RulesBonusBadge() }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(roleColor.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(c.name)
    }
}

/// Kleines Mattbild: der schwarze König in der Ecke wackelt, Dame und König setzen matt.
private struct RulesSceneMate: View {
    @State private var wobble = false
    private let cell: CGFloat = 24
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { col in
                        ZStack {
                            Rectangle().fill((row + col).isMultiple(of: 2) ? Color(hex: 0xF0D9A8) : Color(hex: 0xB58863))
                            piece(row: row, col: col)
                        }
                        .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.black.opacity(0.35), lineWidth: 2))
        .onAppear { wobble = true }
    }

    @ViewBuilder private func piece(row: Int, col: Int) -> some View {
        if row == 0 && col == 3 {
            PieceImage(type: .king, color: .black)
                .frame(width: cell * 0.85, height: cell * 0.85)
                .shadow(color: Color(hex: 0xE0413A), radius: 3)
                .rotationEffect(.degrees(wobble ? 10 : -10), anchor: .bottom)
                .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: wobble)
        } else if row == 1 && col == 1 {
            PieceImage(type: .queen, color: .white).frame(width: cell * 0.85, height: cell * 0.85)
        } else if row == 2 && col == 3 {
            PieceImage(type: .king, color: .white).frame(width: cell * 0.85, height: cell * 0.85)
        }
    }
}

/// Drei Aktionen, von denen genau eine dran ist.
private struct RulesSceneTurn: View {
    var body: some View {
        HStack(spacing: 10) {
            choice("crown.fill", L("Schachzug"), Theme.navy, [Color(hex: 0xF6E3B8), Color(hex: 0xD9B97A)])
            choice("rectangle.stack.fill", L("Karte"), .white, [Color(hex: 0x4A86F0), Theme.blue])
            choice("sparkles", L("Ultimate"), Theme.navy, [Color(hex: 0xFFE38A), Theme.gold])
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func choice(_ icon: String, _ label: String, _ ink: Color, _ fill: [Color]) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 22, weight: .black))
            Text(label).font(.system(size: 11, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundColor(ink)
        .frame(width: 78, height: 70)
        .background(RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: fill, startPoint: .top, endPoint: .bottom)).shadow(color: .black.opacity(0.35), radius: 0, y: 3))
    }
}

/// Mana füllt sich Zug für Zug, höchstens bis zum Maximum – der nächste Tropfen pulsiert.
private struct RulesSceneMana: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<GameState.maxMana, id: \.self) { i in
                Ellipse()
                    .fill(i < 4 ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xD7C8FF), Color(hex: 0x8B5CF6)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(i == 4 ? 0.2 : 0.1)))
                    .frame(width: 15, height: 21)
                    .shadow(color: i < 4 ? Color(hex: 0x8B5CF6).opacity(0.6) : .clear, radius: 4)
                    .overlay {
                        if i == 4 {
                            Ellipse().strokeBorder(Color(hex: 0xB9A2FF), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                                .scaleEffect(pulse ? 1.15 : 1)
                                .opacity(pulse ? 0.5 : 1)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

/// Vier echte Karten im Fächer und die goldene Ultimate.
private struct RulesSceneDeck: View {
    private let cards: [CardType] = [.lightning, .shield, .sprint, .freeze]
    var body: some View {
        HStack(alignment: .bottom, spacing: -8) {
            ForEach(Array(cards.enumerated()), id: \.offset) { i, c in
                CardArtImage(name: "art-card-\(c.rawValue)", thumb: true)
                    .frame(width: 46, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: c.tier.colorHex), lineWidth: 2))
                    .rotationEffect(.degrees(Double(i) * 7 - 10.5))
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            }
            CardArtImage(name: "art-ult-meteor", thumb: true)
                .frame(width: 54, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Theme.gold, lineWidth: 2))
                .shadow(color: Theme.gold.opacity(0.5), radius: 8)
                .padding(.leading, 22)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

/// Alle fünf Truhenarten, die sanft auf und ab wippen.
private struct RulesSceneChests: View {
    var body: some View {
        GeometryReader { geo in
            let bases: [CGFloat] = [42, 48, 54, 60, 68]
            let spacing: CGFloat = 10
            let gaps = spacing * CGFloat(bases.count - 1)
            let natural = bases.reduce(0, +) * 1.2
            let scale = min(1, max(0, geo.size.width - gaps) / max(natural, 1))
            let rarities: [ChestRarity] = [.wood, .silver, .gold, .magic, .legendary]
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(rarities.enumerated()), id: \.offset) { i, rarity in
                    ChestView(rarity: rarity, size: bases[i] * scale, glow: i >= 3 ? 0.5 : 0)
                        .modifier(RoadBob(active: true, amplitude: 3, speed: 2.4 + Double(i) * 0.2))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(height: 84)
        .frame(maxWidth: .infinity)
    }
}

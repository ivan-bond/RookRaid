import SwiftUI

struct PuzzleSession: Identifiable {
    let id = UUID()
    let vm: PuzzleViewModel
}

// MARK: - Puzzle-Übersicht (Tab)

struct PuzzleHubView: View {
    @ObservedObject var store = ProfileStore.shared
    @Binding var session: PuzzleSession?
    @State var showAdventure = false
    @State var showRush = false

    /// Die vier Puzzle-Gruppen, jede als kompakte Karte mit Fortschrittsring.
    enum PuzzleCategory: String, CaseIterable, Identifiable {
        case cards, easy, medium, hard
        var id: String { rawValue }

        var title: String {
            switch self {
            case .cards: return L("Karten-Matts")
            case .easy: return L("Leicht")
            case .medium: return L("Mittel")
            case .hard: return L("Schwer")
            }
        }

        var subtitle: String {
            switch self {
            case .cards: return L("Erst die Karte, dann das Matt")
            case .easy: return L("Klassisch · 10 XP")
            case .medium: return L("Klassisch · 20 XP")
            case .hard: return L("Klassisch · 35 XP")
            }
        }

        var icon: String {
            switch self {
            case .cards: return "rectangle.stack.fill"
            case .easy: return "1.circle.fill"
            case .medium: return "2.circle.fill"
            case .hard: return "3.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .cards: return Theme.blueLight
            case .easy: return Theme.cream
            case .medium: return Theme.gold
            case .hard: return Theme.redLight
            }
        }

        var items: [Puzzle] {
            switch self {
            case .cards: return PuzzleCatalog.all.filter { $0.isRookRaid && !$0.isTerritory }
            case .easy: return PuzzleCatalog.all.filter { $0.difficulty == 1 && !$0.isRookRaid }
            case .medium: return PuzzleCatalog.all.filter { $0.difficulty == 2 && !$0.isRookRaid }
            case .hard: return PuzzleCatalog.all.filter { $0.difficulty == 3 && !$0.isRookRaid }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenHeader(title: L("Puzzles"))
                    nextPuzzleBlock
                        .padding(.bottom, 22)
                    SectionLabel(L("Mehr Training"))
                        .padding(.bottom, 8)
                    trainList
                }
                .padding(.bottom, 16)
            }
            .modifier(BounceOnlyIfNeeded())
            .background(DS.bg.ignoresSafeArea())
            .primaryAction {
                PrimaryButton(title: store.nextPuzzle == nil ? L("Alles gelöst!") : L("Puzzles lösen"), icon: "play.fill",
                              enabled: store.nextPuzzle != nil) {
                    if let next = store.nextPuzzle { open(next, daily: false) }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdventure) { adventureSheet }
            .fullScreenCover(isPresented: $showRush) { PuzzleRushView() }
        }
    }

    // MARK: Next puzzle (redesign V2)

    /// Board thumbnail, goal, difficulty and XP, plus the level bar (puzzles are the quickest XP).
    private var nextPuzzleBlock: some View {
        let next = store.nextPuzzle
        return VStack(spacing: 0) {
            Rectangle().fill(DS.divider).frame(height: 1)
            HStack(alignment: .center, spacing: 16) {
                Button { if let next { open(next, daily: false) } } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x2A2366))
                        if let next {
                            PuzzleThumbnail(fen: next.fen)
                                .padding(8)
                        } else {
                            Image(systemName: "crown.fill").font(.system(size: 34, weight: .black)).foregroundColor(DS.gold)
                        }
                    }
                    .frame(width: 128, height: 128)
                }
                .buttonStyle(PressScaleStyle())
                .disabled(next == nil)
                .accessibilityLabel(next.map { L("Nächstes Puzzle: {0}", $0.goal.title) } ?? L("Alles gelöst!"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("NÄCHSTES PUZZLE"))
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(DS.sectionLabel)
                    Text(next?.goal.title ?? L("Alles gelöst!"))
                        .font(DS.heading(24, .black))
                        .foregroundColor(DS.text)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    if let next {
                        (Text(next.difficultyName + (next.isRookRaid ? " · " + L("mit Karten") : "")).foregroundColor(DS.textMuted)
                         + Text(store.isSolved(next) ? "" : " · " + L("+{0} XP", next.xp)).foregroundColor(DS.purple))
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(2)
                    }
                    Spacer(minLength: 6)
                    HStack {
                        Text(L("Level {0}", store.level))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(DS.text)
                        Spacer(minLength: 4)
                        Text(L("noch {0} XP", store.levelProgress.remaining))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundColor(DS.textMuted)
                            .lineLimit(1)
                    }
                    DSProgressBar(fraction: store.levelProgress.fraction, tint: DS.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DS.side)
            .padding(.vertical, 16)
            Rectangle().fill(DS.divider).frame(height: 1)
        }
    }

    /// Puzzle Rush · Daily puzzle · Adventure · Puzzle chest (5 solved puzzles fill it).
    private var trainList: some View {
        let per = ProfileStore.puzzlesPerChest
        let filled = store.profile.solvedPuzzles.count % per
        let dailyOpen = store.dailyBonusAvailable
        return ListGroup {
            Button { showRush = true } label: {
                ListRow(title: L("Puzzle-Rausch"), subtitle: L("3 Minuten, 3 Leben"),
                        trailing: store.profile.rushBest > 0 ? .value("\(store.profile.rushBest)") : .chevron) {
                    IconTile(symbol: "bolt.fill", tint: DS.flame)
                }
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityHint(store.profile.rushBest > 0 ? L("Bestwert {0}", store.profile.rushBest) : "")
            if let daily = store.dailyPuzzle {
                Button { open(daily, daily: true) } label: {
                    ListRow(title: L("Tagespuzzle"),
                            subtitle: dailyOpen ? L("+15 XP Bonus") : L("Für heute erledigt · +15 XP"),
                            trailing: dailyOpen ? .chevron : .done) {
                        IconTile(symbol: "calendar", tint: DS.gold)
                    }
                }
                .buttonStyle(RowButtonStyle())
            }
            Button {
                Haptics.shared.play(.select)
                showAdventure = true
            } label: {
                ListRow(title: L("Abenteuer"), subtitle: L("Wähle dein Abenteuer"),
                        trailing: .value("\(store.profile.solvedPuzzles.count)/\(PuzzleCatalog.all.count)")) {
                    IconTile(symbol: "map", tint: DS.purple)
                }
            }
            .buttonStyle(RowButtonStyle())
            ListRow(title: L("Rätseltruhe"), trailing: .value("\(filled)/\(per)", chevron: false), showsDivider: false) {
                ChestView(rarity: .silver, size: 34, glow: filled == per - 1 ? 0.6 : 0)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: DS.tileRadius).fill(DS.iconTile))
            } extra: {
                DSProgressBar(fraction: Double(filled) / Double(per), tint: DS.purple)
                    .padding(.top, 6)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(per - filled == 1 ? L("Nächstes Puzzle: Rätseltruhe!") : L("Noch {0} bis zur Rätseltruhe", per - filled))
        }
    }

    /// Die vier Gruppen als eigenes Fenster, jede Karte öffnet ihre Puzzles.
    private var adventureSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(PuzzleCategory.allCases) { c in
                        NavigationLink { categoryPage(c) } label: { categoryFace(c) }
                            .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.background.ignoresSafeArea()
                    RadialGradient(colors: [Color(hex: 0x6B4FD8).opacity(0.35), .clear], center: .top, startRadius: 10, endRadius: 420)
                        .ignoresSafeArea()
                }
            )
            .navigationTitle(L("Wähle dein Abenteuer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { showAdventure = false } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func categoryFace(_ c: PuzzleCategory) -> some View {
        let items = c.items
        let solved = items.filter { store.isSolved($0) }.count
        let done = solved == items.count && !items.isEmpty
        let frac = Double(solved) / Double(max(1, items.count))
        return VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [c.tint.opacity(0.55), c.tint.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                        Image(systemName: c.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 0, y: 2)
                    }
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(-6))
                    Spacer()
                    if done {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(Theme.gold)
                            .shadow(color: Theme.gold.opacity(0.7), radius: 6)
                    } else {
                        Text("\(solved)/\(items.count)")
                            .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundColor(c.tint)
                    }
                }
                Text(c.title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(c.subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                    .frame(height: 26, alignment: .top)
                ShopProgressBar(fraction: frac, tint: done ? Theme.gold : c.tint)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [c.tint.opacity(0.14), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(done ? Theme.gold.opacity(0.7) : c.tint.opacity(0.3), lineWidth: 1.5))
    }

    private func categoryPage(_ c: PuzzleCategory) -> some View {
        let items = c.items
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(c.subtitle)
                    .font(.footnote)
                    .foregroundColor(Theme.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, p in
                        PuzzleTile(puzzle: p, number: idx + 1, solved: store.isSolved(p)) {
                            showAdventure = false
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 400_000_000)
                                open(p, daily: false)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(c.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func open(_ puzzle: Puzzle, daily: Bool) {
        guard let vm = PuzzleViewModel(puzzle: puzzle, isDaily: daily) else { return }
        Haptics.shared.play(.select)
        session = PuzzleSession(vm: vm)
    }
}

// MARK: - Puzzle-Rausch

/// Drei Minuten, drei Leben: so viele Puzzles wie möglich. Erst leichte, dann mittlere, dann schwere.
/// Ein Fehler kostet ein Leben, dann kommt sofort das nächste Puzzle.
struct PuzzleRushView: View {
    @ObservedObject var store = ProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State var vm: PuzzleViewModel?
    @State var score = 0
    @State var lives = 3
    @State var remaining = 180
    @State var running = false
    @State var finished = false
    @State var newBest = false
    @State var queue: [Puzzle] = []
    @State var pop = false
    @State var timerTask: Task<Void, Never>?

    static let duration = 180

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Color(hex: 0x6B4FD8).opacity(0.4), .clear], center: .top, startRadius: 10, endRadius: 520)
                .ignoresSafeArea()
            if running || finished {
                VStack(spacing: 10) {
                    playBar
                    if let vm {
                        RushBoard(vm: vm, onSolved: solved, onFailed: failed)
                            .id(vm.puzzle.id + "\(score)-\(lives)")
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    Spacer(minLength: 0)
                }
            } else {
                startScreen
            }
            if finished { resultOverlay }
        }
        .onDisappear { timerTask?.cancel() }
    }

    private var closeButton: some View {
        Button {
            timerTask?.cancel()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.panelRaised))
        }
        .accessibilityLabel(L("Schließen"))
    }

    /// Während des Rauschs: Titel, Uhr, Leben und Punktzahl im gleichen Kapsel-Stil wie die übrigen Leisten.
    private var playBar: some View {
        VStack(spacing: 8) {
            HStack {
                closeButton
                Text(L("Puzzle-Rausch"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(Theme.gold)
                        .scaleEffect(pop ? 1.25 : 1)
                        .contentTransition(.numericText())
                    Text(L("+{0} XP", score * 3))
                        .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(Theme.manaLight)
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(Capsule().fill(Theme.panelRaised))
                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1))
            }
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60)).monospacedDigit()
                }
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(remaining <= 20 ? .white : Theme.navy)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(remaining <= 20 ? Theme.red : Theme.gold))
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < lives ? "heart.fill" : "heart")
                            .foregroundColor(i < lives ? Theme.redLight : Theme.textMuted)
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Capsule().fill(Theme.panelRaised))
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var startScreen: some View {
        VStack(spacing: 18) {
            HStack {
                closeButton
                Spacer()
            }
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(-12))
                Text(L("Puzzle-Rausch"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(L("3 Minuten · 3 Leben · erst leicht, dann schwerer.\nJedes gelöste Puzzle zählt einen Punkt und bringt 3 XP."))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    rushChip(icon: "timer", text: "3:00")
                    rushChip(icon: "heart.fill", text: "3")
                    rushChip(icon: "sparkles", text: L("+{0} XP", 3))
                }
                if store.profile.rushBest > 0 {
                    Text(L("Bestwert: {0}", store.profile.rushBest))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Theme.gold)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Capsule().fill(Theme.gold.opacity(0.16)))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(hex: 0x2A2366), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color(hex: 0x8B5CF6).opacity(0.6), lineWidth: 1.5))
            Button(L("LOS GEHT'S")) { begin() }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, textColor: Theme.navy))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func rushChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .black))
            Text(text).font(.system(size: 13, weight: .black, design: .rounded))
        }
        .foregroundColor(Theme.gold)
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(Color.black.opacity(0.28)))
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            if newBest { ConfettiView(seed: 99).ignoresSafeArea().allowsHitTesting(false) }
            VStack(spacing: 12) {
                Image(systemName: newBest ? "crown.fill" : "flag.checkered")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                Text(newBest ? L("NEUER BESTWERT!") : L("Zeit um!"))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(newBest ? Theme.gold : .white)
                    .multilineTextAlignment(.center)
                Text("\(score)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(L("gelöste Puzzles · +{0} XP", score * 3))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Text(L("Bestwert: {0}", store.profile.rushBest))
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(Theme.gold)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Theme.gold.opacity(0.16)))
                Button(L("Nochmal")) { begin() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, textColor: Theme.navy))
                    .padding(.top, 4)
                Button(L("Fertig")) { dismiss() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 48))
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: [Color(hex: 0x2A2366), Theme.panelRaised], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(newBest ? Theme.gold.opacity(0.75) : Color(hex: 0x8B5CF6).opacity(0.55), lineWidth: 1.5))
            .padding(24)
        }
    }

    // MARK: Ablauf

    private func begin() {
        score = 0
        lives = 3
        remaining = PuzzleRushView.duration
        finished = false
        newBest = false
        // Je Stufe gemischt: zuerst leicht, dann mittel, dann schwer
        let pool = PuzzleCatalog.all.filter { !$0.isTerritory }
        queue = [1, 2, 3].flatMap { d in pool.filter { $0.difficulty == d }.shuffled() }
        running = true
        next()
        Haptics.shared.play(.chestLand)
        timerTask?.cancel()
        timerTask = Task { @MainActor in
            while !Task.isCancelled && remaining > 0 && running {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard running else { return }
                remaining -= 1
                if remaining <= 10 && remaining > 0 { Haptics.shared.play(.tick) }
            }
            if running { end() }
        }
    }

    private func next() {
        guard !queue.isEmpty else { end(); return }
        let p = queue.removeFirst()
        withAnimation(.easeInOut(duration: 0.25)) { vm = PuzzleViewModel(puzzle: p, rush: true) }
    }

    private func solved() {
        guard running else { return }
        score += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) { pop = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pop = false }
            try? await Task.sleep(nanoseconds: 250_000_000)
            if running { next() }
        }
    }

    private func failed() {
        guard running else { return }
        lives -= 1
        Haptics.shared.play(.defeat)
        if lives <= 0 {
            end()
        } else {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                if running { next() }
            }
        }
    }

    private func end() {
        guard running else { return }
        running = false
        timerTask?.cancel()
        newBest = store.finishRush(score: score)
        Haptics.shared.play(newBest ? .chestBigReveal : .victory)
        SoundPlayer.shared.play(newBest ? .rewardBig : .victory)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { finished = true }
    }
}

/// Brett und Hand eines Rausch-Puzzles; meldet Lösung oder Fehler nach oben.
struct RushBoard: View {
    @ObservedObject var vm: PuzzleViewModel
    let onSolved: () -> Void
    let onFailed: () -> Void

    private var rushPrompt: some View {
        Text(PuzzleViewModel.prompt(for: vm.puzzle))
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundColor(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
            .padding(.horizontal, 12)
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height + 40
            Group {
                if wide {
                    HStack(alignment: .top, spacing: 12) {
                        PuzzleBoardView(vm: vm)
                            .modifier(ShakeEffect(animatableData: CGFloat(vm.shake)))
                            .frame(maxHeight: .infinity)
                        VStack(spacing: 8) {
                            rushPrompt
                            if vm.hasCards { PuzzleHandView(vm: vm) }
                            Spacer(minLength: 0)
                        }
                        .frame(width: min(360, geo.size.width * 0.38))
                    }
                    .padding(.trailing, 8)
                } else {
                    VStack(spacing: 8) {
                        rushPrompt
                        PuzzleBoardView(vm: vm)
                            .modifier(ShakeEffect(animatableData: CGFloat(vm.shake)))
                        if vm.hasCards {
                            PuzzleHandView(vm: vm)
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .onChange(of: vm.phase) { phase in
            switch phase {
            case .solved: onSolved()
            case .revealed: onFailed()
            default: break
            }
        }
    }
}

struct PuzzleTile: View {
    let puzzle: Puzzle
    let number: Int
    let solved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(solved
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x8B5CF6), Color(hex: 0x5B3DB8)], startPoint: .top, endPoint: .bottom)))
                    Image(systemName: solved ? "star.fill" : puzzle.tileIcon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(solved ? Theme.navy : .white)
                }
                .frame(width: 38, height: 38)
                .shadow(color: (solved ? Theme.gold : Color(hex: 0x8B5CF6)).opacity(0.5), radius: 6)
                Text("\(number)")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Text(shortGoal)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(solved ? Theme.gold.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .foregroundColor(Theme.textPrimary)
        .accessibilityLabel(L("Puzzle {0}, {1}{2}", number, puzzle.goal.title, solved ? L(", gelöst") : ""))
    }

    private var shortGoal: String { puzzle.goal.shortTitle }
}

/// Federndes Eindrücken beim Antippen.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Mini-Brett mit der Stellung eines Puzzles (aus der FEN, Sicht der Seite am Zug).
struct PuzzleThumbnail: View {
    let fen: String

    var body: some View {
        let pieces = PuzzleThumbnail.parse(fen)
        let flip = fen.split(separator: " ").dropFirst().first == "b"
        GeometryReader { geo in
            let s = geo.size.width / 8
            let colors = BoardColors.forTheme(ProfileStore.shared.profile.settings.boardTheme)
            ZStack(alignment: .topLeading) {
                ForEach(0..<64, id: \.self) { i in
                    let r = i / 8, c = i % 8
                    Rectangle()
                        .fill((r + c) % 2 == 0 ? colors.light : colors.dark)
                        .frame(width: s, height: s)
                        .offset(x: CGFloat(c) * s, y: CGFloat(r) * s)
                }
                ForEach(0..<pieces.count, id: \.self) { k in
                    let p = pieces[k]
                    let r = flip ? 7 - p.row : p.row
                    let c = flip ? 7 - p.col : p.col
                    PieceImage(type: p.type, color: p.color)
                        .frame(width: s * 0.98, height: s * 0.98)
                        .offset(x: CGFloat(c) * s + s * 0.01, y: CGFloat(r) * s + s * 0.01)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.navy, lineWidth: 3))
        .accessibilityHidden(true)
    }

    static func parse(_ fen: String) -> [(row: Int, col: Int, type: PieceType, color: PlayerColor)] {
        let placement = fen.split(separator: " ").first.map(String.init) ?? ""
        var out: [(row: Int, col: Int, type: PieceType, color: PlayerColor)] = []
        for (r, rank) in placement.split(separator: "/").prefix(8).enumerated() {
            var c = 0
            for ch in rank {
                if let n = ch.wholeNumberValue { c += n; continue }
                let type: PieceType?
                switch ch.lowercased() {
                case "k": type = .king
                case "q": type = .queen
                case "r": type = .rook
                case "b": type = .bishop
                case "n": type = .knight
                case "p": type = .pawn
                default: type = nil
                }
                if let type, c < 8 { out.append((r, c, type, ch.isUppercase ? .white : .black)) }
                c += 1
            }
        }
        return out
    }
}

// MARK: - Ein Puzzle spielen

/// Hält das aktuelle Puzzle und tauscht es bei „Nächstes Puzzle“ direkt aus.
struct PuzzlePlayer: View {
    @State var vm: PuzzleViewModel

    var body: some View {
        PuzzleView(viewModel: vm) { next in
            if let nextVM = PuzzleViewModel(puzzle: next) {
                withAnimation(.easeInOut(duration: 0.25)) { vm = nextVM }
            }
        }
        // Neue Identität je Puzzle, damit der View seinen Zustand frisch übernimmt
        .id(vm.puzzle.id)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

struct PuzzleView: View {
    @StateObject private var vm: PuzzleViewModel
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var chestToOpen: Chest?
    let onNext: (Puzzle) -> Void

    init(viewModel: PuzzleViewModel, onNext: @escaping (Puzzle) -> Void) {
        _vm = StateObject(wrappedValue: viewModel)
        self.onNext = onNext
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            GeometryReader { geo in
                let wide = geo.size.width > geo.size.height + 40
                VStack(spacing: 10) {
                    topBar
                    if wide {
                        HStack(alignment: .top, spacing: 12) {
                            PuzzleBoardView(vm: vm)
                                .modifier(ShakeEffect(animatableData: CGFloat(vm.shake)))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            VStack(spacing: 10) {
                                promptCard
                                messageLine
                                if vm.hasCards { PuzzleHandView(vm: vm) }
                                controls
                                Spacer(minLength: 0)
                            }
                            .frame(width: min(380, geo.size.width * 0.4))
                        }
                        .padding(.trailing, 8)
                    } else {
                        promptCard
                        PuzzleBoardView(vm: vm)
                            .modifier(ShakeEffect(animatableData: CGFloat(vm.shake)))
                        messageLine
                        if vm.hasCards {
                            PuzzleHandView(vm: vm)
                                .padding(.horizontal, 12)
                        }
                        controls
                        Spacer(minLength: 0)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }

            if let reward = vm.reward {
                Color.black.opacity(0.45).ignoresSafeArea()
                ConfettiView(seed: UInt64(abs(vm.puzzle.id.hashValue % 100_000) + 1)).ignoresSafeArea()
                    .allowsHitTesting(false)
                RewardPanel(puzzle: vm.puzzle, reward: reward, clean: vm.clean,
                            onNext: next, onClose: { dismiss() },
                            onOpenChest: store.pendingChests.isEmpty ? nil : { chestToOpen = store.pendingChests.first })
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: vm.reward)
        .fullScreenCover(item: $chestToOpen) { c in ChestOpeningView(start: c) }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L("Schließen"))
            Spacer()
            VStack(spacing: 1) {
                Text(vm.isDaily ? L("Tagespuzzle") : L(vm.puzzle.title))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(L("{0} · {1} XP", vm.puzzle.difficultyName, vm.puzzle.xp))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            FlameBadge(compact: true)
                .frame(width: 44)
        }
        .padding(.horizontal, 8)
    }

    private var messageLine: some View {
        Text(vm.message)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            // feste Höhe, damit das Brett bei längeren Texten nicht springt
            .frame(height: 40)
            .padding(.horizontal, 16)
            .animation(.easeOut, value: vm.message)
    }

    private var promptCard: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(vm.player == .white ? Color(hex: 0xF2EFEA) : Color(hex: 0x1B1A18))
                .overlay(Circle().strokeBorder(Theme.panelHighlight, lineWidth: 1))
                .frame(width: 18, height: 18)
            Text(PuzzleViewModel.prompt(for: vm.puzzle))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            xpChip
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
        .padding(.horizontal, 12)
    }

    /// Was dieses Puzzle gerade wert ist: volle oder halbe XP, Tagesbonus – oder schon gelöst.
    private var xpChip: some View {
        let store = ProfileStore.shared
        let solvedBefore = store.isSolved(vm.puzzle)
        let half = vm.mistakes > 0 || vm.hintUsed
        let base = solvedBefore ? 0 : (half ? vm.puzzle.xp / 2 : vm.puzzle.xp)
        let bonus = vm.isDaily && store.dailyBonusAvailable ? 15 : 0
        let total = base + bonus
        return HStack(spacing: 3) {
            Image(systemName: total > 0 ? "sparkles" : "checkmark")
                .font(.system(size: 10, weight: .black))
            Text(total > 0 ? L("+{0} XP", total) : L("Gelöst"))
                .font(.system(size: 12, weight: .black, design: .rounded))
            if half && total > 0 {
                Text("½").font(.system(size: 11, weight: .black))
            }
        }
        .foregroundColor(total > 0 ? Theme.manaText : Theme.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Capsule().fill(total > 0 ? Theme.manaLight : Theme.panelHighlight))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: half)
        .accessibilityLabel(total > 0 ? L("Belohnung {0} XP{1}", total, half ? L(", halbiert") : "") : L("Schon gelöst, keine XP"))
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                vm.showHint()
            } label: {
                Label(L("Hinweis"), systemImage: "lightbulb.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PanelButtonStyle())
            .disabled(!vm.canInteract)

            Button {
                vm.revealSolution()
            } label: {
                Label(L("Lösung"), systemImage: "eye.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(PanelButtonStyle())
            .disabled(!vm.canInteract)

            if vm.phase == .revealed {
                Button {
                    next()
                } label: {
                    Label(L("Weiter"), systemImage: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(PanelButtonStyle())
            }
        }
        .padding(.horizontal, 12)
    }

    private func next() {
        let all = PuzzleCatalog.all
        let store = ProfileStore.shared
        guard let idx = all.firstIndex(of: vm.puzzle) else { return }
        // Nächstes ungelöstes Puzzle, sonst einfach das nächste
        let rest = Array(all[(idx + 1)...]) + Array(all[..<idx])
        let target = rest.first { !store.isSolved($0) } ?? rest.first
        // Direkt weiter – ohne Umweg über die Übersicht
        if let target { onNext(target) }
    }
}

/// Hand im Rook-Raid-Puzzle: Mana, Ultimate und Karten – wie im Spiel.
struct PuzzleHandView: View {
    @ObservedObject var vm: PuzzleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ManaDrop(text: "\(vm.mana)", size: 22)
                Text(vm.mana == 1 ? L("1 Mana") : L("{0} Mana", vm.mana))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if vm.pendingCard != nil || vm.pendingUltimate {
                    Button(L("Abbrechen")) { vm.cancelPending() }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(minHeight: 32)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                if let u = vm.ultimate {
                    UltimateCard(ultimate: u, mana: vm.mana, usable: vm.ultimateUsable,
                                 isSelected: vm.pendingUltimate)
                        .frame(width: 58)
                        .overlay(hintRing(vm.hintUltimate))
                        .onTapGesture { vm.tapUltimate() }
                        .accessibilityLabel(L("Ultimate {0}", u.name))
                        .accessibilityAddTraits(.isButton)
                    if !vm.hand.isEmpty {
                        Rectangle().fill(Theme.panelHighlight).frame(width: 1, height: 50).padding(.bottom, 14)
                    }
                }
                ForEach(Array(vm.hand.enumerated()), id: \.offset) { _, card in
                    CardView(card: card, isPlayable: vm.canAfford(card) && vm.canInteract && !vm.state.bonusActionUsed,
                             isSelected: vm.pendingCard == card)
                        .frame(maxWidth: 62)
                        .overlay(hintRing(vm.hintCard == card))
                        .onTapGesture { vm.tapCard(card) }
                        .accessibilityLabel(L("{0}, {1} Mana", card.name, card.cost))
                        .accessibilityAddTraits(.isButton)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
        .overlay {
            if vm.state.bonusActionUsed && vm.phase == .playing {
                BonusMoveBanner(card: vm.state.bonusLockedSquare != nil ? .shield : .freeze)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func hintRing(_ on: Bool) -> some View {
        if on {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.gold, lineWidth: 3)
                .padding(-3)
                .allowsHitTesting(false)
        }
    }
}

/// Ergebnis nach dem Lösen: XP, Level-Aufstieg, Flamme.
struct RewardPanel: View {
    let puzzle: Puzzle
    let reward: ProfileStore.PuzzleReward
    let clean: Bool
    let onNext: () -> Void
    let onClose: () -> Void
    var onOpenChest: (() -> Void)? = nil
    @State private var shownXP = 0

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(Theme.gold)
                .padding(.top, 6)
            Text(L("Gelöst!"))
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)

            if reward.puzzleStreak >= 2 {
                PuzzleStreakBadge(count: reward.puzzleStreak)
            }

            if reward.firstSolve || reward.dailyBonus > 0 {
                VStack(spacing: 4) {
                    Text(L("+{0} XP", shownXP))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(Theme.manaLight)
                        .contentTransition(.numericText())
                    if reward.dailyBonus > 0 {
                        Text(L("inklusive {0} XP Tagesbonus", reward.dailyBonus))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    if reward.firstSolve && !clean {
                        Text(L("Halbe XP wegen Fehler oder Hinweis"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            } else {
                Text(L("Schon einmal gelöst – keine neuen XP"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }

            if let level = reward.levelUp {
                Label(L("Level {0} erreicht!", level), systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Theme.gold))
            }
            if reward.chest || reward.levelUp != nil, let onOpenChest {
                EarnedChestsRow(chests: ProfileStore.shared.pendingChests, onOpen: onOpenChest)
            }
            if let streak = reward.streakLit {
                FlameLitRow(streak: streak)
            }

            VStack(spacing: 10) {
                Button(L("Nächstes Puzzle"), action: onNext)
                    .buttonStyle(ChunkyButtonStyle())
                Button(L("Zur Übersicht"), action: onClose)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: 340)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.panelHighlight, lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 20)
        .padding(24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { shownXP = reward.xp + reward.dailyBonus }
        }
    }
}

/// „X in Folge!" – wird mit wachsender Serie größer und heißer.
struct PuzzleStreakBadge: View {
    let count: Int
    @State private var pop = false

    private var tint: Color {
        switch count {
        case ..<3: return Theme.manaLight
        case 3..<5: return Theme.gold
        case 5..<10: return Color(hex: 0xFF8A3D)
        default: return Color(hex: 0xFF4D6D)
        }
    }
    private var flames: Int { min(3, 1 + count / 4) }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: -4) {
                ForEach(0..<flames, id: \.self) { _ in
                    Image(systemName: "flame.fill")
                }
            }
            Text(L("{0} in Folge!", count))
        }
        .font(.system(size: count >= 5 ? 19 : 16, weight: .black, design: .rounded))
        .foregroundColor(Theme.background)
        .padding(.horizontal, 14)
        .frame(height: count >= 5 ? 38 : 32)
        .background(Capsule().fill(tint))
        .shadow(color: tint.opacity(count >= 5 ? 0.8 : 0.4), radius: count >= 5 ? 14 : 6)
        .scaleEffect(pop ? 1 : 0.3)
        .rotationEffect(.degrees(pop ? 0 : -12))
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) { pop = true }
            Feedback.play(nil, count >= 5 ? .chestUpgrade : .chestCharge1)
        }
    }
}

// MARK: - Brett für Puzzles

struct PuzzleBoardView: View {
    @ObservedObject var vm: PuzzleViewModel
    @ObservedObject private var store = ProfileStore.shared
    @State private var dragFrom: Square?
    @State private var dragLocation: CGPoint?
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let s = side / 8
            let colors = BoardColors.forTheme(store.profile.settings.boardTheme)
            ZStack(alignment: .topLeading) {
                let control: [PlayerColor?] = vm.showsTerritory ? vm.control : []
                ForEach(GameState.allSquares, id: \.self) { sq in
                    let owner: PlayerColor? = control.isEmpty ? nil : control[sq.index]
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(colors.color(light: sq.isLight, mine: owner.map { $0 == vm.player }))
                        if vm.isLastMoveSquare(sq) || vm.selected == sq {
                            Rectangle().fill(Color(hex: 0xF6D65A).opacity(0.45))
                        }
                        if vm.wrongSquare == sq {
                            Rectangle().fill(Theme.red.opacity(0.55))
                        }
                        if store.profile.settings.showCoordinates {
                            coordinates(sq, s, sq.isLight ? colors.dark : colors.light)
                        }
                    }
                    .frame(width: s, height: s)
                    .position(point(sq, s))
                }
                ForEach(Array(vm.cardTargets), id: \.self) { sq in
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.95), lineWidth: max(2, s * 0.06))
                        .frame(width: s, height: s)
                        .position(point(sq, s))
                        .allowsHitTesting(false)
                }
                if let h = vm.hintSquare {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Theme.gold, lineWidth: max(3, s * 0.08))
                        .frame(width: s, height: s)
                        .position(point(h, s))
                }
                pieces(s)
                ForEach(Array(vm.targets.enumerated()), id: \.offset) { _, m in
                    Group {
                        if vm.state[m.to] != nil || m.isEnPassant {
                            Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: s * 0.09)
                        } else {
                            Circle().fill(Color.black.opacity(0.2)).frame(width: s * 0.3, height: s * 0.3)
                        }
                    }
                    .frame(width: s, height: s)
                    .position(point(m.to, s))
                    .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .contentShape(Rectangle())
            .gesture(gesture(s))
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 6)
    }

    private func pieces(_ s: CGFloat) -> some View {
        let items: [PieceItem] = GameState.allSquares.compactMap { sq in
            guard let p = vm.state[sq] else { return nil }
            return PieceItem(id: p.id, square: sq, piece: p)
        }
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                let isDragged = dragging && dragFrom == item.square
                PieceSprite(piece: item.piece, ply: vm.state.ply, size: s, locked: vm.state.isBonusLocked(item.square))
                    .frame(width: s, height: s)
                    .scaleEffect(isDragged ? 1.2 : 1)
                    .position(isDragged ? (dragLocation ?? point(item.square, s)) : point(item.square, s))
                    .zIndex(isDragged ? 10 : 1)
                    .animation(isDragged ? nil : .easeOut(duration: 0.2), value: item.square)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func coordinates(_ sq: Square, _ s: CGFloat, _ color: Color) -> some View {
        let displayCol = vm.flipped ? 7 - sq.col : sq.col
        let displayRow = vm.flipped ? 7 - sq.row : sq.row
        ZStack {
            if displayCol == 0 {
                Text("\(8 - sq.row)")
                    .font(.system(size: s * 0.18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, s * 0.05)
            }
            if displayRow == 7 {
                Text(Square.files[sq.col])
                    .font(.system(size: s * 0.18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, s * 0.05)
            }
        }
        .frame(width: s, height: s)
    }

    private func point(_ sq: Square, _ s: CGFloat) -> CGPoint {
        let r = vm.flipped ? 7 - sq.row : sq.row
        let c = vm.flipped ? 7 - sq.col : sq.col
        return CGPoint(x: (CGFloat(c) + 0.5) * s, y: (CGFloat(r) + 0.5) * s)
    }

    private func square(at p: CGPoint, _ s: CGFloat) -> Square? {
        guard p.x >= 0, p.y >= 0 else { return nil }
        let c = Int(p.x / s)
        let r = Int(p.y / s)
        guard (0..<8).contains(c), (0..<8).contains(r) else { return nil }
        return vm.flipped ? Square(row: 7 - r, col: 7 - c) : Square(row: r, col: c)
    }

    private func gesture(_ s: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                if dragFrom == nil { dragFrom = square(at: v.startLocation, s) }
                guard let from = dragFrom else { return }
                if !dragging && hypot(v.translation.width, v.translation.height) > 8 && vm.canDrag(from: from) {
                    dragging = true
                    vm.beginDrag(at: from)
                }
                if dragging { dragLocation = v.location }
            }
            .onEnded { v in
                if dragging, let from = dragFrom {
                    if let to = square(at: v.location, s) { vm.drop(from: from, to: to) }
                } else if let sq = square(at: v.location, s) {
                    vm.tap(sq)
                }
                dragFrom = nil
                dragging = false
                dragLocation = nil
            }
    }
}

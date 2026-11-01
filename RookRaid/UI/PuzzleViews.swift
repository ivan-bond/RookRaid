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
            ZStack {
                Theme.background.ignoresSafeArea()
                // Leuchtender Himmel oben: Puzzles sind der Denksport-Bereich – lila/blau
                RadialGradient(colors: [Color(hex: 0x6B4FD8).opacity(0.35), .clear], center: .top, startRadius: 10, endRadius: 520)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        heroCard
                        chestMeter
                        HStack(spacing: 12) {
                            if let daily = store.dailyPuzzle { dailyCard(daily) }
                            rushCard
                        }
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAdventure) { adventureSheet }
            .fullScreenCover(isPresented: $showRush) { PuzzleRushView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xC9B8FF), Color(hex: 0x8B5CF6)], startPoint: .top, endPoint: .bottom))
                        .rotationEffect(.degrees(-12))
                    Text(L("Puzzles"))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                FlameBadge()
            }
            // Level und XP: Puzzles sind die schnellste XP-Quelle
            HStack(spacing: 10) {
                LevelBadge(level: store.level, progress: store.levelProgress.fraction)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(L("Level {0}", store.level))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text(L("{0} XP · noch {1}", store.profile.xp, store.levelProgress.remaining))
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(Theme.manaLight)
                    }
                    ShopProgressBar(fraction: store.levelProgress.fraction, tint: Theme.manaLight)
                        .frame(height: 8)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
        }
    }

    /// Großes „Nächstes Puzzle“: Mini-Brett mit der echten Stellung, Ziel, Sterne, XP, ein dicker Los-Knopf
    /// und der Eingang zu den vier Abenteuern.
    private var heroCard: some View {
        let next = store.nextPuzzle
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    if let next {
                        FloatingThumbnail(fen: next.fen)
                            .frame(width: 118, height: 118)
                    }
                }
                .frame(width: 124, height: 124)
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("NÄCHSTES PUZZLE"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(Color(hex: 0xC9B8FF))
                    Text(next?.goal.title ?? L("Alles gelöst!"))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let next {
                        HStack(spacing: 2) {
                            ForEach(1...3, id: \.self) { i in
                                Image(systemName: i <= next.difficulty ? "star.fill" : "star")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(i <= next.difficulty ? Theme.gold : Theme.textMuted)
                            }
                            Text(next.difficultyName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .padding(.leading, 4)
                        }
                        HStack(spacing: 6) {
                            if next.isRookRaid {
                                chip(L("mit Karten"), icon: "rectangle.stack.fill", color: Theme.blueLight)
                            }
                            if !store.isSolved(next) {
                                chip(L("+{0} XP", next.xp), icon: "sparkles", color: Theme.manaLight)
                            }
                        }
                    }
                    if store.profile.puzzleStreak > 0 {
                        chip(L("{0} in Folge", store.profile.puzzleStreak), icon: "flame.fill", color: FlameStyle.glow)
                    }
                }
                Spacer(minLength: 0)
            }
            Button {
                if let next { open(next, daily: false) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(L("LOS GEHT'S"))
                }
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [Color(hex: 0x8B5CF6), Color(hex: 0x6B3FD0)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color(hex: 0x3E2490), radius: 0, y: 5)
                )
                .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 14)).allowsHitTesting(false))
            }
            .buttonStyle(PressScaleStyle())
            .disabled(next == nil)
            Button {
                Haptics.shared.play(.select)
                showAdventure = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .foregroundColor(Color(hex: 0xC9B8FF))
                    Text(L("Wähle dein Abenteuer"))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Text(L("{0} von {1} gelöst", store.profile.solvedPuzzles.count, PuzzleCatalog.all.count))
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Theme.textMuted)
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(hex: 0x2A2366), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(hex: 0x8B5CF6).opacity(0.6), lineWidth: 1.5))
    }

    private func chip(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
            Text(text).font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(color.opacity(0.16)))
    }

    /// Fünf Puzzleteile bis zur Rätseltruhe – jedes gelöste Puzzle setzt eins ein.
    private var chestMeter: some View {
        let per = ProfileStore.puzzlesPerChest
        let filled = store.profile.solvedPuzzles.count % per
        let text = per - filled == 1 ? L("Nächstes Puzzle: Rätseltruhe!") : L("Noch {0} bis zur Rätseltruhe", per - filled)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(0..<per, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(i < filled ? Color(hex: 0x8B5CF6).opacity(0.3) : Color.white.opacity(0.05))
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(i < filled ? Color(hex: 0xC9B8FF) : Color.white.opacity(0.15),
                                          style: StrokeStyle(lineWidth: 1.5, dash: i < filled ? [] : [4, 3]))
                        Image(systemName: "puzzlepiece.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(i < filled ? Color(hex: 0xE4DBFF) : Theme.textMuted.opacity(0.5))
                            .rotationEffect(.degrees(Double(i) * 90))
                    }
                    .frame(width: 34, height: 34)
                }
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Theme.textMuted)
                ChestView(rarity: .silver, size: 36, glow: filled == per - 1 ? 0.7 : 0.2)
                Spacer(minLength: 0)
            }
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(filled == per - 1 ? Theme.gold : Theme.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    private func dailyCard(_ puzzle: Puzzle) -> some View {
        let open = store.dailyBonusAvailable
        return Button {
            self.open(puzzle, daily: true)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    PuzzleThumbnail(fen: puzzle.fen)
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-6))
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
                    Image(systemName: open ? "sparkles" : "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(open ? Theme.gold : Theme.green)
                        .offset(x: 12, y: -8)
                }
                .frame(height: 74)
                Text(L("Tagespuzzle"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(open ? L("+15 XP Bonus") : L("Erledigt ✓"))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(open ? Theme.navy : Theme.textMuted)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(open ? Theme.gold : Color.white.opacity(0.06)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color(hex: open ? 0x5C4413 : 0x2A3348), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(open ? Theme.gold.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle())
    }

    private var rushCard: some View {
        Button { showRush = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Circle().fill(Theme.red.opacity(0.25)).frame(width: 70, height: 70)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE066), Color(hex: 0xFF7A2F)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Color(hex: 0xFF7A2F).opacity(0.8), radius: 10)
                        .rotationEffect(.degrees(8))
                }
                .frame(height: 74)
                Text(L("Puzzle-Rausch"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(store.profile.rushBest > 0 ? L("Bestwert {0}", store.profile.rushBest) : L("3 Minuten, 3 Leben"))
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(Theme.redLight)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(Theme.red.opacity(0.18)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color(hex: 0x5A1A22), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.red.opacity(0.6), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle())
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
                        .frame(width: s * 0.94, height: s * 0.94)
                        .offset(x: CGFloat(c) * s + s * 0.03, y: CGFloat(r) * s + s * 0.03)
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

/// Mini-Brett, das sanft schwebt und kippt (zeitgesteuert, keine Endlos-Animation).
struct FloatingThumbnail: View {
    @Environment(\.liveAnimations) private var live
    let fen: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            PuzzleThumbnail(fen: fen)
                .rotationEffect(.degrees(-5 + sin(t * 1.2) * 2))
                .offset(y: CGFloat(sin(t * 1.6)) * 3)
                .shadow(color: Color(hex: 0x8B5CF6).opacity(0.55), radius: 14, y: 6)
        }
    }
}

/// Level, XP und Fortschrittsbalken.
struct LevelCard: View {
    @ObservedObject private var store = ProfileStore.shared

    var body: some View {
        let progress = store.levelProgress
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.panelHighlight, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress.fraction)
                    .stroke(Theme.mana, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text(L("LVL"))
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(store.level)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("{0} XP", store.profile.xp))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(L("noch {0} XP bis Level {1}", progress.remaining, store.level + 1))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.panelHighlight)
                        Capsule().fill(Theme.mana).frame(width: max(6, geo.size.width * progress.fraction))
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
        .animation(.easeOut(duration: 0.5), value: store.profile.xp)
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

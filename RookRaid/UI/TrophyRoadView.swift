import SwiftUI

// MARK: - Trophäenpfad (Tab „Pfad“)
//
// Ein gewundener Weg nach oben durch sechs Welten – unten das grüne Trainingsgelände, ganz oben der verschneite
// Königsgipfel, wo die Turmkönigin thront. Jede Arena hat ihr gemaltes Bild (Wiese, Kaserne, Thron, Sturm,
// Drachenhort, Gipfel) und eigene Teilchen (Glühwürmchen, Staub, Funkeln, Regen, Glut, Schnee).
// Der Weg glüht golden, so weit du gekommen bist, und funkelt in deiner Arena. Die Gegner stehen als
// Königsfigur ihres Figurensets am Weg – noch nicht erreichte nur als Schatten mit Fragezeichen.
// Bereite Truhen wackeln und hüpfen, gesperrte verraten beim Antippen, wie viele Trophäen noch fehlen.
// Oben zeigt eine Weltkarte alle sechs Arenen (antippen springt hin), unten rechts bringt „Zu mir“ zurück.
//
// Alle Dauerbewegungen laufen über Zeitleisten (TimelineView) statt über Endlos-Animationen,
// damit nichts anderes auf dem Bildschirm mitschwingt.

struct TrophyRoadView: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    @ObservedObject var store = ProfileStore.shared
    @State var chestToOpen: Chest?
    @State var toast: RoadToast?
    @State var bounce: Int?
    @State var burst: UInt64?
    /// Gesperrte Belohnung, die gerade angetippt wurde (zeigt kurz „noch X“).
    @State var peek: Int?
    @State var showGuide = false

    struct RoadToast: Equatable {
        var shards = 0
        var board: BoardTheme?
    }

    /// Ein Punkt auf dem Weg innerhalb einer Arena.
    struct TrailItem: Identifiable {
        enum Kind { case step(RoadStep), bot(BotLevel), you(Int) }
        let kind: Kind
        let trophies: Int
        let order: Int

        var id: String {
            switch kind {
            case .step(let s): return "s\(s.trophies)"
            case .bot(let b): return "b\(b.tier)"
            case .you: return "you"
            }
        }
    }

    private let rowHeight: CGFloat = 108

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [arenaColors(store.arena.number)[1].opacity(0.55), Theme.background, Theme.background],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        header(proxy)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 10)
                            .background(
                                Theme.background.opacity(0.94)
                                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                                    .ignoresSafeArea(edges: .top)
                            )
                            .zIndex(1)
                        GeometryReader { geo in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(spacing: 0) {
                                    summitCap
                                    ForEach(Arena.all.reversed()) { arena in
                                        arenaSection(arena, width: geo.size.width)
                                    }
                                    startCap
                                }
                                .frame(width: geo.size.width)
                            }
                            .overlay(alignment: .bottomTrailing) { jumpButton(proxy) }
                            .onAppear { scrollToFocus(proxy) }
                        }
                    }
                }
                if let toast { toastView(toast) }
                if let burst {
                    ConfettiView(seed: burst)
                        .ignoresSafeArea()
                        .id(burst)
                        .allowsHitTesting(false)
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $chestToOpen) { c in ChestOpeningView(start: c) }
            .fullScreenCover(isPresented: $showGuide) { pathGuide }
        }
    }

    /// Kurz erklärt, wie Belohnungen und Arenen auf dem Pfad funktionieren.
    private var pathGuide: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    pathClimb
                    pathGuideCard(title: L("Trophäenpfad"), tint: Theme.gold, art: {
                        HStack(spacing: 4) {
                            ForEach(Arena.all) { arena in
                                VStack(spacing: 4) {
                                    arenaMedal(arena, reached: true, size: 32)
                                    Text("\(arena.number)")
                                        .font(.system(size: 10, weight: .black, design: .rounded))
                                        .foregroundColor(Theme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }, text: {
                        Text(L("Sechs Arenen führen nach oben. Tippe ein Wappen, um dorthin zu springen."))
                    })
                    pathGuideCard(title: L("Truhen"), tint: Color(hex: 0xC084FC), art: {
                        pathChests
                    }, text: {
                        Text(L("Alle 50 bis 150 Trophäen wartet eine Belohnung: Truhen, Splitter, Sammelbretter und an jeder neuen Arena eine Magische oder Legendäre Truhe. Abgerechnet wird nach deinem Rekord – wer abrutscht, behält seine Stufen."))
                    })
                    pathGuideCard(title: L("Rekord"), tint: Theme.gold, art: {
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 36, weight: .black))
                                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                                Text(L("Rekord"))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.gold)
                            }
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(Theme.textMuted)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("2100")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.gold)
                                Text("1800")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "gift.fill")
                                .font(.system(size: 28, weight: .black))
                                .foregroundColor(Theme.green)
                        }
                    }, text: {
                        Text(L("Auf dem Trophäenpfad zählt dein Rekord – wer abrutscht, behält seine Belohnungen."))
                    })
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle(L("So funktioniert der Pfad"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { showGuide = false } }
            }
        }
        .background(
            ZStack {
                Theme.background.ignoresSafeArea()
                RadialGradient(colors: [Theme.gold.opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 420)
                    .ignoresSafeArea()
            }
        )
        .preferredColorScheme(.dark)
    }

    /// Truhenreihe, die in die Kartenbreite schrumpft. Jede Truhe ist breiter als ihre Nenngröße.
    private var pathChests: some View {
        GeometryReader { geo in
            let bases: [CGFloat] = [52, 58, 64, 70]
            let spacing: CGFloat = 8
            let icons: CGFloat = 28
            let gaps = spacing * CGFloat(bases.count)
            let natural = bases.reduce(0, +) * 1.2
            let room = max(0, geo.size.width - icons - gaps)
            let scale = min(1, room / max(natural, 1))
            let sizes = bases.map { $0 * scale }
            let rarities: [ChestRarity] = [.wood, .gold, .magic, .legendary]
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(rarities.enumerated()), id: \.offset) { i, rarity in
                    ChestView(rarity: rarity, size: sizes[i])
                }
                Spacer(minLength: 4)
                VStack(spacing: 6) {
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(Color(hex: 0x7FE3FF))
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Theme.gold)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 84)
    }

    /// Sechs Arenen als aufsteigender Weg, von unten links nach oben rechts.
    private var pathClimb: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Arena.all) { arena in
                if arena.number > 1 {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.gold.opacity(0.35), Theme.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 4)
                        .padding(.bottom, 22 + CGFloat(arena.number - 1) * 8)
                }
                VStack(spacing: 4) {
                    arenaMedal(arena, reached: true, size: arena.number == 6 ? 46 : 34)
                    Text("\(arena.number)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, CGFloat(arena.number - 1) * 16)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 168)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(hex: 0x3A2A12), Theme.panelRaised], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5))
    }

    private func pathGuideCard<Art: View, Copy: View>(title: String, tint: Color, @ViewBuilder art: () -> Art, @ViewBuilder text: () -> Copy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
            art()
            text()
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.4), lineWidth: 1))
    }

    private func scrollToFocus(_ proxy: ScrollViewProxy) {
        let first = store.claimableRoadSteps.first
        let id = first.map { s in s.arena.map { "a\($0.number)" } ?? "s\(s.trophies)" } ?? "you"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            proxy.scrollTo(id, anchor: .center)
        }
    }

    // MARK: Kopf

    private func header(_ proxy: ScrollViewProxy) -> some View {
        let ready = store.claimableRoadSteps.count
        let arena = store.arena
        let colors = arenaColors(arena.number)
        return VStack(alignment: .leading, spacing: 10) {
            // Kopf im Stil von Puzzles und Deck: schräges Symbol mit Verlauf und großer Titel
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(-12))
                Text(L("Pfad"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Button {
                    Haptics.shared.play(.select)
                    showGuide = true
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.gold)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("So funktioniert der Pfad"))
                Spacer(minLength: 8)
                trophyPill
                    .fixedSize()
            }
            // Deine Arena als Band über der Weltkarte
            HStack(spacing: 6) {
                Image(systemName: arena.icon)
                    .font(.system(size: 11, weight: .black))
                Text(L("ARENA {0} · {1}", arena.number, arena.name.uppercased()))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(colors[0])
            worldMap(proxy)
            if ready > 0 {
                claimButton(ready)
                    .transition(.scale.combined(with: .opacity))
            } else if let next = store.nextRoadStep {
                nextRewardBar(next)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: ready)
    }

    private var trophyPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
            Text("\(store.profile.trophies)")
                .foregroundColor(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.system(size: 18, weight: .black, design: .rounded))
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Capsule().fill(Theme.panelRaised))
        .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1.5))
        .accessibilityLabel(L("{0} Trophäen", store.profile.trophies))
    }

    /// Mini-Weltkarte: alle sechs Arenen als Wappen auf einer Linie. Antippen springt zur Arena.
    private func worldMap(_ proxy: ScrollViewProxy) -> some View {
        let current = store.arena.number
        return HStack(spacing: 0) {
            ForEach(Arena.all) { a in
                let reached = store.roadTrophies >= a.trophies
                if a.number > 1 {
                    Capsule()
                        .fill(reached ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Color(hex: 0xFFB648)], startPoint: .leading, endPoint: .trailing))
                                      : AnyShapeStyle(Color.white.opacity(0.1)))
                        .frame(height: 4)
                }
                Button {
                    Haptics.shared.play(.select)
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { proxy.scrollTo("a\(a.number)", anchor: .center) }
                } label: {
                    arenaMedal(a, reached: reached, size: a.number == current ? 34 : 26)
                        .overlay(alignment: .bottom) {
                            if a.number == current {
                                Circle().fill(Theme.blueLight).frame(width: 7, height: 7).offset(y: 7)
                            }
                        }
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(L("ARENA {0}", a.number) + ", " + a.name)
            }
        }
        .frame(height: 40)
    }

    private func claimButton(_ ready: Int) -> some View {
        Button(action: claimAll) {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 18, weight: .black))
                    .modifier(RoadBob(active: true, amplitude: 2.5, speed: 6))
                Text(ready == 1 ? L("BELOHNUNG ABHOLEN") : L("ALLE {0} ABHOLEN", ready))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .black))
            }
            .padding(.horizontal, 16)
        }
        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 48, textColor: Theme.navy))
        .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
        .modifier(PulseGlow(color: Theme.gold, active: true))
    }

    private func nextRewardBar(_ next: RoadStep) -> some View {
        let prev = ProfileStore.road.last { $0.trophies < next.trophies }?.trophies ?? 0
        let frac = Double(store.roadTrophies - prev) / Double(max(1, next.trophies - prev))
        return HStack(spacing: 10) {
            rewardIcon(next.reward, size: 34)
                .frame(width: 38, height: 38)
                .modifier(Jiggle(active: true, amplitude: 4, period: 1.4))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L("Nächste Belohnung: {0}", next.reward.title))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text(L("noch {0}", next.trophies - store.roadTrophies))
                        .font(.system(size: 12, weight: .heavy).monospacedDigit())
                        .foregroundColor(Theme.gold)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.gold, Color(hex: 0xFFB648)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, max(0.04, frac)))
                            .overlay(ShineSweep().clipShape(Capsule()))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1))
    }

    /// Rundes Arena-Wappen in den Farben der Arena (gesperrt: grau mit Schloss).
    private func arenaMedal(_ arena: Arena, reached: Bool, size: CGFloat) -> some View {
        let colors = arenaColors(arena.number)
        return ZStack {
            Circle()
                .fill(LinearGradient(colors: reached ? [colors[0], colors[1]] : [Theme.panelRaised, Theme.panel],
                                     startPoint: .top, endPoint: .bottom))
            Circle()
                .strokeBorder(reached ? Color.white.opacity(0.85) : Theme.panelHighlight, lineWidth: max(1.5, size * 0.06))
            Image(systemName: reached ? arena.icon : "lock.fill")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundColor(reached ? .white : Theme.textMuted)
                .shadow(color: .black.opacity(0.3), radius: 0, y: 1.5)
        }
        .frame(width: size, height: size)
    }

    private func jumpButton(_ proxy: ScrollViewProxy) -> some View {
        Button {
            Haptics.shared.play(.select)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { proxy.scrollTo("you", anchor: .center) }
        } label: {
            HStack(spacing: 6) {
                PlayerAvatar(size: 28)
                Text(L("Zu mir"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .frame(height: 38)
            .background(Capsule().fill(Theme.blue))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
        }
        .buttonStyle(PressScaleStyle())
        .padding(.trailing, 14)
        .padding(.bottom, 14)
    }

    // MARK: Gipfel und Start

    private var summitCap: some View {
        let top = ProfileStore.road.last?.trophies ?? 2400
        let atTop = store.arena.number == (Arena.all.last?.number ?? 6)
        return VStack(spacing: 6) {
            ZStack {
                LightRays(color: Theme.gold, count: 12, speed: 0.2, paused: !atTop)
                    .frame(width: 240, height: 200)
                    .opacity(0.55)
                // Die Turmkönigin wartet ganz oben – in ihrem goldenen Figurenset
                PieceImage(type: .queen, color: .white, skin: .queen)
                    .frame(width: 92, height: 92)
                    .shadow(color: Theme.gold.opacity(0.9), radius: 16)
                    .modifier(RoadBob(active: true, amplitude: 4, speed: 1.6))
                Image(systemName: "crown.fill")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.gold.opacity(0.7), radius: 10)
                    .offset(y: -66)
            }
            .frame(height: 180)
            Text(L("Der Gipfel: {0} Trophäen", top))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(Theme.gold)
                .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
            Text(L("Hier oben thront die Turmkönigin. Schaffst du es bis zu ihr?"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(BiomeBackdrop(arena: 6, colors: arenaColors(6), reached: atTop, animated: atTop))
    }

    /// Start ganz unten: karierte Startlinie.
    private var startCap: some View {
        VStack(spacing: 6) {
            Canvas { ctx, size in
                let n = Int(size.width / 12)
                for i in 0..<n {
                    for row in 0..<2 where (i + row) % 2 == 0 {
                        ctx.fill(Path(CGRect(x: CGFloat(i) * 12, y: CGFloat(row) * 12, width: 12, height: 12)), with: .color(.white.opacity(0.85)))
                    }
                }
            }
            .frame(width: 168, height: 24)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(L("START"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
        }
        .padding(.top, 8)
        .padding(.bottom, 90)
        .frame(maxWidth: .infinity)
        .background(BiomeBackdrop(arena: 1, colors: arenaColors(1), reached: true, animated: store.arena.number <= 2))
    }

    // MARK: Arena-Abschnitt (Landschaft + Weg + Tor)

    private func arenaSection(_ arena: Arena, width w: CGFloat) -> some View {
        let n = arena.number
        // Teilchen bewegen sich nur in deiner und den beiden Nachbar-Arenen
        let lively = abs(n - store.arena.number) <= 1
        return VStack(spacing: 0) {
            trail(arena, width: w)
            arenaGate(arena)
                .id("a\(n)")
        }
        .background(BiomeBackdrop(arena: n, colors: arenaColors(n), reached: store.roadTrophies >= arena.trophies, animated: lively))
    }

    // MARK: Weg innerhalb einer Arena

    private func range(of arena: Arena) -> Range<Int> {
        let next = Arena.all.first { $0.number == arena.number + 1 }?.trophies ?? Int.max
        return arena.trophies..<next
    }

    /// Punkte des Wegs in einer Arena, aufsteigend nach Trophäen.
    private func items(in arena: Arena) -> [TrailItem] {
        let r = range(of: arena)
        var list: [TrailItem] = ProfileStore.road
            .filter { $0.arena == nil && r.contains($0.trophies) }
            .map { TrailItem(kind: .step($0), trophies: $0.trophies, order: 1) }
        for b in BotLevel.allCases.dropFirst() {
            let t = b.trophyStart
            if r.contains(t) { list.append(TrailItem(kind: .bot(b), trophies: t, order: 0)) }
        }
        let me = store.profile.trophies
        if r.contains(me) { list.append(TrailItem(kind: .you(me), trophies: me, order: 2)) }
        return list.sorted { ($0.trophies, $0.order) < ($1.trophies, $1.order) }
    }

    private func trail(_ arena: Arena, width w: CGFloat) -> some View {
        let list = items(in: arena)
        let n = list.count
        let height = CGFloat(n) * rowHeight + 30
        // Mitte der Zeilen, von unten nach oben; abwechselnd links und rechts
        let points: [CGPoint] = (0..<n).map { i in
            CGPoint(x: w * (i % 2 == 0 ? 0.3 : 0.7), y: height - 12 - (CGFloat(i) + 0.5) * rowHeight)
        }
        let r = range(of: arena)
        let isTop = arena.number == (Arena.all.last?.number ?? 6)
        // Wegpunkte inklusive Ein- und Ausgang (Mitte unten → … → Mitte oben)
        var road: [(CGPoint, Int)] = [(CGPoint(x: w / 2, y: height), r.lowerBound)]
        road += zip(points, list).map { ($0, $1.trophies) }
        if !isTop { road.append((CGPoint(x: w / 2, y: 0), r.upperBound)) }
        let progress = store.roadTrophies
        let isCurrent = store.arena.number == arena.number

        return ZStack(alignment: .topLeading) {
            // Nur in deiner Arena wandern Funken über den goldenen Weg
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isCurrent || !live)) { tl in
                let phase = isCurrent ? CGFloat(clock.time(tl.date) * 22) : 0
                Canvas { ctx, _ in
                    TrophyRoadView.drawRoad(ctx, road: road, progress: progress, phase: phase)
                }
            }
            .frame(width: w, height: height)
            .allowsHitTesting(false)

            ForEach(Array(list.enumerated()), id: \.element.id) { i, item in
                let p = points[i]
                let leftSide = i % 2 == 0
                trailNode(item)
                    .position(p)
                    .id(item.id)
                trailLabel(item, leading: leftSide)
                    .frame(width: w * 0.5 - 20, alignment: leftSide ? .leading : .trailing)
                    // Ruhende Beschriftung mit mehreren Textschatten als ein einziges Bild zeichnen: Beim Wisch
                    // und Scrollen wird es nur verschoben statt jeder Schatten neu berechnet. Der Rand hält die
                    // Schatten im Bild.
                    .padding(4)
                    .drawingGroup()
                    .padding(-4)
                    .position(x: leftSide ? p.x + 46 + (w * 0.5 - 20) / 2 : p.x - 46 - (w * 0.5 - 20) / 2, y: p.y)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: w, height: height)
    }

    /// Straße: dunkler Rand, Pflaster, goldener Teil bis zu deinem Fortschritt mit wandernden Lichtpunkten.
    static func drawRoad(_ ctx: GraphicsContext, road: [(CGPoint, Int)], progress: Int, phase: CGFloat) {
        guard road.count > 1 else { return }
        for i in 0..<(road.count - 1) {
            let (a, ta) = road[i]
            let (b, tb) = road[i + 1]
            var seg = Path()
            seg.move(to: a)
            let midY = (a.y + b.y) / 2
            seg.addCurve(to: b, control1: CGPoint(x: a.x, y: midY), control2: CGPoint(x: b.x, y: midY))
            ctx.stroke(seg, with: .color(Color.black.opacity(0.4)), style: StrokeStyle(lineWidth: 26, lineCap: .round))
            ctx.stroke(seg, with: .color(Theme.panelRaised), style: StrokeStyle(lineWidth: 18, lineCap: .round))
            ctx.stroke(seg, with: .color(Color.white.opacity(0.05)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            let f = tb > ta ? min(1, max(0, Double(progress - ta) / Double(tb - ta))) : (progress >= tb ? 1 : 0)
            if f > 0 {
                let gold = seg.trimmedPath(from: 0, to: f)
                ctx.stroke(gold, with: .color(Theme.gold.opacity(0.35)), style: StrokeStyle(lineWidth: 30, lineCap: .round))
                ctx.stroke(gold, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE38A), Theme.gold, Color(hex: 0xE09A2C)]),
                                                       startPoint: a, endPoint: b),
                           style: StrokeStyle(lineWidth: 18, lineCap: .round))
                ctx.stroke(gold, with: .color(Color.white.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [3, 13], dashPhase: -phase))
            }
            if f < 1 {
                let rest = seg.trimmedPath(from: f, to: 1)
                ctx.stroke(rest, with: .color(Color.white.opacity(0.14)), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [2, 10]))
            }
        }
    }

    // MARK: Knoten

    @ViewBuilder
    private func trailNode(_ item: TrailItem) -> some View {
        switch item.kind {
        case .step(let step): stepNode(step)
        case .bot(let bot): botNode(bot)
        case .you: youNode
        }
    }

    private func stepNode(_ step: RoadStep) -> some View {
        let reached = store.isReached(step)
        let claimed = store.isClaimed(step)
        let ready = reached && !claimed
        let isChest: Bool = { if case .chest = step.reward { return true }; return false }()
        return Button {
            if ready { claim(step) } else if !claimed { peekAt(step) }
        } label: {
            ZStack {
                if ready {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.gold.opacity(0.75), .clear], center: .center, startRadius: 10, endRadius: 56))
                        .frame(width: 112, height: 112)
                        .modifier(RoadBreathe(active: true))
                }
                Circle()
                    .fill(LinearGradient(colors: ready ? [Color(hex: 0x5A4614), Color(hex: 0x2A2110)] : [Theme.panelRaised, Theme.panel],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 70, height: 70)
                    .overlay(Circle().strokeBorder(reached ? Theme.gold : Theme.panelHighlight, lineWidth: ready ? 4 : 2.5))
                    .shadow(color: .black.opacity(0.4), radius: 0, y: 4)
                rewardIcon(step.reward, size: 46)
                    .frame(width: 50, height: 50)
                    .saturation(reached ? 1 : 0.2)
                    .opacity(claimed ? 0.5 : (reached ? 1 : 0.75))
                    .modifier(Jiggle(active: ready && isChest, amplitude: 6, period: 0.6))
                if claimed {
                    badge("checkmark", fill: Theme.green, fg: .white)
                        .offset(x: 25, y: 25)
                } else if !reached {
                    badge("lock.fill", fill: Theme.panelHighlight, fg: Theme.textMuted)
                        .offset(x: 25, y: 25)
                }
                if ready {
                    Text(L("ABHOLEN"))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 9)
                        .frame(height: 22)
                        .background(Capsule().fill(Theme.gold))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                        .offset(y: 42)
                }
                if peek == step.trophies {
                    peekBubble(step.trophies - store.roadTrophies)
                        .offset(y: -58)
                        .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                }
            }
            .modifier(RoadBob(active: ready, amplitude: 4, speed: 4.5))
            .modifier(Jiggle(active: peek == step.trophies, amplitude: 7, period: 0.12))
            .scaleEffect(bounce == step.trophies ? 1.18 : 1)
        }
        .buttonStyle(.plain)
        .disabled(claimed)
        .accessibilityLabel(L("{0} Trophäen: {1}{2}", step.trophies, step.reward.title, ready ? L(", abholbar") : claimed ? L(", abgeholt") : L(", gesperrt")))
    }

    /// Sprechblase über einer gesperrten Belohnung.
    private func peekBubble(_ missing: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").foregroundColor(Theme.gold)
            Text(L("noch {0}", max(0, missing)))
                .foregroundColor(Theme.navy)
        }
        .font(.system(size: 13, weight: .black, design: .rounded))
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(Color.white))
        .overlay(alignment: .bottom) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 10))
                .foregroundColor(.white)
                .offset(y: 8)
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
        .fixedSize()
    }

    private func peekAt(_ step: RoadStep) {
        Haptics.shared.play(.select)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { peek = step.trophies }
        let mine = step.trophies
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if peek == mine { withAnimation(.easeOut(duration: 0.2)) { peek = nil } }
        }
    }

    private func badge(_ icon: String, fill: Color, fg: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .black))
            .foregroundColor(fg)
            .frame(width: 22, height: 22)
            .background(Circle().fill(fill))
            .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
    }

    /// Gegner am Weg: die Königsfigur seines Figurensets. Noch nicht erreicht → Schatten mit Fragezeichen.
    private func botNode(_ bot: BotLevel) -> some View {
        let reached = store.profile.trophies >= bot.trophyStart
        let c = Color(hex: bot.colorHex)
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [c.opacity(reached ? 0.75 : 0.18), Theme.panel], center: .center, startRadius: 2, endRadius: 32))
                .frame(width: 58, height: 58)
                .overlay(Circle().strokeBorder(reached ? c : Theme.panelHighlight, lineWidth: 2.5))
                .shadow(color: reached ? c.opacity(0.6) : .clear, radius: 8)
            PieceImage(type: .king, color: .white, skin: bot)
                .frame(width: 42, height: 42)
                .colorMultiply(reached ? .white : Color(hex: 0x10182E))
                .opacity(reached ? 1 : 0.85)
            if !reached {
                Text("?")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .offset(y: 2)
            }
        }
        .modifier(RoadBob(active: reached && store.arena.number == Arena.forTrophies(bot.trophyStart).number, amplitude: 2, speed: 2.2))
        .accessibilityLabel(reached ? bot.displayName : L("Unbekannter Gegner"))
    }

    /// Du: dein Avatar mit pulsierendem Ring und kreisendem Goldkranz.
    private var youNode: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { tl in
            let t = clock.time(tl.date)
            let ph = (sin(t * 3) + 1) / 2
            ZStack {
                Circle()
                    .strokeBorder(Theme.blueLight.opacity(0.75 - 0.6 * ph), lineWidth: 3)
                    .frame(width: 70 + 20 * ph, height: 70 + 20 * ph)
                Circle()
                    .strokeBorder(Theme.gold.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [3, 7]))
                    .frame(width: 78, height: 78)
                    .rotationEffect(.degrees(t * 40))
                PlayerAvatar(size: 62)
                    .shadow(color: Theme.blue.opacity(0.9), radius: 10)
            }
            .offset(y: CGFloat(sin(t * 2.4)) * 3)
        }
        .frame(width: 92, height: 92)
    }

    @ViewBuilder
    private func trailLabel(_ item: TrailItem, leading: Bool) -> some View {
        let align: HorizontalAlignment = leading ? .leading : .trailing
        switch item.kind {
        case .step(let step):
            let reached = store.isReached(step)
            VStack(alignment: align, spacing: 2) {
                Label("\(step.trophies)", systemImage: "trophy.fill")
                    .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundColor(reached ? Theme.gold : Theme.textMuted)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                Text(step.reward.title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(reached ? Theme.textPrimary : Theme.textSecondary)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .lineLimit(2)
                    .multilineTextAlignment(leading ? .leading : .trailing)
                if case .board(let b) = step.reward, store.isOwned(b), !store.isClaimed(step) {
                    Text(L("Schon im Besitz → {0} Splitter", BoardTheme.collectiblePrice))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
            }
        case .bot(let bot):
            let reached = store.profile.trophies >= bot.trophyStart
            VStack(alignment: align, spacing: 1) {
                Text(L("ab {0}", bot.trophyStart))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(Theme.textMuted)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                Text(reached ? bot.displayName : L("Unbekannter Gegner"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(reached ? Color(hex: bot.colorHex) : Theme.textSecondary)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(reached ? bot.title : bot.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
        case .you(let t):
            VStack(alignment: align, spacing: 1) {
                Text(L("DU BIST HIER"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Theme.navy)
                    .padding(.horizontal, 7)
                    .frame(height: 18)
                    .background(Capsule().fill(Theme.blueLight))
                Text(L("Du · {0}", t))
                    .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
        }
    }

    @ViewBuilder
    private func rewardIcon(_ reward: RoadReward, size: CGFloat) -> some View {
        switch reward {
        case .chest(let r), .arena(_, let r):
            ChestView(rarity: r, size: size)
        case .shards:
            ShardIcon(size: size * 0.8)
        case .board(let b):
            let colors = BoardColors.forTheme(b)
            VStack(spacing: 0) {
                HStack(spacing: 0) { Rectangle().fill(colors.light); Rectangle().fill(colors.dark) }
                HStack(spacing: 0) { Rectangle().fill(colors.dark); Rectangle().fill(colors.light) }
            }
            .frame(width: size * 0.82, height: size * 0.82)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5))
        }
    }

    // MARK: Arena-Tore

    func arenaColors(_ n: Int) -> [Color] { ArenaPalette.colors(n) }

    /// Tor einer Arena: Burgmauer mit Zinnen und Wimpeln, großes Wappen, Name, neue Ultimates und Arena-Truhe.
    private func arenaGate(_ arena: Arena) -> some View {
        let reached = store.roadTrophies >= arena.trophies
        let isCurrent = store.arena.number == arena.number
        let step = ProfileStore.road.first { $0.arena?.number == arena.number }
        let colors = arenaColors(arena.number)
        let fill = LinearGradient(colors: reached ? [colors[0].opacity(0.75), colors[1], Theme.panel] : [Theme.panelRaised, Theme.panel],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    if isCurrent {
                        LightRays(color: Color.white.opacity(0.5), count: 10, speed: 0.3)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    }
                    arenaMedal(arena, reached: reached, size: 72)
                        .shadow(color: reached ? colors[0].opacity(0.8) : .clear, radius: 12)
                }
                .frame(width: 82, height: 82)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("ARENA {0}", arena.number))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(reached ? .white.opacity(0.85) : Theme.textMuted)
                    Text(arena.name)
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if isCurrent {
                        Text(L("DU BIST HIER"))
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(Theme.navy)
                            .padding(.horizontal, 8)
                            .frame(height: 20)
                            .background(Capsule().fill(Theme.blueLight))
                    } else if reached {
                        Label(L("Erobert"), systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(Theme.green)
                    } else {
                        Label(L("noch {0}", arena.trophies - store.roadTrophies), systemImage: "trophy.fill")
                            .font(.system(size: 12, weight: .heavy).monospacedDigit())
                            .foregroundColor(Theme.gold)
                    }
                }
                Spacer(minLength: 0)
            }
            if !arena.ultimates.isEmpty || step != nil {
                HStack(spacing: 8) {
                    ForEach(arena.ultimates) { u in
                        UltimateCard(ultimate: u, mana: store.isUnlocked(u) ? GameState.maxMana : 0, compact: true)
                            .frame(width: 44)
                            .opacity(store.isUnlocked(u) ? 1 : 0.55)
                    }
                    if !arena.ultimates.isEmpty {
                        Text(arena.ultimates.count == 1 ? L("Neue Ultimate") : L("Neue Ultimates"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let step { arenaChest(step) }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(fill))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(isCurrent ? Color.white.opacity(0.85) : (reached ? colors[0].opacity(0.7) : Theme.panelHighlight),
                              lineWidth: isCurrent ? 2.5 : 1.5)
        )
        // Zinnen oben auf der Mauer
        .overlay(alignment: .top) {
            Battlements(teeth: 9)
                .fill(reached ? colors[0].opacity(0.9) : Theme.panelRaised)
                .frame(height: 12)
                .padding(.horizontal, 26)
                .offset(y: -11)
        }
        // Wimpel an beiden Ecken – in deiner Arena flattern sie
        .overlay(alignment: .topLeading) {
            Pennant(color: reached ? colors[0] : Theme.panelHighlight, waving: isCurrent, phase: 0)
                .offset(x: 12, y: -40)
        }
        .overlay(alignment: .topTrailing) {
            Pennant(color: reached ? colors[0] : Theme.panelHighlight, waving: isCurrent, phase: 1.3)
                .offset(x: -12, y: -40)
        }
        .modifier(PulseGlow(color: colors[0], active: isCurrent, strength: 0.8))
        .saturation(reached ? 1 : 0.5)
        .padding(.horizontal, 16)
        .padding(.top, 40)
        .padding(.bottom, 10)
    }

    private func arenaChest(_ step: RoadStep) -> some View {
        let reached = store.isReached(step)
        let claimed = store.isClaimed(step)
        let ready = reached && !claimed
        return Button {
            if ready { claim(step) } else if !claimed { peekAt(step) }
        } label: {
            ZStack(alignment: .bottom) {
                rewardIcon(step.reward, size: 52)
                    .frame(width: 60, height: 54)
                    .saturation(reached ? 1 : 0.3)
                    .opacity(claimed ? 0.5 : 1)
                    .modifier(Jiggle(active: ready, amplitude: 6, period: 0.6))
                    .modifier(RoadBob(active: ready, amplitude: 3, speed: 4.5))
                if ready {
                    Text(L("ABHOLEN"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 7)
                        .frame(height: 18)
                        .background(Capsule().fill(Theme.gold))
                        .offset(y: 10)
                } else if claimed {
                    badge("checkmark", fill: Theme.green, fg: .white).offset(x: 22, y: 4)
                }
                if peek == step.trophies {
                    peekBubble(step.trophies - store.roadTrophies)
                        .offset(y: -58)
                        .transition(.scale(scale: 0.4, anchor: .bottom).combined(with: .opacity))
                }
            }
            .scaleEffect(bounce == step.trophies ? 1.18 : 1)
        }
        .buttonStyle(.plain)
        .disabled(claimed)
        .accessibilityLabel(L("{0} Trophäen: {1}{2}", step.trophies, step.reward.title, ready ? L(", abholbar") : claimed ? L(", abgeholt") : L(", gesperrt")))
    }

    // MARK: Abholen

    private func claim(_ step: RoadStep) {
        guard let result = store.claim(step) else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { bounce = step.trophies }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.spring()) { bounce = nil }
        }
        switch result {
        case .chest(let chest):
            Haptics.shared.play(.chestLand)
            chestToOpen = chest
        case .shards(let n):
            celebrate(RoadToast(shards: n))
        case .board(let b):
            celebrate(RoadToast(board: b))
        }
    }

    /// Alles auf einmal: Splitter und Bretter sofort, Truhen öffnen sich nacheinander.
    private func claimAll() {
        var summary = RoadToast()
        var firstChest: Chest?
        for step in store.claimableRoadSteps {
            switch store.claim(step) {
            case .chest(let c)?: if firstChest == nil { firstChest = c }
            case .shards(let n)?: summary.shards += n
            case .board(let b)?: summary.board = b
            case nil: break
            }
        }
        if summary.shards > 0 || summary.board != nil {
            celebrate(summary)
        }
        if let firstChest {
            Haptics.shared.play(.chestLand)
            Task { @MainActor in
                if summary.shards > 0 || summary.board != nil {
                    try? await Task.sleep(nanoseconds: 900_000_000)
                }
                chestToOpen = firstChest
            }
        }
    }

    private func celebrate(_ t: RoadToast) {
        Haptics.shared.play(.chestBigReveal)
        SoundPlayer.shared.play(t.shards > 0 ? .shardShower : .rewardBig)
        burst = UInt64.random(in: 1...UInt64.max)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toast = t }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation(.easeOut) { toast = nil }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            burst = nil
        }
    }

    private func toastView(_ t: RoadToast) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 6) {
                if t.shards > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "diamond.fill").foregroundColor(Color(hex: 0x7FE3FF))
                        Text(L("+{0} Splitter", t.shards))
                    }
                }
                if let b = t.board {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill").foregroundColor(Theme.gold)
                        Text(L("Neues Brett: {0}!", b.name))
                    }
                }
            }
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(Capsule().fill(Theme.panelRaised))
            .overlay(Capsule().strokeBorder(Theme.gold, lineWidth: 2))
            .shadow(color: .black.opacity(0.5), radius: 12)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .allowsHitTesting(false)
    }
}

/// Gemaltes Arenabild. Die Dateien heißen wie die Arenen: 1 Wiese, 2 Kaserne, 3 Thron, 4 Sturm, 5 Hort, 6 Gipfel.
enum ArenaArt {
    static func imageName(_ n: Int) -> String { "arena-\(min(6, max(1, n)))" }
}

/// Farben je Arena – jede hat ihre eigene Stimmung (hell, dunkel).
enum ArenaPalette {
    static func colors(_ n: Int) -> [Color] {
        switch n {
        case 1: return [Color(hex: 0x2FAE8F), Color(hex: 0x16584C)]
        case 2: return [Color(hex: 0x5E86C9), Color(hex: 0x27406E)]
        case 3: return [Color(hex: 0xA066E0), Color(hex: 0x4B2A7A)]
        case 4: return [Color(hex: 0x3BB8E0), Color(hex: 0x1B4E72)]
        case 5: return [Color(hex: 0xF0623E), Color(hex: 0x7A1F1A)]
        default: return [Color(hex: 0xF7C64A), Color(hex: 0x8A5A10)]
        }
    }
}

// MARK: - Bewegung über die Uhrzeit (keine Endlos-Animationen)

/// Sanftes Auf und Ab.
struct RoadBob: ViewModifier {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    let active: Bool
    var amplitude: CGFloat = 3
    var speed: Double = 3
    var phase: Double = 0

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || !live)) { tl in
            content.offset(y: active ? CGFloat(sin(clock.time(tl.date) * speed + phase)) * amplitude : 0)
        }
    }
}

/// Atmen: wird größer und kleiner (für Leuchthöfe).
struct RoadBreathe: ViewModifier {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    let active: Bool
    var speed: Double = 3.5

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !active || !live)) { tl in
            let ph = active ? (sin(clock.time(tl.date) * speed) + 1) / 2 : 0.5
            content
                .scaleEffect(0.88 + 0.26 * ph)
                .opacity(0.6 + 0.4 * ph)
        }
    }
}

// MARK: - Burg-Elemente

/// Zinnen einer Burgmauer.
struct Battlements: Shape {
    var teeth = 7

    func path(in r: CGRect) -> Path {
        var p = Path()
        let n = max(2, teeth)
        let w = r.width / CGFloat(n * 2 - 1)
        for i in 0..<n {
            p.addRoundedRect(in: CGRect(x: r.minX + CGFloat(i * 2) * w, y: r.minY, width: w, height: r.height + 8),
                             cornerSize: CGSize(width: 3, height: 3))
        }
        return p
    }
}

/// Wimpel an einer Stange; flattert auf Wunsch.
struct Pennant: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    let color: Color
    var waving = false
    var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !waving || !live)) { tl in
            let t = clock.time(tl.date)
            let wave = waving ? CGFloat(sin(t * 5 + phase)) : 0
            Canvas { ctx, size in
                // Stange
                ctx.fill(Path(roundedRect: CGRect(x: 2, y: 0, width: 3, height: size.height), cornerRadius: 1.5),
                         with: .color(Color(hex: 0xC9B48A)))
                ctx.fill(Path(ellipseIn: CGRect(x: 0, y: -2, width: 7, height: 7)), with: .color(Theme.gold))
                // Schwalbenschwanz-Wimpel, die Spitze schwingt
                var flag = Path()
                flag.move(to: CGPoint(x: 5, y: 4))
                flag.addQuadCurve(to: CGPoint(x: size.width, y: 6 + wave * 4), control: CGPoint(x: size.width * 0.55, y: 2 - wave * 4))
                flag.addLine(to: CGPoint(x: size.width * 0.72, y: 13 + wave * 2))
                flag.addLine(to: CGPoint(x: size.width, y: 21 + wave * 4))
                flag.addQuadCurve(to: CGPoint(x: 5, y: 22), control: CGPoint(x: size.width * 0.55, y: 25 - wave * 4))
                flag.closeSubpath()
                ctx.fill(flag, with: .color(color))
                ctx.stroke(flag, with: .color(Color.white.opacity(0.5)), lineWidth: 1)
            }
        }
        .frame(width: 34, height: 44)
        .accessibilityHidden(true)
    }
}

// MARK: - Landschaften der Arenen

/// Hintergrund einer Arena: das gemalte Bild füllt die Fläche, die Mitte bleibt der Weg.
/// Noch nicht erreichte Arenen sind blasser. `scrim` dunkelt ab, wo Schrift direkt auf dem Bild liegt.
struct BiomeBackdrop: View {
    let arena: Int
    let colors: [Color]
    let reached: Bool
    let animated: Bool
    var scrim: Double = 0.18

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PreparedImages.image(ArenaArt.imageName(arena))
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .saturation(reached ? 1 : 0.15)
                    .brightness(reached ? 0 : -0.14)
                    .clipped()
                LinearGradient(colors: [
                    colors[1].opacity(min(0.78, scrim + (reached ? 0.12 : 0.34))),
                    Color.black.opacity(scrim * (reached ? 0.28 : 0.55)),
                    colors[1].opacity(min(0.82, scrim + (reached ? 0.22 : 0.42)))
                ], startPoint: .top, endPoint: .bottom)
                BiomeParticles(arena: arena, animated: animated)
                    .opacity(reached ? 0.72 : 0.22)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Teilchen je Arena: Glühwürmchen, Staub, Funkeln, Regen mit Blitzlicht, aufsteigende Glut, Schnee.
/// Ein Canvas pro Abschnitt, die Positionen ergeben sich aus der Uhrzeit (keine gespeicherten Teilchen).
struct BiomeParticles: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    let arena: Int
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !animated || !live)) { tl in
            let t = clock.time(tl.date)
            Canvas { ctx, size in
                BiomeParticles.draw(arena, ctx: ctx, size: size, t: t)
            }
        }
    }

    static func rand(_ i: Int, _ k: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return x - floor(x)
    }

    static func draw(_ arena: Int, ctx: GraphicsContext, size: CGSize, t: Double) {
        let w = Double(size.width), h = Double(max(1, size.height))
        let count = max(10, Int(h / 38))
        if arena == 4, t.truncatingRemainder(dividingBy: 7) < 0.12 {
            // Blitzlicht im Gewitter
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.1)))
        }
        for i in 0..<count {
            let r1 = rand(i, 1), r2 = rand(i, 2), r3 = rand(i, 3)
            switch arena {
            case 1:
                let x = r1 * w + sin(t * 0.8 + r2 * 6) * 14
                let y = r2 * h + cos(t * 0.6 + r3 * 6) * 12
                let a = 0.25 + 0.75 * (sin(t * 2.2 + r3 * 6) + 1) / 2
                ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(Color(hex: 0xD8FF7A).opacity(0.18 * a)))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)), with: .color(Color(hex: 0xEFFFB0).opacity(a)))
            case 2:
                let x = (r1 * w + t * (6 + r3 * 8)).truncatingRemainder(dividingBy: w)
                let y = r2 * h + sin(t * 0.7 + r1 * 6) * 8
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.4, height: 2.4)), with: .color(Color.white.opacity(0.28)))
            case 3:
                let a = max(0, sin(t * 1.6 + r3 * 12))
                guard a > 0.05 else { continue }
                let c = r2 > 0.5 ? Theme.gold : Color(hex: 0xD9B8FF)
                ctx.fill(ParticleCanvas.star(radius: CGFloat(2.5 + 3.5 * a)).offsetBy(dx: r1 * w, dy: r2 * h), with: .color(c.opacity(a)))
            case 4:
                let x = r1 * w
                let y = (r2 * h + t * 300 * (0.7 + r3 * 0.6)).truncatingRemainder(dividingBy: h)
                var drop = Path()
                drop.move(to: CGPoint(x: x, y: y))
                drop.addLine(to: CGPoint(x: x - 4, y: y + 14))
                ctx.stroke(drop, with: .color(Color(hex: 0xBFE6FF).opacity(0.3)), lineWidth: 1.4)
            case 5:
                let y = h - (r2 * h + t * 45 * (0.6 + r3)).truncatingRemainder(dividingBy: h)
                let x = r1 * w + sin(t * 1.3 + r2 * 6) * 12
                let a = min(1, y / h * 1.4)
                let s = 2 + r3 * 2.5
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(Color(hex: 0xFF8A3D).opacity(0.85 * a)))
            default:
                let y = (r2 * h + t * 28 * (0.6 + r3)).truncatingRemainder(dividingBy: h)
                let x = r1 * w + sin(t * 0.9 + r2 * 6) * 16
                let s = 1.5 + r3 * 2.2
                ctx.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(Color.white.opacity(0.7)))
                if i % 6 == 0 {
                    let a = max(0, sin(t * 2 + r1 * 9))
                    ctx.fill(ParticleCanvas.star(radius: CGFloat(3 * a + 1)).offsetBy(dx: r3 * w, dy: r1 * h), with: .color(Theme.gold.opacity(a)))
                }
            }
        }
    }
}

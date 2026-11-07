import SwiftUI

/// Gegnersuche (Anleitung Schritt 8): Rocky, laufende Sekunden, Abbrechen. Sieht bei Bot-Ersatz aus wie bei Menschen.
@MainActor
final class MatchmakingController: ObservableObject {
    enum Phase: Equatable {
        case idle
        case searching(elapsed: Int)
        case found(MatchFound)
        case failed(String)
    }

    @Published var phase: Phase = .idle
    private var service: MatchService?
    private var task: Task<Void, Never>?
    private var ticker: Task<Void, Never>?

    var isSearching: Bool {
        if case .searching = phase { return true }
        return false
    }

    func start() {
        guard let client = Backend.client else {
            phase = .failed(L("Keine Verbindung zum Server."))
            return
        }
        cancel()
        let store = ProfileStore.shared
        let request = MatchRequest(rulesVersion: OnlineConfig.rulesVersion, player: store.playerCard,
                                   deck: store.activeDeck.map(\.rawValue), ultimate: store.activeUltimate.rawValue,
                                   timeControl: OnlineConfig.timeControl.rawValue)
        let svc = SupabaseMatchService(client: client)
        service = svc
        phase = .searching(elapsed: 0)
        let start = Date()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                let s = Int(Date().timeIntervalSince(start))
                await MainActor.run {
                    if case .searching = self?.phase { self?.phase = .searching(elapsed: s) }
                }
            }
        }
        task = Task { [weak self] in
            do {
                let found = try await svc.findMatch(request)
                guard !Task.isCancelled else { return }
                self?.ticker?.cancel()
                self?.phase = .found(found)
            } catch is CancellationError {
                self?.ticker?.cancel()
                self?.phase = .idle
            } catch {
                self?.ticker?.cancel()
                self?.phase = .failed(MatchmakingError(error).message)
            }
        }
    }

    func cancel() {
        task?.cancel()
        ticker?.cancel()
        service?.cancel()
        task = nil
        ticker = nil
        if isSearching { phase = .idle }
    }
}

struct MatchmakingSheet: View {
    @ObservedObject var controller: MatchmakingController
    @ObservedObject private var store = ProfileStore.shared
    var onCancel: () -> Void
    @State private var appeared = false
    @State private var startedAt = Date()

    private var elapsed: Int {
        if case .searching(let s) = controller.phase { return s }
        return Int(OnlineConfig.matchmakingTimeout)
    }
    private var found: MatchFound? {
        if case .found(let f) = controller.phase { return f }
        return nil
    }

    var body: some View {
        let arena = store.arena
        let colors = ArenaPalette.colors(arena.number)
        return ZStack {
            Theme.background.ignoresSafeArea()
            BiomeBackdrop(arena: arena.number, colors: colors, reached: true, animated: true, scrim: 0.5)
                .ignoresSafeArea()
            RadialGradient(colors: [.clear, Color.black.opacity(0.55)], center: .center, startRadius: 120, endRadius: 520)
                .ignoresSafeArea()
            TwinkleField(count: 18, colors: [Theme.gold, .white, colors[0]])
                .opacity(0.6)
                .ignoresSafeArea()
            if found != nil {
                MatchmakingFlash()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            VStack(spacing: 14) {
                topBar(arena: arena, colors: colors)
                Spacer(minLength: 4)
                title
                MatchmakingRadar(found: found != nil, accent: colors[0])
                    .frame(width: 270, height: 270)
                duelRow
                Spacer(minLength: 4)
                if found == nil {
                    searchInfo
                    TipTicker(cards: store.activeDeck)
                        .padding(.horizontal, 20)
                }
                Button(action: onCancel) {
                    Text(L("Abbrechen"))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Color.black.opacity(0.85), height: 52))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(found == nil ? 1 : 0)
                .disabled(found != nil)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startedAt = Date()
            Haptics.shared.play(.summon)
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
        .onChange(of: elapsed) { seconds in
            guard controller.isSearching, seconds > 0 else { return }
            Haptics.shared.play(.tick)
        }
        .interactiveDismissDisabled()
    }

    // MARK: Kopf

    private func topBar(arena: Arena, colors: [Color]) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    Image(systemName: arena.icon)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(width: 24, height: 24)
                Text(L("ARENA {0} · {1}", arena.number, arena.name.uppercased()))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(Theme.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 32)
            .background(Capsule().fill(Color.black.opacity(0.4)))
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
            Spacer(minLength: 8)
            SettingChip(icon: "timer", text: OnlineConfig.timeControl.name, gold: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var title: some View {
        if let found {
            VStack(spacing: 4) {
                Text(L("Gegner gefunden!"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.gold.opacity(0.7), radius: 14)
                Text(found.opponent.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .transition(.scale(scale: 1.8).combined(with: .opacity))
        } else {
            VStack(spacing: 4) {
                Text(L("Gegner wird gesucht"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 0, y: 2)
                Text(elapsed < 4 ? L("Spieler mit ähnlich vielen Trophäen …") : L("Noch ein Moment …"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
        }
    }

    // MARK: Du gegen …

    private var duelRow: some View {
        HStack(spacing: 10) {
            fighter(name: store.profile.name, trophies: store.profile.trophies) {
                PlayerAvatar(size: 74)
            }
            ZStack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.gold.opacity(0.8), radius: 10)
                    .modifier(Jiggle(active: found == nil, amplitude: 6, period: 0.8))
                Text("VS")
                    .font(.system(size: 13, weight: .black, design: .rounded).italic())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(Capsule().fill(Theme.red))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1))
                    .offset(y: 26)
            }
            .frame(width: 54)
            if let found {
                fighter(name: found.opponent.name, trophies: found.opponent.trophies) {
                    PlayerAvatar(size: 74,
                                 frame: found.opponent.frame.flatMap(AvatarFrame.init(rawValue:)) ?? AvatarFrame.none,
                                 avatar: Avatar(rawValue: found.opponent.avatar) ?? .knight)
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                fighter(name: "???", trophies: nil) {
                    AvatarRoulette(size: 74)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: found != nil)
    }

    private func fighter<Portrait: View>(name: String, trophies: Int?, @ViewBuilder portrait: () -> Portrait) -> some View {
        VStack(spacing: 6) {
            portrait()
                .shadow(color: Theme.gold.opacity(0.45), radius: 10)
            Text(name)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 3) {
                Image(systemName: "trophy.fill").font(.system(size: 10, weight: .black))
                Text(trophies.map { "\($0)" } ?? "–")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundColor(Theme.gold)
        }
        .frame(width: 110)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.38)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1))
    }

    // MARK: Suchbereich und Zeit

    /// Wie auf dem Server: Der Suchbereich wächst von ±100 auf ±400 Trophäen, nach 10 s übernimmt ein Ersatz.
    private var searchInfo: some View {
        let timeout = OnlineConfig.matchmakingTimeout
        let progress = min(1, Double(elapsed) / timeout)
        let range = 100 + Int(300 * progress)
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [Theme.gold, Color(hex: 0xFFA000)], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                Text(String(format: "0:%02d", min(elapsed, Int(timeout))))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Suchbereich ±{0} Trophäen", range))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.4))
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.blueLight, Theme.gold], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(10, geo.size.width * (0.25 + 0.75 * progress)))
                            .overlay(ShineSweep().clipShape(Capsule()))
                            .animation(.easeOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.black.opacity(0.4)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

/// Radar: drehender Lichtkegel, Pulsringe und Gegner-„Echos“, die aufleuchten, wenn der Kegel sie trifft.
private struct MatchmakingRadar: View {
    @Environment(\.liveAnimations) private var live
    let found: Bool
    let accent: Color
    private let blips: [(angle: Double, radius: Double, avatar: Avatar)] = [
        (20, 0.78, .fox), (95, 0.55, .owl), (150, 0.86, .wolf), (215, 0.66, .bear), (280, 0.82, .lion), (330, 0.5, .robot)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let sweep = (t * (found ? 260 : 120)).truncatingRemainder(dividingBy: 360)
            GeometryReader { geo in
                let r = min(geo.size.width, geo.size.height) / 2
                ZStack {
                    Circle().fill(Color.black.opacity(0.35))
                    ForEach(1..<4, id: \.self) { i in
                        Circle()
                            .strokeBorder(Theme.gold.opacity(0.18), lineWidth: 1)
                            .frame(width: r * 2 * Double(i) / 3, height: r * 2 * Double(i) / 3)
                    }
                    Rectangle().fill(Theme.gold.opacity(0.12)).frame(width: 1, height: r * 2)
                    Rectangle().fill(Theme.gold.opacity(0.12)).frame(width: r * 2, height: 1)
                    // Pulsringe
                    ForEach(0..<3, id: \.self) { i in
                        let p = ((t / 2.4) + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                        Circle()
                            .strokeBorder((found ? Theme.gold : accent).opacity(0.8 * (1 - p)), lineWidth: 2.5)
                            .frame(width: r * 2 * (0.3 + 0.7 * p), height: r * 2 * (0.3 + 0.7 * p))
                    }
                    // Lichtkegel
                    Circle()
                        .fill(AngularGradient(gradient: Gradient(colors: [Theme.gold.opacity(0.55), Theme.gold.opacity(0.0), .clear, .clear]),
                                              center: .center, startAngle: .degrees(0), endAngle: .degrees(360)))
                        .rotationEffect(.degrees(sweep))
                        .blendMode(.screen)
                    // Echos
                    ForEach(0..<blips.count, id: \.self) { i in
                        let b = blips[i]
                        let behind = (sweep - b.angle + 360).truncatingRemainder(dividingBy: 360)
                        let glow = max(0, 1 - behind / 140)
                        let a = b.angle * .pi / 180
                        AvatarPortrait(avatar: b.avatar)
                            .frame(width: 26, height: 26)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Theme.gold.opacity(0.4 + 0.6 * glow), lineWidth: 1.5))
                            .shadow(color: Theme.gold.opacity(glow), radius: 8 * glow)
                            .opacity(found ? 0 : 0.25 + 0.75 * glow)
                            .scaleEffect(0.8 + 0.3 * glow)
                            .offset(x: cos(a) * r * b.radius, y: sin(a) * r * b.radius)
                    }
                    PlayerAvatar(size: 96)
                        .shadow(color: Theme.gold.opacity(0.6), radius: 14)
                        .scaleEffect(found ? 1.08 : 1 + 0.03 * sin(t * 3))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold.opacity(0.4)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
            }
        }
    }
}

/// Gegner-Platz während der Suche: Die Avatare wechseln wie an einem Spielautomaten.
private struct AvatarRoulette: View {
    @Environment(\.liveAnimations) private var live
    let size: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !live)) { tl in
            let all = Avatar.allCases
            let i = Int(tl.date.timeIntervalSinceReferenceDate * 9) % all.count
            ZStack {
                AvatarPortrait(avatar: all[i])
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .blur(radius: 1.2)
                    .saturation(0.4)
                    .opacity(0.75)
                Circle().fill(Color.black.opacity(0.35))
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                    .foregroundColor(Theme.gold)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Theme.gold.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, dash: [5, 4])))
        }
    }
}

/// Unten wechseln die Karten deines Decks mit ihrer Wirkung – die Wartezeit wird zur kleinen Auffrischung.
private struct TipTicker: View {
    let cards: [CardType]
    @State private var index = 0

    var body: some View {
        Group {
            if !cards.isEmpty {
                let card = cards[index % cards.count]
                HStack(spacing: 10) {
                    CardArtThumb(art: "art-card-\(card.rawValue)", width: 38, border: Color(hex: card.tier.colorHex))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.name)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(Theme.gold)
                        Text(card.description)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.4)))
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(height: 76)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_200_000_000)
                withAnimation(.easeInOut(duration: 0.35)) { index += 1 }
            }
        }
    }
}

/// Goldener Blitz und Funken, wenn ein Gegner gefunden ist.
private struct MatchmakingFlash: View {
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.white.opacity(shown ? 0 : 0.7)
            RadialGradient(colors: [Theme.gold.opacity(0.55), .clear], center: .center, startRadius: 10, endRadius: shown ? 520 : 60)
                .opacity(shown ? 0.6 : 1)
            ConfettiView(seed: 7)
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { shown = true } }
    }
}

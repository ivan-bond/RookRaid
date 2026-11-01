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
    @State private var dots = 0

    var body: some View {
        let arena = store.arena.number
        let colors = ArenaPalette.colors(arena)
        return ZStack {
            Theme.background.ignoresSafeArea()
            BiomeBackdrop(arena: arena, colors: colors, reached: true, animated: true)
                .ignoresSafeArea()
            TwinkleField(count: 16, colors: [Theme.gold, .white, colors[0]])
                .opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 12)
                Text(L("Gegner wird gesucht"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.45), radius: 0, y: 2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                duel
                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                VStack(spacing: 8) {
                    Text(timer)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(Theme.gold)
                        .shadow(color: Theme.gold.opacity(0.55), radius: 16)
                        .contentTransition(.numericText())
                    SettingChip(icon: "timer", text: OnlineConfig.timeControl.name, gold: true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 22)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.45), lineWidth: 1.5))
                Spacer(minLength: 12)
                Button(action: onCancel) {
                    Text(L("Abbrechen"))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Color.black.opacity(0.85), height: 52))
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Haptics.shared.play(.summon)
            startDots()
        }
        .onChange(of: elapsed) { seconds in
            guard controller.isSearching, seconds > 0 else { return }
            Haptics.shared.play(.tick)
        }
        .interactiveDismissDisabled()
    }

    /// Du gegen ein noch unbekanntes Gegenüber, Rocky feuert von unten an.
    private var duel: some View {
        ZStack {
            Circle()
                .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 2)
                .frame(width: 210, height: 210)
                .scaleEffect(1 + 0.04 * Double(dots % 2))
                .animation(.easeInOut(duration: 0.7), value: dots)
            HStack(spacing: 8) {
                fighter(name: store.profile.name) {
                    AvatarPortrait(avatar: store.activeAvatar)
                        .frame(width: 86, height: 86)
                        .clipShape(Circle())
                }
                Text("VS")
                    .font(.system(size: 22, weight: .black, design: .rounded).italic())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(Capsule().fill(Theme.red))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                    .modifier(Jiggle(active: true, amplitude: 4, period: 0.9))
                fighter(name: "???") {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.45))
                        Image(systemName: "questionmark")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(Theme.gold)
                            .modifier(RoadBob(active: true, amplitude: 3, speed: 2.4))
                    }
                    .frame(width: 86, height: 86)
                }
            }
            RockyAvatar(size: 54, bounce: dots, excited: true)
                .offset(y: 78)
        }
        .frame(height: 230)
    }

    private func fighter<Portrait: View>(name: String, @ViewBuilder portrait: () -> Portrait) -> some View {
        VStack(spacing: 8) {
            portrait()
                .overlay(Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom), lineWidth: 3))
                .shadow(color: Theme.gold.opacity(0.45), radius: 10)
            Text(name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .frame(width: 100)
        }
    }

    private var elapsed: Int {
        if case .searching(let s) = controller.phase { return s }
        return 0
    }

    private var timer: String {
        String(format: "0:%02d", min(elapsed, Int(OnlineConfig.matchmakingTimeout)))
    }

    private var subtitle: String {
        elapsed < 4 ? L("Spieler mit ähnlich vielen Trophäen …") : L("Noch ein Moment …")
    }

    private func startDots() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 700_000_000)
                dots += 1
            }
        }
    }
}

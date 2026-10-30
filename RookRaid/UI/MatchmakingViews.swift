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
    var onCancel: () -> Void
    @State private var dots = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            LinearGradient(colors: [Theme.gold.opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                RockyAvatar(size: 96, bounce: dots, excited: true)
                Text(L("Gegner wird gesucht"))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Text(timer)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.4), radius: 12)
                SettingChip(icon: "timer", text: OnlineConfig.timeControl.name, gold: true)
                Spacer()
                Button(action: onCancel) {
                    Text(L("Abbrechen"))
                        .font(.system(size: 16, weight: .heavy))
                        .frame(maxWidth: .infinity)
                        .padding(14)
                }
                .buttonStyle(PanelButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startDots() }
        .interactiveDismissDisabled()
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

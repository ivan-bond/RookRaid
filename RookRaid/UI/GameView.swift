import SwiftUI

struct GameView: View {
    @StateObject private var vm: GameViewModel
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showResignConfirm = false
    @State private var showRules = false
    @State private var chestToOpen: Chest?
    /// Truhen dieser Partie: werden nacheinander geöffnet, ältere Truhen im Lager bleiben liegen.
    @State private var chestQueue: Set<UUID>?

    init(viewModel: GameViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        let top = vm.flipped ? PlayerColor.white : PlayerColor.black
        let bottom = top.opponent

        ZStack {
            Theme.background.ignoresSafeArea()

            GeometryReader { geo in
            let side = GameView.boardSide(for: geo.size, tutorial: vm.mode == .tutorial)
            VStack(spacing: 6) {
                topBar
                    .frame(height: GameView.topBarHeight)
                if vm.mode == .tutorial {
                    // Erste Schlacht: Die Aufgabe steht dort, wo sonst die Gegnerleiste ist – nichts verdeckt das Brett.
                    QuestBar(coach: vm.coach, opponent: vm.name(for: top),
                             opponentThinking: vm.isThinking, nudge: vm.questNudge,
                             nudgeText: vm.questNudgeText, onSkip: { vm.skipTutorial() })
                        .padding(.horizontal, 8)
                } else {
                    PlayerBar(vm: vm, color: top)
                        .padding(.horizontal, 8)
                        .frame(height: GameView.opponentBarHeight)
                }

                // Feste Brettgröße: Hinweise, Gutschriften oder Leisten, die kommen und gehen,
                // verändern das Brett nie (kein „Zoomen“ nach einem Zug).
                BoardView(vm: vm)
                    .frame(width: side, height: side)
                    .modifier(ShakeEffect(animatableData: CGFloat(vm.shake)))

                PlayerBar(vm: vm, color: bottom)
                    .padding(.horizontal, 8)
                    .frame(height: GameView.playerBarHeight)

                HandView(vm: vm)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)

                // Fester Platz für die Hinweis-Blase direkt unter den Karten (immer gleich hoch)
                if vm.mode != .tutorial {
                    HintSlot(vm: vm)
                        .padding(.horizontal, 10)
                }

                Spacer(minLength: 0)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }

            if let done = vm.tutorialComplete {
                TutorialCompleteOverlay(xp: done.xp, streakLit: done.streak, onDone: { dismiss() },
                                        onOpenChest: store.pendingChests.isEmpty ? nil : { chestToOpen = store.pendingChests.first })
                    .zIndex(6)
            }

            if let a = vm.announcement {
                AnnouncementView(announcement: a)
                    .id(a.id)
                    .transition(.scale(scale: 2.2).combined(with: .opacity))
                    .offset(y: -150)
                    .allowsHitTesting(false)
            }

            if let f = vm.finisher, vm.gameOver == nil {
                FinisherTitle(humanWon: !vm.mode.isBot || f.winner == vm.humanColor)
                    .allowsHitTesting(false)
            }

            if let banner = vm.banner {
                CastBannerView(banner: banner, casterName: vm.name(for: banner.caster))
                    .id(banner.id)
                    .transition(.scale.combined(with: .opacity))
                    .offset(y: -60)
            }

            if let move = vm.promotionRequest, let pawn = vm.state[move.from] {
                PromotionPicker(color: pawn.color, onChoose: { vm.choosePromotion($0) }, onCancel: { vm.cancelPromotion() })
                    .transition(.opacity)
                    .zIndex(5)
            }

            if let notice = vm.onlineNotice {
                Text(notice)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.red.opacity(0.9)))
                    .padding(.top, 40)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .zIndex(4)
            }

            if vm.incomingDraw {
                VStack(spacing: 8) {
                    Text(L("{0} bietet Remis an", vm.name(for: vm.humanColor.opponent)))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                    HStack(spacing: 10) {
                        Button(L("Annehmen")) { vm.answerDraw(true) }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.green, shadow: Theme.green.opacity(0.4), height: 44))
                        Button(L("Ablehnen")) { vm.answerDraw(false) }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 44))
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 24)
                .zIndex(5)
            }

            if vm.introActive {
                VersusIntro(vm: vm) { vm.finishIntro() }
                    .transition(.opacity)
                    .zIndex(8)
            }

            if let info = vm.gameOver {
                GameOverOverlay(info: info, onRematch: { vm.restart() }, onExit: { dismiss() },
                                next: nextGame(after: info),
                                onOpenChest: { openEarnedChests(info) })
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Feedback.apply(settings: store.profile.settings)
            vm.startClock()
            vm.resumeOnlinePresence()
        }
        .onDisappear {
            vm.stopClock()
            vm.flushStats()
            vm.endOnlinePresence()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                vm.startClock()
                vm.resumeOnlinePresence()
            } else {
                vm.stopClock()
                vm.flushStats()
            }
        }
        .confirmationDialog(L("Partie aufgeben?"), isPresented: $showResignConfirm, titleVisibility: .visible) {
            Button(L("Aufgeben"), role: .destructive) { vm.resign() }
            Button(L("Weiterspielen"), role: .cancel) {}
        }
        .sheet(isPresented: $showRules) { RulesView() }
        .background(
            // Eigener Träger für die Truhen-Öffnung, damit sie der Wiedergabe nicht in die Quere kommt.
            Color.clear.fullScreenCover(item: $chestToOpen) { c in ChestOpeningView(start: c, only: chestQueue) }
        )
        .onChange(of: vm.closeRequested) { close in
            if close { dismiss() }
        }
    }

    /// Nächste Partie direkt aus dem Ergebnisfenster: im Kampf ein neuer Gegner passend zu den Trophäen,
    /// in der Leiter nach einem Sieg der nächste Charakter. Übung und Zu-zweit haben nur Revanche.
    private func nextGame(after info: GameOverInfo) -> GameOverOverlay.NextGame? {
        switch vm.mode {
        case .online:
            return .init(title: L("Nächstes Spiel"), icon: "bolt.fill") {
                dismiss()
                NotificationCenter.default.post(name: .startQuickBattle, object: nil)
            }
        case .bot:
            if vm.onlineBotPlay != nil {
                return .init(title: L("Nächstes Spiel"), icon: "bolt.fill") {
                    dismiss()
                    NotificationCenter.default.post(name: .startQuickBattle, object: nil)
                }
            }
            return .init(title: L("Nächstes Spiel"), icon: "bolt.fill") {
                startNext(.bot(BotLevel.forTrophies(store.profile.trophies)))
            }
        case .ladder(let level):
            guard info.result == .win,
                  let i = BotLevel.allCases.firstIndex(of: level), i + 1 < BotLevel.allCases.count else { return nil }
            let next = BotLevel.allCases[i + 1]
            guard store.isLadderUnlocked(next) else { return nil }
            return .init(title: L("Gegen {0} kämpfen", next.displayName), icon: "arrow.right.circle.fill") {
                startNext(.ladder(next))
            }
        default:
            return nil
        }
    }

    /// Die in dieser Partie verdienten Truhen öffnen – gleich nacheinander, jede mit ihrem Grund.
    private func openEarnedChests(_ info: GameOverInfo) {
        let ids = Set(info.chests.map(\.id))
        let waiting = store.pendingChests.filter { ids.contains($0.id) }
        guard let first = waiting.first else { return }
        chestQueue = ids
        chestToOpen = first
    }

    /// Der Träger (GameHost) tauscht die Partie aus, das Vollbild bleibt offen.
    private func startNext(_ mode: GameMode) {
        Haptics.shared.play(.select)
        NotificationCenter.default.post(name: .startGame, object: mode)
    }

    /// Brettgröße aus dem verfügbaren Platz – unabhängig vom wechselnden Inhalt darunter.
    static let topBarHeight: CGFloat = 32
    static let playerBarHeight: CGFloat = 46
    /// Die Gegnerleiste ist höher: Seine Karten sind dort groß zu sehen (Platz vom früheren Gebietsbalken).
    static let opponentBarHeight: CGFloat = 80
    static let questBarHeight: CGFloat = 84

    /// Brettgröße aus dem Platz, der nach allen festen Leisten übrig bleibt – auf jedem iPhone so,
    /// dass Karten und Hinweis-Blase vollständig darunter passen.
    static func boardSide(for size: CGSize, tutorial: Bool) -> CGFloat {
        // Karten: Ultimate 66 pt + Trenner + 4 Karten (Seitenverhältnis 0,8 plus Name darunter)
        let cardWidth = max(40, (size.width - 20 - 66 - 1 - 30) / 4)
        let cardHeight = max(cardWidth / 0.8 + 16, 66 / 0.8 + 15)
        let hand = 2 + 32 + 11 + cardHeight
        var reserved = topBarHeight + (tutorial ? questBarHeight : opponentBarHeight) + playerBarHeight + hand + 6 * 4 + 6
        if !tutorial { reserved += HintSlot.height + 6 }
        return max(220, min(size.width, size.height - reserved))
    }

    private var topBar: some View {
        HStack {
            Button {
                vm.save()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 40, height: 32)
            }
            Spacer()
            Text(gameTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            if vm.timeControl.isTimed {
                Text(vm.timeControl.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            Menu {
                if vm.mode == .tutorial {
                    Button { vm.skipTutorial() } label: { Label(L("Tutorial überspringen"), systemImage: "forward.end") }
                }
                Button { vm.cancelPending() } label: { Label(L("Auswahl abbrechen"), systemImage: "xmark.circle") }
                if vm.canOfferDraw {
                    Button { vm.offerDraw() } label: { Label(L("Remis anbieten"), systemImage: "equal") }
                }
                if vm.onlineBotPlay == nil && !vm.mode.isOnline {
                    Button { vm.restart() } label: { Label(L("Neue Partie"), systemImage: "arrow.counterclockwise") }
                }
                Button { showRules = true } label: { Label(L("Regeln"), systemImage: "book") }
                Button(role: .destructive) { showResignConfirm = true } label: { Label(L("Aufgeben"), systemImage: "flag") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 40, height: 32)
            }
        }
        .padding(.horizontal, 6)
    }

    private var gameTitle: String {
        if vm.mode == .tutorial { return L("Erste Schlacht") }
        if vm.onlineBotPlay != nil || vm.mode.isOnline {
            return L("Gegen ") + vm.name(for: vm.humanColor.opponent)
        }
        if vm.mode.isBot {
            let prefix = vm.mode.isLadder ? L("Leiter: ") : (vm.mode.isPractice ? L("Übung: ") : L("Gegen "))
            return prefix + (vm.botLevel?.displayName ?? L("Bot"))
        }
        return L("Zu zweit")
    }
}

// MARK: - Spielerleiste (kompakt)

struct PlayerBar: View {
    @ObservedObject var vm: GameViewModel
    let color: PlayerColor

    var body: some View {
        let active = vm.state.current == color && !vm.status.isOver
        let lost = vm.capturedPieces(lostBy: color.opponent)
        let balance = vm.state.materialBalance(for: color)

        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color == .white ? Color(hex: 0xE8E6E3) : Color(hex: 0x1B1A18))
                if (vm.onlineBotPlay != nil || vm.mode.isOnline), color != vm.humanColor {
                    // Bot-Ersatz: wie ein Mensch – kein CPU-Symbol (E1)
                    PieceImage(type: .knight, color: color, skin: nil).padding(3)
                } else if vm.mode.isBot && color != vm.humanColor, let skin = vm.skin(for: color) {
                    // Der König aus dem Figurenset des Bots
                    PieceImage(type: .king, color: color, skin: skin).padding(2)
                } else if vm.mode.isBot && color != vm.humanColor {
                    Image(systemName: "cpu")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color == .white ? .black : .white)
                } else {
                    PieceImage(type: .knight, color: color, skin: vm.skin(for: color)).padding(3)
                }
            }
            .frame(width: 32, height: 32)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(color == vm.perspective ? Theme.blue : Theme.red, lineWidth: active ? 2.5 : 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vm.name(for: color))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if vm.isThinking && vm.state.current == color {
                        ThinkingDots()
                    }
                    HStack(spacing: -4) {
                        ForEach(Array(lost.enumerated()), id: \.offset) { _, p in
                            PieceImage(type: p.type, color: p.color, skin: vm.skin(for: p.color))
                                .frame(width: 14, height: 14)
                        }
                    }
                    if balance > 0 {
                        Text("+\(balance)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                if color != vm.handOwner, let deck = vm.state.decks[color] {
                    OpponentHandStrip(hand: deck.hand, ultimate: vm.state.ultimates[color],
                                      mana: vm.state.mana[color, default: 0],
                                      cooldowns: deck.hand.map { vm.state.cooldownRemaining($0, player: color) },
                                      cardWidth: color == vm.perspective ? 18 : 36)
                }
            }
            Spacer(minLength: 4)
            if vm.timeControl.isTimed {
                LiveClockView(clock: vm.clock, color: color, active: active)
            }
        }
    }
}

/// Beobachtet nur die Uhr – das Ticken baut nichts anderes neu auf.
struct LiveClockView: View {
    @ObservedObject var clock: GameClock
    let color: PlayerColor
    let active: Bool

    var body: some View {
        ClockView(seconds: clock.seconds[color, default: 0], active: active)
    }
}

struct ClockView: View {
    let seconds: Double
    let active: Bool

    var body: some View {
        let low = seconds < 20
        HStack(spacing: 4) {
            if active {
                Image(systemName: "clock.fill").font(.system(size: 12, weight: .bold))
            }
            Text(format(seconds))
                .font(.system(size: 20, weight: .bold, design: .monospaced))
        }
        .foregroundColor(active ? (low ? .white : Theme.navy) : Theme.textMuted)
        .padding(.horizontal, 10)
        .frame(minWidth: 96, minHeight: 38, alignment: .trailing)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(active ? (low ? Theme.red : Theme.clockActive) : Theme.clockInactive)
        )
    }

    private func format(_ s: Double) -> String {
        let total = max(0, s)
        if total < 20 {
            return String(format: "%d:%04.1f", Int(total) / 60, total.truncatingRemainder(dividingBy: 60))
        }
        let t = Int(total.rounded(.up))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

struct ThinkingDots: View {
    @State private var phase = false
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.textSecondary)
                    .frame(width: 4, height: 4)
                    .opacity(phase ? 1 : 0.25)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .onAppear { phase = true }
    }
}

// MARK: - Spielende

// MARK: - Ansagen & Finisher

struct AnnouncementView: View {
    let announcement: Announcement

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: announcement.icon)
                    .font(.system(size: 26, weight: .black))
                Text(announcement.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .italic()
            }
            .foregroundColor(.white)
            .shadow(color: announcement.color, radius: 0, x: 3, y: 3)
            .shadow(color: .black.opacity(0.6), radius: 6)
            Text(announcement.subtitle)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(announcement.color.opacity(0.9)))
        }
        .rotationEffect(.degrees(-4))
    }
}

struct FinisherTitle: View {
    let humanWon: Bool
    @State var slam = false

    var body: some View {
        VStack(spacing: 6) {
            Text(L("SCHACHMATT"))
                .font(.system(size: 46, weight: .black, design: .rounded))
                .italic()
                .foregroundColor(.white)
                .shadow(color: humanWon ? Theme.gold : Theme.red, radius: 0, x: 4, y: 4)
                .shadow(color: .black, radius: 10)
            Image(systemName: "crown.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(humanWon ? Theme.gold : Theme.red)
        }
        .scaleEffect(slam ? 1 : 3.5)
        .opacity(slam ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(1.1)) { slam = true }
        }
    }
}

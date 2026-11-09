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
                // Hochformat: alles untereinander. Querformat (iPad, offenes iPhone Duo): Brett links, Karten rechts.
                // Die Entscheidung kommt nur aus dem Fenster, nicht aus dem Gerät.
                if geo.size.width > geo.size.height + 40 {
                    widePlay(top: top, bottom: bottom, size: geo.size)
                } else {
                    tallPlay(top: top, bottom: bottom, size: geo.size)
                }
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
                let won = vm.mode.isBot || vm.mode.isOnline ? f.winner == vm.humanColor : true
                FinisherTitle(style: won ? .win : .loss, headline: f.headline,
                              subline: won ? L("Der König platzt!") : L("Dein König platzt!"))
                    .id(f.headline)
            } else if let reason = vm.drawFinish, vm.gameOver == nil {
                FinisherTitle(style: .draw, headline: L("REMIS"), subline: reason, delay: 0.1)
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
                                allowsRematch: vm.onlineBotPlay == nil && !vm.mode.isOnline,
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
        .fullScreenCover(isPresented: $showRules) { RulesView() }
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

    /// Hochformat: Brett unter den Leisten, Karten darunter. Die Größe folgt dem Fenster, nicht einem Gerät.
    private func tallPlay(top: PlayerColor, bottom: PlayerColor, size: CGSize) -> some View {
        let side = GameView.boardSide(for: size, tutorial: vm.mode == .tutorial)
        return VStack(spacing: 6) {
            topBar
                .frame(height: GameView.topBarHeight)
            opponentStrip(top)
            board(side)
            PlayerBar(vm: vm, color: bottom)
                .padding(.horizontal, 8)
                .frame(height: GameView.playerBarHeight)
            HandView(vm: vm)
                .padding(.horizontal, 10)
                .padding(.top, 2)
            if vm.mode != .tutorial {
                HintSlot(vm: vm)
                    .padding(.horizontal, 10)
            }
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    /// Querformat: das Brett nimmt die ganze Höhe. Namen, Karten und Hinweis stehen daneben.
    private func widePlay(top: PlayerColor, bottom: PlayerColor, size: CGSize) -> some View {
        let metrics = GameView.wideMetrics(for: size)
        return VStack(spacing: 4) {
            topBar
                .frame(height: GameView.topBarHeight)
            HStack(alignment: .center, spacing: 10) {
                board(metrics.board)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 8) {
                    if vm.mode == .tutorial {
                        QuestBar(coach: vm.coach, opponent: vm.name(for: top),
                                 opponentThinking: vm.isThinking, nudge: vm.questNudge,
                                 nudgeText: vm.questNudgeText, onSkip: { vm.skipTutorial() })
                    } else {
                        PlayerBar(vm: vm, color: top, compactCards: true)
                    }
                    Spacer(minLength: 0)
                    HandView(vm: vm)
                    if vm.mode != .tutorial {
                        HintSlot(vm: vm)
                    }
                    PlayerBar(vm: vm, color: bottom, compactCards: true)
                }
                .frame(width: metrics.column)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    @ViewBuilder
    private func opponentStrip(_ top: PlayerColor) -> some View {
        if vm.mode == .tutorial {
            QuestBar(coach: vm.coach, opponent: vm.name(for: top),
                     opponentThinking: vm.isThinking, nudge: vm.questNudge,
                     nudgeText: vm.questNudgeText, onSkip: { vm.skipTutorial() })
                .padding(.horizontal, 8)
        } else {
            PlayerBar(vm: vm, color: top)
                .padding(.horizontal, 8)
                .frame(height: GameView.opponentBarHeight)
        }
    }

    /// Feste Brettgröße: Hinweise und Leisten, die kommen und gehen, verändern das Brett nicht.
    private func board(_ side: CGFloat) -> some View {
        BoardView(vm: vm)
            .frame(width: side, height: side)
            .modifier(ShakeEffect(animatableData: CGFloat(vm.shake)))
    }

    /// Brettgröße aus dem Platz, der nach allen festen Leisten übrig bleibt,
    /// sodass Karten und Hinweis-Blase vollständig darunter passen.
    static func boardSide(for size: CGSize, tutorial: Bool) -> CGFloat {
        // Karten: Ultimate 66 pt + Trenner + 4 Karten (Seitenverhältnis 0,8 plus Name darunter)
        let cardWidth = max(40, (size.width - 20 - 66 - 1 - 30) / 4)
        let cardHeight = max(cardWidth / 0.8 + 16, 66 / 0.8 + 15)
        let hand = 2 + 32 + 11 + cardHeight
        var reserved = topBarHeight + (tutorial ? questBarHeight : opponentBarHeight) + playerBarHeight + hand + 6 * 4 + 6
        if !tutorial { reserved += HintSlot.height + 6 }
        return max(180, min(size.width, size.height - reserved))
    }

    /// Querformat: größtes Quadrat, das unter die Titelleiste passt. Der Rest der Breite ist die Kartenspalte.
    static func wideMetrics(for size: CGSize) -> (board: CGFloat, column: CGFloat) {
        let maxBoard = max(160, size.height - topBarHeight - 10)
        let gap: CGFloat = 20
        let column = min(340, max(220, size.width - maxBoard - gap))
        let board = max(160, min(maxBoard, size.width - column - gap))
        return (board, column)
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
    /// Querformat: die gegnerischen Karten sind kleiner, damit das Brett die Höhe behält.
    var compactCards = false

    var body: some View {
        let active = vm.state.current == color && !vm.status.isOver
        let lost = vm.capturedPieces(lostBy: color.opponent)
        let balance = vm.state.materialBalance(for: color)

        HStack(spacing: 8) {
            portrait(active: active)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(vm.name(for: color))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if vm.onlineBotPlay != nil && color != vm.humanColor {
                        TrainingTag()
                    }
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
                                      cardWidth: color == vm.perspective ? 18 : (compactCards ? 24 : 36))
                }
            }
            Spacer(minLength: 4)
            if vm.timeControl.isTimed {
                LiveClockView(clock: vm.clock, color: color, active: active)
            }
        }
    }

    /// Der Spieler sieht immer seinen Avatar. Leiter- und Kampfgegner behalten ihren König.
    @ViewBuilder
    private func portrait(active: Bool) -> some View {
        let ring = color == vm.perspective ? Theme.blue : Theme.red
        if color == vm.humanColor && (vm.mode.isBot || vm.onlineOpponent != nil || vm.mode.isOnline) {
            PlayerAvatar(size: 34, pieceColor: color)
                .overlay(Circle().strokeBorder(ring, lineWidth: active ? 2.5 : 1))
        } else if let card = vm.onlineOpponent {
            PlayerAvatar(size: 34, pieceColor: color,
                         frame: card.frame.flatMap(AvatarFrame.init(rawValue:)) ?? AvatarFrame.none,
                         avatar: Avatar(rawValue: card.avatar) ?? .knight)
                .overlay(Circle().strokeBorder(ring, lineWidth: active ? 2.5 : 1))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(color == .white ? Color(hex: 0xE8E6E3) : Color(hex: 0x1B1A18))
                if vm.mode.isBot && color != vm.humanColor, let skin = vm.skin(for: color) {
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
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(ring, lineWidth: active ? 2.5 : 1))
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

/// Großer Moment in der Bildschirmmitte: Matt, Zeit, Aufgabe – und Remis. Lichtstrahlen, ein Band, das herein-
/// knallt, Funken; beim Sieg fällt eine Krone aufs Band, bei der Niederlage wackelt es.
struct FinisherTitle: View {
    enum Style { case win, loss, draw }
    let style: Style
    let headline: String
    let subline: String
    /// Matt/Zeit/Aufgabe warten auf das Platzen des Königs, Remis kommt sofort.
    var delay: Double = 0.78

    @Environment(\.liveAnimations) private var live
    @State private var shown = false
    @State private var crown = false
    @State private var burst = false
    @State private var shake: CGFloat = 0

    private var colors: [Color] {
        switch style {
        case .win: return [Color(hex: 0xFFD866), Color(hex: 0xF0A419)]
        case .loss: return [Color(hex: 0xE5636A), Color(hex: 0xA8323B)]
        case .draw: return [Color(hex: 0x9DB4DC), Color(hex: 0x5D6F92)]
        }
    }
    private var glow: Color { style == .win ? Theme.gold : style == .loss ? Theme.red : Theme.blueLight }

    var body: some View {
        ZStack {
            // Dunkler Hof, damit der Titel über dem Brett steht
            RadialGradient(colors: [Color.black.opacity(0.55), .clear], center: .center, startRadius: 20, endRadius: 230)
                .frame(width: 520, height: 420)
                .opacity(shown ? 1 : 0)
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || !shown)) { tl in
                FinisherRays(count: 14)
                    .fill(RadialGradient(colors: [glow.opacity(0.55), glow.opacity(0)], center: .center, startRadius: 10, endRadius: 190))
                    .frame(width: 380, height: 380)
                    .rotationEffect(.degrees(tl.date.timeIntervalSinceReferenceDate * 18))
            }
            .scaleEffect(shown ? 1 : 0.2)
            .opacity(shown ? (style == .loss ? 0.6 : 1) : 0)
            if burst {
                Shockwave(color: glow, maxScale: 3.2, lineWidth: 5, duration: 0.6)
                    .frame(width: 120, height: 120)
                if style != .loss {
                    ParticleBurst(seed: 41, count: 18, colors: [Theme.gold, .white, colors[0]], symbol: "star.fill",
                                  radius: 170, size: 13, duration: 0.9, gravity: 60)
                        .frame(width: 10, height: 10)
                }
            }
            VStack(spacing: 10) {
                ZStack {
                    Text(headline)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .italic()
                        .foregroundColor(style == .win ? Theme.navy : .white)
                        .shadow(color: .white.opacity(style == .win ? 0.5 : 0), radius: 0, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            VictoryRibbonShape()
                                .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                                .shadow(color: colors[1].opacity(0.7), radius: 0, y: 6)
                                .shadow(color: glow.opacity(0.6), radius: 18)
                        )
                    if style == .win {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                            .shadow(color: .black.opacity(0.4), radius: 0, y: 2)
                            .rotationEffect(.degrees(crown ? -14 : 30))
                            .offset(x: -6, y: crown ? -46 : -160)
                            .opacity(crown ? 1 : 0)
                    }
                }
                .modifier(ShakeEffect(amount: 7, shakes: 3, animatableData: shake))
                Text(subline)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
                    .opacity(crown || style != .win ? (shown ? 1 : 0) : 0)
            }
            .scaleEffect(shown ? 1 : 2.6)
            .rotationEffect(.degrees(shown ? -3 : -16))
            .opacity(shown ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.55).delay(delay)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.18) {
                burst = true
                if style == .loss { withAnimation(.linear(duration: 0.45)) { shake = 1 } }
            }
            if style == .win {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.45).delay(delay + 0.28)) { crown = true }
            }
        }
    }
}

/// Strahlenkranz (abwechselnd Keil und Lücke) hinter dem Titel.
struct FinisherRays: Shape {
    var count: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = max(rect.width, rect.height) / 2
        let step = 2 * Double.pi / Double(count * 2)
        for i in 0..<count {
            let a0 = Double(i) * 2 * step, a1 = a0 + step
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + cos(a0) * r, y: c.y + sin(a0) * r))
            p.addLine(to: CGPoint(x: c.x + cos(a1) * r, y: c.y + sin(a1) * r))
            p.closeSubpath()
        }
        return p
    }
}

/// Kennzeichen für den Bot-Ersatz online (wie .training-tag in web/src/screens.css).
struct TrainingTag: View {
    var large = false

    var body: some View {
        Text(L("Trainingsgegner"))
            .font(.system(size: large ? 12 : 10, weight: .heavy, design: .rounded))
            .tracking(0.3)
            .foregroundColor(Color(hex: 0x0B1B33))
            .lineLimit(1)
            .padding(.horizontal, large ? 10 : 6)
            .frame(height: large ? 22 : 17)
            .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0x8FE3A3), Color(hex: 0x4FBF6A)],
                                                      startPoint: .top, endPoint: .bottom)))
            .fixedSize()
    }
}

import SwiftUI

@main
struct RookRaidApp: App {
    /// Nur für das APNs-Token der Freundschafts-Push-Nachrichten
    @UIApplicationDelegateAdaptor(RookRaidAppDelegate.self) private var appDelegate
    init() { FlameReminders.install() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

extension Notification.Name {
    static let startTutorial = Notification.Name("RookRaidStartTutorial")
    static let showTrophyRoad = Notification.Name("RookRaidShowTrophyRoad")
    /// Zum Puzzle-Tab wechseln (z. B. „Flamme entzünden“)
    static let showPuzzles = Notification.Name("RookRaidShowPuzzles")
    static let startPractice = Notification.Name("RookRaidStartPractice")
    /// Direkt die nächste Partie (Objekt: `GameMode`) – aus dem Ergebnisfenster
    static let startGame = Notification.Name("RookRaidStartGame")
    static let openSettings = Notification.Name("RookRaidOpenSettings")
    /// Zum Deck-Tab wechseln (z. B. aus der Sammlung im Profil)
    static let showDeck = Notification.Name("RookRaidShowDeck")
    /// Zum Spielen-Tab wechseln und die Bot-Leiter öffnen
    static let showLadder = Notification.Name("RookRaidShowLadder")
    /// Zum Spielen-Tab wechseln und sofort „Kampf!“ starten (Ende der Deck-Werkstatt)
    static let startQuickBattle = Notification.Name("RookRaidStartQuickBattle")
    /// Zu zweit an einem Gerät, ohne Trophäen (aus den Einstellungen)
    static let startHotSeat = Notification.Name("RookRaidStartHotSeat")
    /// Zum Spielen-Tab wechseln und die erste wartende Truhe öffnen (Rockys Einladung)
    static let openPendingChest = Notification.Name("RookRaidOpenPendingChest")
    /// Freundesliste öffnen (Push-Tipp, Einladungslink, Hinweis oben). Objekt: optional ein Freundescode
    static let showFriends = Notification.Name("RookRaidShowFriends")
    /// Freundschaftsspiel steht bereit. Objekt: die Partie-ID (UUID)
    static let startFriendMatch = Notification.Name("RookRaidStartFriendMatch")
}

struct GameSession: Identifiable {
    let id = UUID()
    let vm: GameViewModel
}

/// Träger der laufenden Partie im Vollbild. „Nächstes Spiel“ tauscht hier nur das Modell aus –
/// das Vollbild bleibt offen. (Vorher wurde die Sitzung der Startseite ersetzt, während das Vollbild
/// noch offen war; SwiftUI hat dann die alte Partie geschlossen, die neue aber nicht geöffnet.)
struct GameHost: View {
    @State private var vm: GameViewModel

    init(vm: GameViewModel) {
        _vm = State(initialValue: vm)
    }

    var body: some View {
        ZStack {
            GameView(viewModel: vm)
                .id(ObjectIdentifier(vm))
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.04)), removal: .opacity))
        }
        .background(Theme.background.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: .startGame)) { note in
            guard let mode = note.object as? GameMode else { return }
            let store = ProfileStore.shared
            let settings = store.profile.settings
            store.clearGame()
            // Farbe immer 50 : 50 (auch gegen Bots und in der Leiter).
            let next = GameViewModel(mode: mode, humanColor: Bool.random() ? .white : .black,
                                     timeControl: mode.isBot ? settings.timeControl : .none)
            vm.flushStats()
            withAnimation(.easeInOut(duration: 0.35)) { vm = next }
        }
    }
}

enum RootTab: Hashable {
    case play, puzzles, deck, arena, profile
}

struct RootView: View {
    @ObservedObject private var store = ProfileStore.shared
    @State private var tab: RootTab = .play
    @State private var session: GameSession?
    @State private var puzzleSession: PuzzleSession?
    /// Interaktive Einführung vor der ersten Schlacht – beim Schließen startet die Tutorial-Partie.
    @State private var showIntro = false
    @State private var showSplash = true
    @State private var lastTab: RootTab = .play
    /// Eine Animationsuhr je Tab: Ein angehaltener Tab macht beim Zurückkehren dort weiter, wo er stand.
    @State private var clocks = AnimationClocks()
    @State private var settleTask: Task<Void, Never>?
    /// Der Deck-Tab wurde verlassen – „neue Karten gesehen“ wird nach dem Wechsel gespeichert, nicht währenddessen.
    @State private var seenPending = false
    /// Einstellungen hängen außerhalb des neu aufgebauten Bereichs – ein Sprachwechsel schließt sie nicht.
    @State private var showSettings = false
    /// Rocky lädt nach der ersten Partie in die Deck-Werkstatt ein (v0.9.32)
    @State private var showRockyInvite = false
    /// Nach 3 Online-Partien einmal: anonymes Konto mit Apple sichern
    @State private var showAppleSecure = false
    /// „Später“ – in dieser Sitzung nicht noch einmal fragen
    @State private var inviteSnoozed = false
    @ObservedObject private var account = OnlineAccount.shared
    @ObservedObject private var friends = FriendsStore.shared
    /// Freundesliste als Sheet; der Code kommt aus einem Einladungslink.
    @State private var friendsSheet: FriendsInvite?
    @Environment(\.scenePhase) private var scenePhase

    /// Nur der gewählte Tab animiert. Beim Wechsel hält der alte sofort an und der neue läuft sofort los –
    /// es zeichnet also nie mehr als eine Seite, und die neue gleitet schon lebendig herein (statt erst danach
    /// loszulegen). Ihre Uhr setzt dort fort, wo sie zuletzt stand, deshalb springt nichts.
    private func isLive(_ t: RootTab) -> Bool {
        tab == t && session == nil && puzzleSession == nil
    }

    private func page<V: View>(_ t: RootTab, _ view: V) -> some View {
        let live = isLive(t)
        return view
            // Sprachwechsel baut nur den Inhalt der Seite neu auf, nicht den Seiten-Container: Ein neu angelegter
            // TabView mit einer anderen Seite als der ersten zeigt sonst manchmal eine leere Seite (Profil leer).
            .id(store.profile.settings.language)
            .environment(\.liveAnimations, live)
            .environment(\.animationClock, clocks.clock(t, live: live))
            .tag(t)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Seiten-Container: Zwischen den Tabs lässt sich mit dem Finger wischen.
                // Reihenfolge wie die Tab-Leiste: Pfad · Puzzle · Spielen (Mitte, Start) · Deck · Profil
                TabView(selection: $tab) {
                    page(.arena, TrophyRoadView())
                    page(.puzzles, PuzzleHubView(session: $puzzleSession))
                    page(.play, HomeView(session: $session, puzzleSession: $puzzleSession, tab: $tab))
                    page(.deck, DeckView())
                    page(.profile, ProfileView())
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Theme.background.ignoresSafeArea())

                RootTabBar(tab: $tab)
                    .id(store.profile.settings.language)
                    .environment(\.liveAnimations, session == nil && puzzleSession == nil)
                    .environment(\.animationClock, clocks.clock("tabBar", live: session == nil && puzzleSession == nil))
            }
            .environment(\.locale, store.profile.settings.language.locale)
            .background(Theme.background.ignoresSafeArea())
            .onAppear {
                Feedback.apply(settings: store.profile.settings)
                store.checkStreak()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    store.checkStreak()
                    Task { await FlameReminders.sync() }
                    friends.startPolling()
            FriendMatchCenter.shared.start()
                    if session == nil, puzzleSession == nil {
                        Task { await OnlineAccount.shared.reload() }
                    }
                }
                if phase != .active { store.flushSave(); friends.stopPolling() }
                if phase == .background { OnlineAccount.shared.backupQuietly() }
            }
            .onChange(of: tab) { newTab in
                Haptics.shared.play(.select)
                if newTab != .play && showRockyInvite {
                    withAnimation(.easeOut(duration: 0.2)) { showRockyInvite = false }
                }
                // Wer den Deck-Tab verlässt, hat die neuen Karten gesehen.
                if lastTab == .deck && newTab != .deck { seenPending = true }
                lastTab = newTab
                // Speichern erst nach dem Wisch, damit er nicht von der Festplatte aufgehalten wird.
                settleTask?.cancel()
                settleTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 320_000_000)
                    guard !Task.isCancelled else { return }
                    if seenPending && tab != .deck {
                        seenPending = false
                        store.markAllSeen()
                    }
                }
            }
            .fullScreenCover(item: $session) { s in
                GameHost(vm: s.vm)
            }
            .background(
                // Eigener Träger, damit sich die beiden Vollbild-Ansichten nicht in die Quere kommen.
                Color.clear
                    .fullScreenCover(item: $puzzleSession) { s in
                        PuzzlePlayer(vm: s.vm)
                    }
            )
            .background(
                Color.clear
                    .fullScreenCover(isPresented: $showIntro, onDismiss: {
                        session = GameSession(vm: GameViewModel(mode: .tutorial, humanColor: .white, timeControl: .none))
                    }) {
                        IntroView { showIntro = false }
                    }
            )

            if showRockyInvite && !showSplash {
                RockyInviteOverlay(chestsWaiting: !store.pendingChests.isEmpty, onPrimary: {
                    if store.pendingChests.isEmpty {
                        withAnimation(.easeOut(duration: 0.25)) { showRockyInvite = false }
                        tab = .deck
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { showRockyInvite = false }
                        tab = .play
                        NotificationCenter.default.post(name: .openPendingChest, object: nil)
                    }
                }, onSecondary: {
                    withAnimation(.easeOut(duration: 0.25)) { showRockyInvite = false }
                    if store.pendingChests.isEmpty {
                        inviteSnoozed = true
                    } else {
                        tab = .deck
                    }
                })
                .transition(.opacity)
                .zIndex(8)
            }

            if showAppleSecure && !showSplash && !showRockyInvite {
                RockyAppleSecureOverlay {
                    withAnimation(.easeOut(duration: 0.25)) { showAppleSecure = false }
                }
                .transition(.opacity)
                .zIndex(9)
            }

            if !showSplash, session == nil, puzzleSession == nil, store.profile.freezeNotice == nil,
               let streak = store.flameCelebration {
                FlameIgnitionOverlay(streak: streak) {
                    withAnimation(.easeOut(duration: 0.25)) { store.flameCelebration = nil }
                    Task { await FlameReminders.askIfReady() }
                }
                .transition(.opacity)
                .zIndex(9)
            }

            if !showSplash, let days = store.profile.freezeNotice {
                FreezeNoticeOverlay(days: days, streak: store.currentStreak) {
                    withAnimation(.easeOut(duration: 0.25)) { store.profile.freezeNotice = nil }
                }
                .transition(.opacity)
                .zIndex(9)
            }

            if !showSplash, session == nil, puzzleSession == nil, friends.news != nil {
                FriendBanner(onOpen: { openFriends(nil) }, onOpenChest: { id in
                    tab = .play
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        NotificationCenter.default.post(name: .openPendingChest, object: id)
                    }
                })
                    .zIndex(9.5)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .modifier(FriendsLinks(sheet: $friendsSheet, friends: friends, account: account, open: openFriends))
        .modifier(FriendMatchLinks(center: FriendMatchCenter.shared, friendsSheet: $friendsSheet, tab: $tab,
                                   quiet: showSplash || session != nil || puzzleSession != nil))
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in showSettings = true }
        .onReceive(NotificationCenter.default.publisher(for: .showPuzzles)) { _ in tab = .puzzles }
        .onReceive(NotificationCenter.default.publisher(for: .showTrophyRoad)) { _ in tab = .arena }
        .onReceive(NotificationCenter.default.publisher(for: .showDeck)) { _ in tab = .deck }
        .onReceive(NotificationCenter.default.publisher(for: .showLadder)) { _ in tab = .play }
        .onReceive(NotificationCenter.default.publisher(for: .startQuickBattle)) { _ in tab = .play }
        // Rockys Einladung: nach jeder geschlossenen Partie bzw. sobald alle Truhen offen sind
        .onChange(of: session?.id) { id in
            if id == nil {
                Task { await OnlineAccount.shared.reload() }
                if account.hasAccount, let code = friends.pendingInvite {
                    friends.pendingInvite = nil
                    openFriends(code)
                }
                scheduleRockyInvite(after: 0.9)
                scheduleAppleSecure(after: 1.1)
            }
        }
        .onChange(of: puzzleSession?.id) { id in
            if id == nil { Task { await OnlineAccount.shared.reload() } }
        }
        .onChange(of: store.flameCelebration) { value in
            if value == nil {
                scheduleRockyInvite(after: 0.4)
                scheduleAppleSecure(after: 0.6)
            }
        }
        .onChange(of: showRockyInvite) { shown in
            if !shown { scheduleAppleSecure(after: 0.4) }
        }
        .modifier(AccountRestoreAlert(settingsOpen: showSettings))
        .onChange(of: store.pendingChests.count) { n in
            if n == 0 { scheduleRockyInvite(after: 1.0) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startPractice)) { _ in
            // „Deck testen“: lockere Übungspartie mit dem aktuellen Deck, ohne Trophäen (nur mit vollem Deck)
            guard store.deckIsFull else { return }
            session = GameSession(vm: GameViewModel(mode: .practice(.easy), humanColor: .white, timeControl: .none))
        }
        .onReceive(NotificationCenter.default.publisher(for: .startTutorial)) { _ in
            showIntro = true
        }
        .task {
            // Startbildschirm kurz zeigen, dann – beim ersten Start – direkt in die erste Schlacht
            try? await Task.sleep(nanoseconds: UInt64((SplashView.duration + 0.35) * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            await FlameReminders.askIfReady()
            await PushRegistration.shared.syncIfAllowed()
            friends.startPolling()
            // Kartenbilder im Hintergrund vorbereiten, ohne den Start aufzuhalten (v0.9.25)
            Task {
                await CardArtImage.preload()
                await PreparedImages.preload()
            }
            if !store.profile.tutorialSeen {
                try? await Task.sleep(nanoseconds: 250_000_000)
                showIntro = true
            } else {
                scheduleRockyInvite(after: 0.5)
            }
        }
    }

    /// Freundesliste öffnen. Ohne Konto wartet der Code, bis eins angelegt ist (die Liste zeigt dann „Konto erstellen“).
    private func openFriends(_ code: String?) {
        friends.news = nil
        if let code, !account.hasAccount { friends.pendingInvite = code }
        if session != nil || puzzleSession != nil {
            // Mitten in einer Partie nicht stören: nach dem Ende zeigt der Hinweis oben die Anfrage.
            if let code { friends.pendingInvite = code }
            return
        }
        tab = .profile
        friendsSheet = FriendsInvite(code: code)
    }

    /// Rocky lädt in die Deck-Werkstatt ein – nur auf der Startseite, ohne laufende Partie und nur, solange die Tour aussteht.
    private func scheduleRockyInvite(after delay: Double) {
        guard store.needsDeckTour, !inviteSnoozed, !showRockyInvite else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard store.needsDeckTour, !inviteSnoozed, !showRockyInvite, !showSplash,
                  session == nil, puzzleSession == nil, tab == .play,
                  store.flameCelebration == nil else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showRockyInvite = true }
        }
    }

    /// Einmalig, nachdem Rocky mit der Deck-Einladung fertig ist und keine Partie offen ist.
    private func scheduleAppleSecure(after delay: Double) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !showAppleSecure, !showRockyInvite, !showSplash, session == nil,
                  store.flameCelebration == nil else { return }
            guard account.consumeApplePrompt() else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showAppleSecure = true }
        }
    }
}

/// Eigene Tab-Leiste: folgt dem Wischen zwischen den Seiten, die aktive Seite trägt eine blaue Kapsel.
/// Freundesliste als Sheet, Einladungslinks, Push-Tipps und Kontowechsel – eigener Modifier, damit der
/// Ausdruck in RootView.body für den Compiler überschaubar bleibt.
private struct FriendsLinks: ViewModifier {
    @Binding var sheet: FriendsInvite?
    @ObservedObject var friends: FriendsStore
    @ObservedObject var account: OnlineAccount
    let open: (String?) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheet) { item in FriendsSheet(invite: item.code) }
            .onReceive(NotificationCenter.default.publisher(for: .showFriends)) { note in open(note.object as? String) }
            // Einladungslink https://<Domain>/f/<Code> (Universal Link) – öffnet die Freundesliste mit dem Code.
            .onOpenURL { url in
                if let code = FriendCode.from(url: url) { open(code) }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL, let code = FriendCode.from(url: url) { open(code) }
            }
            // Konto da (neu angelegt, angemeldet): Freunde laden, Push anmelden, wartende Einladung zeigen.
            .onChange(of: account.status) { _ in
                Task { @MainActor in
                    if !account.hasAccount { FriendMatchCenter.shared.reset() }
                    await friends.refresh()
                    await FriendMatchCenter.shared.touch()
                    await PushRegistration.shared.syncIfAllowed()
                    if account.hasAccount, let code = friends.pendingInvite {
                        friends.pendingInvite = nil
                        open(code)
                    }
                }
            }
    }
}

struct RootTabBar: View {
    @Binding var tab: RootTab
    @ObservedObject var store = ProfileStore.shared
    @ObservedObject private var friends = FriendsStore.shared

    /// Zahl oder Punkt am Tab: wartende Truhen, Tagespuzzle, neue Karten, abholbare Pfad-Belohnungen.
    private func badge(_ t: RootTab) -> (count: Int, dot: Bool) {
        switch t {
        case .play: return (store.pendingChests.count + (store.dailyChestReady ? 1 : 0), false)
        case .puzzles: return (0, store.dailyBonusAvailable)
        case .deck: return (store.newCardCount, store.profile.tutorialSeen && !store.deckIsFull)
        case .arena: return (store.claimableRoadSteps.count, false)
        case .profile: return (store.claimableAchievements.count + friends.incoming.count, false)
        }
    }

    private let items: [(RootTab, String, String)] = [
        (.arena, L("Pfad"), "trophy.fill"),
        (.puzzles, L("Puzzles"), "puzzlepiece.fill"),
        (.play, L("Spielen"), "bolt.fill"),
        (.deck, L("Deck"), "rectangle.stack.fill"),
        (.profile, L("Profil"), "person.crop.circle.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in sideItem(items[i]) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Theme.backgroundDeep
                .overlay(Rectangle().fill(Theme.panelHighlight).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: tab)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: store.pendingChests.count)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: store.claimableRoadSteps.count)
    }

    private func sideItem(_ item: (RootTab, String, String)) -> some View {
        let active = tab == item.0
        return Button {
            // Ohne withAnimation: der Seitenwechsel selbst gleitet, der Inhalt wird nicht mitanimiert.
            guard tab != item.0 else { return }
            tab = item.0
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    // Jede Kapsel leuchtet für sich (kein wanderndes Element, das hängen bleiben kann)
                    Capsule()
                        .fill(Theme.blue)
                        .frame(width: 52, height: 30)
                        .shadow(color: Theme.blue.opacity(0.6), radius: 8)
                        .opacity(active ? 1 : 0)
                        .scaleEffect(active ? 1 : 0.6)
                    Image(systemName: item.2)
                        .font(.system(size: active ? 18 : 17, weight: .bold))
                        .foregroundColor(active ? .white : Theme.textMuted)
                        .scaleEffect(active ? 1.08 : 1)
                }
                .frame(height: 30)
                .overlay(alignment: .topTrailing) { badgeView(badge(item.0)) }
                Text(item.1)
                    .font(.system(size: 10, weight: active ? .heavy : .semibold))
                    .foregroundColor(active ? Theme.textPrimary : Theme.textMuted)
                Capsule()
                    .fill(Theme.blueLight)
                    .frame(width: active ? 20 : 0, height: 3)
                    .opacity(active ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.1)
        .accessibilityValue(badge(item.0).count > 0 ? L("{0} neu", badge(item.0).count) : "")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

extension RootTabBar {
    @ViewBuilder
    func badgeView(_ b: (count: Int, dot: Bool)) -> some View {
        if b.count > 0 {
            Text(b.count > 9 ? "9+" : "\(b.count)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(Theme.red))
                .overlay(Capsule().strokeBorder(Theme.backgroundDeep, lineWidth: 2))
                .offset(x: 8, y: -4)
                .transition(.scale.combined(with: .opacity))
        } else if b.dot {
            Circle()
                .fill(Theme.red)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Theme.backgroundDeep, lineWidth: 2))
                .offset(x: 4, y: -2)
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Startseite

struct HomeView: View {
    @ObservedObject var store = ProfileStore.shared
    @Binding var session: GameSession?
    @Binding var puzzleSession: PuzzleSession?
    @Binding var tab: RootTab
    @State var showLadder = false
    @State var chestToOpen: Chest?
    @State var showDaily = false
    @State var showEmptyDeck = false
    @StateObject private var matchmaking = MatchmakingController()
    @State private var showMatchmaking = false
    @State private var showNameForOnline = false
    @State private var matchError: String?
    @State private var rulesNotice: OnlineRulesLock?
    @State private var didSeekOnlineResume = false
    /// Laufende Online-Partie, die verlassen wurde (Zurück-Knopf). Sie bleibt im Speicher und lässt sich über
    /// „Partie fortsetzen“ wieder öffnen – nach 45 s ohne Lebenszeichen wertet der Server sie als verloren.
    @State private var parkedGame: GameViewModel?
    /// Die gerade offene Partie (damit sie beim Schließen geparkt werden kann)
    @State private var liveGame: GameViewModel?
    /// Laufende Partie gegen einen Menschen auf dem Server (z. B. nach einem Neustart der App)
    @State private var resumableMatch: UUID?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                // Oben schimmert die Farbe deiner Arena
                LinearGradient(colors: [ArenaPalette.colors(store.arena.number)[1].opacity(0.6), .clear],
                               startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
                // Alles auf einen Bildschirm (v0.9.24). Seit v0.9.25 ohne ViewThatFits: Das hielt drei Fassungen samt
                // Animationen gleichzeitig im Speicher. Jetzt entscheidet die verfügbare Höhe über groß oder kompakt;
                // der ScrollView springt nur an, wenn selbst die kompakte Fassung nicht passt (z. B. iPhone SE).
                GeometryReader { geo in
                    let compact = geo.size.height < (store.hasSavedGame ? 780 : 705)
                    // Große iPhones (v0.9.28): Avatar und Deck größer; übriger Platz geht in die Kampf-Bühne statt in eine Lücke.
                    let large = geo.size.height >= (store.hasSavedGame ? 860 : 785)
                    ScrollView(showsIndicators: false) {
                        page(compact: compact, large: large)
                            .frame(minHeight: geo.size.height, alignment: .top)
                    }
                    .modifier(BounceOnlyIfNeeded())
                }
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .showLadder)) { _ in
                afterSheet { showLadder = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startQuickBattle)) { _ in
                afterSheet { quickBattle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startFriendMatch)) { note in
                guard let id = note.object as? UUID else { return }
                afterSheet { Task { await startFriendMatch(id) } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPendingChest)) { note in
                // Mit ID (z. B. die Freundestruhe): genau diese Truhe, sonst die erste wartende
                let wanted = (note.object as? UUID).flatMap { id in store.pendingChests.first { $0.id == id } }
                afterSheet { chestToOpen = wanted ?? store.pendingChests.first }
            }
            .fullScreenCover(item: $chestToOpen) { c in ChestOpeningView(start: c) }
            .sheet(isPresented: $showLadder) {
                LadderView { level in
                    showLadder = false
                    guard store.deckIsFull else {
                        afterSheet { showEmptyDeck = true }
                        return
                    }
                    store.clearGame()
                    // Bot-Leiter ohne Uhr (v0.9.34)
                    session = GameSession(vm: GameViewModel(mode: .ladder(level), humanColor: Bool.random() ? .white : .black,
                                                            timeControl: .none))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startHotSeat)) { _ in
                afterSheet { start(mode: .hotSeat, humanColor: .white) }
            }
            // Ohne volles Deck kein Spiel (v0.9.31) – falls ein Weg am Kampf-Knopf vorbeiführt (Tagesziel, Zu zweit)
            .alert(L("Dein Deck braucht 4 Karten"), isPresented: $showEmptyDeck) {
                Button(L("Zum Deck")) { tab = .deck }
                Button(L("Abbrechen"), role: .cancel) {}
            } message: {
                Text(L("Du hast {0} von {1} Karten. Stell dein Deck fertig, dann geht's los.", store.activeDeck.count, PlayerDeck.size))
            }
            .sheet(isPresented: $showDaily) {
                ChestHubSheet(onGoal: { kind in afterSheet { handleGoal(kind) } },
                              onChest: { afterSheet { openChest() } },
                              onOpen: { chest in afterSheet { chestToOpen = chest } })
            }
            .fullScreenCover(isPresented: $showMatchmaking) {
                MatchmakingSheet(controller: matchmaking) {
                    matchmaking.cancel()
                    showMatchmaking = false
                }
            }
            .sheet(isPresented: $showNameForOnline) {
                OnlineNameSheet(purpose: .create) { afterSheet { startOnlineSearch() } }
            }
            .alert(L("Keine Verbindung"), isPresented: Binding(
                get: { matchError != nil },
                set: { if !$0 { matchError = nil } }
            )) {
                Button(L("Fertig"), role: .cancel) { matchError = nil }
            } message: {
                Text(matchError ?? "")
            }
            .alert(rulesNotice?.title ?? "", isPresented: Binding(
                get: { rulesNotice != nil },
                set: { if !$0 { rulesNotice = nil } }
            )) {
                Button(L("Fertig"), role: .cancel) { rulesNotice = nil }
            } message: {
                Text(rulesNotice?.detail ?? "")
            }
            .task { await prepareOnline() }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                Task {
                    await OnlineRules.shared.refresh(deferAdopt: session != nil || store.hasSavedGame)
                }
            }
            .onChange(of: session?.id) { id in
                if id == nil {
                    OnlineRules.shared.applyPending(deferAdopt: store.hasSavedGame)
                    if let vm = liveGame, vm.canResumeOnline { parkedGame = vm }
                    liveGame = nil
                    Task { await refreshResumableMatch() }
                } else {
                    liveGame = session?.vm
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active, session == nil { Task { await refreshResumableMatch() } }
            }
            .onChange(of: matchmaking.phase) { phase in
                handleMatchmaking(phase)
            }
        }
    }

    private func page(compact: Bool, large: Bool = false) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            header
            if canContinue {
                ContinueBanner(compact: compact) { resume() }
            }
            BattleHeroCard(compact: compact, large: large,
                           onBattle: quickBattle,
                           onChests: { showDaily = true },
                           onDeck: { tab = .deck },
                           onArena: { tab = .arena })
            LadderTile(compact: compact) { showLadder = true }
        }
        .padding(.horizontal, 16)
        .padding(.top, compact ? 4 : 8)
        .padding(.bottom, compact ? 10 : 16)
    }

    private var header: some View {
        HStack(spacing: 8) {
            LevelBadge(level: store.level, progress: store.levelProgress.fraction)
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Level {0}", store.level))
                    .lineLimit(1)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(L("noch {0} XP", store.levelProgress.remaining))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(-1)
            Spacer(minLength: 8)
            FlameBadge()
            ShardPill()
            HStack(spacing: 4) {
                Image(systemName: "trophy.fill").foregroundColor(Theme.gold)
                Text("\(store.profile.trophies)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.panelRaised))
            .onTapGesture { tab = .arena }
        }
    }

    /// Ein Tipp auf „Kampf!“ startet sofort: Gegner passend zu den Trophäen (alle 200 eine Stufe).
    /// Online (Schritt 8): erst Konto, dann Suche; nach 10 s Bot-Ersatz.
    /// Weichen die Regeln vom Server ab, bleibt die Suche zu (Schritt 10).
    private func quickBattle() {
        guard NetworkMonitor.shared.isOnline else {
            Haptics.shared.play(.invalid)
            return
        }
        if OnlineConfig.isLive {
            guard store.deckIsFull else {
                Haptics.shared.play(.invalid)
                showEmptyDeck = true
                return
            }
            Task { await beginOnline() }
            return
        }
        start(mode: .bot(BotLevel.forTrophies(store.profile.trophies)), humanColor: Bool.random() ? .white : .black)
    }

    /// Regeln abgleichen, dann Konto oder Suche. Eine laufende oder gespeicherte Partie behält ihre Fassung.
    private func beginOnline() async {
        let busy = session != nil || store.hasSavedGame
        await OnlineRules.shared.refresh(deferAdopt: busy)
        OnlineRules.shared.applyPending(deferAdopt: busy)
        if OnlineRules.shared.lock != .open {
            Haptics.shared.play(.invalid)
            rulesNotice = OnlineRules.shared.lock
            return
        }
        if OnlineAccount.shared.hasAccount {
            startOnlineSearch()
        } else {
            showNameForOnline = true
        }
    }

    private func startOnlineSearch() {
        showMatchmaking = true
        matchmaking.start()
        PendingBotReports.retryIfNeeded()
    }

    private func handleMatchmaking(_ phase: MatchmakingController.Phase) {
        switch phase {
        case .found(let found):
            // Erst kurz „Gegner gefunden“ zeigen, dann das Suchfenster schließen – und die Partie erst öffnen, wenn das
            // Fenster ganz weg ist. (Vorher öffnete die Partie im selben Moment, in dem sich das Suchfenster schloss;
            // SwiftUI verwirft dann das zweite Vollbild, und die gefundene Partie ging nie auf.)
            Feedback.play(.reward, .victory)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard case .found = matchmaking.phase else { return }
                showMatchmaking = false
                matchmaking.phase = .idle
                afterSheet { startFoundMatch(found) }
            }
        case .failed(let message):
            showMatchmaking = false
            if message == L("Bitte aktualisiere Rook Raid, um online zu spielen.") {
                rulesNotice = OnlineRules.shared.lock == .serverBehind ? .serverBehind : .updateAvailable
            } else {
                matchError = message
            }
        case .idle, .searching:
            break
        }
    }

    private func startFoundMatch(_ found: MatchFound) {
        guard store.deckIsFull else { return }
        if found.kind == .human, let id = found.matchId {
            Task { await startHumanMatch(id) }
            return
        }
        guard let level = found.botLevel, let id = found.matchId else { return }
        parkedGame = nil
        store.clearGame()
        let play = OnlineBotPlay(matchId: id, opponent: found.opponent, deck: found.botDeck,
                                 ultimate: found.botUltimate, rated: found.rated)
        session = GameSession(vm: GameViewModel(mode: .bot(level),
                                                humanColor: found.youAreWhite ? .white : .black,
                                                timeControl: OnlineConfig.timeControl,
                                                onlineBotPlay: play))
    }

    /// Freundschaftsspiel: gegen einen Menschen wie eine Online-Partie, gegen einen Bot-Spieler wie der Bot-Ersatz
    /// (der Bot rechnet auf dem Gerät, ohne Trophäen).
    private func startFriendMatch(_ id: UUID) async {
        guard session == nil, let client = Backend.client else { return }
        guard let info = try? await OnlineMatches.load(id: id, client: client) else {
            matchError = L("Keine Verbindung zum Server.")
            return
        }
        if !info.isBot {
            await startHumanMatch(id)
            return
        }
        let mine = info.myColor
        var card = info.opponent
        card.bot = true
        let found = MatchFound(kind: .bot, opponent: card,
                               botLevel: info.botLevel ?? BotLevel.forTrophies(card.trophies),
                               youAreWhite: mine == .white, matchId: id,
                               botDeck: info.record.decks[mine.opponent.rawValue]?.compactMap(CardType.init(rawValue:)),
                               botUltimate: info.record.ultimates[mine.opponent.rawValue].flatMap(Ultimate.init(rawValue:)),
                               rated: info.rated)
        startFoundMatch(found)
    }

    private func startHumanMatch(_ id: UUID, resumed: Bool = false) async {
        guard let client = Backend.client else {
            matchError = L("Keine Verbindung zum Server.")
            return
        }
        do {
            let info = try await OnlineMatches.load(id: id, client: client)
            guard !info.isBot, info.record.actions.count < 800 else { return }
            let live = SupabaseMatchSession(info: info, client: client)
            parkedGame = nil
            resumableMatch = nil
            store.clearGame()
            session = GameSession(vm: GameViewModel(online: info, session: live, resumed: resumed))
        } catch {
            matchError = L("Keine Verbindung zum Server.")
        }
    }

    /// App-Start: Regeln mit dem Server abgleichen, dann eine laufende Partie gegen einen Menschen wieder öffnen.
    /// Die Übernahme einer neueren Fassung wartet, bis diese Partie (oder ein lokaler Spielstand) zu Ende ist.
    private func prepareOnline() async {
        guard !didSeekOnlineResume, OnlineConfig.isLive, session == nil, let client = Backend.client else { return }
        didSeekOnlineResume = true
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard session == nil else { return }
        let active = await OnlineMatches.activeHumanMatch(client: client)
        await OnlineRules.shared.refresh(deferAdopt: active != nil || store.hasSavedGame)
        guard session == nil, let active else { return }
        await startHumanMatch(active, resumed: true)
    }

    private func handleGoal(_ kind: ProfileStore.DailyGoal.Kind) {
        switch kind {
        case .flame, .puzzle: openDailyPuzzle()
        case .win: quickBattle()
        }
    }

    /// Tagesziele geschafft: Die Goldtruhe kommt ins Lager und wird sofort geöffnet.
    private func openChest() {
        guard let chest = store.claimDailyChest() else { return }
        chestToOpen = chest
    }

    /// Ein Fenster schließt sich gerade – kurz warten, bevor das nächste Vollbild aufgeht.
    private func afterSheet(_ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            action()
        }
    }

    private func openDailyPuzzle() {
        guard let p = store.dailyPuzzle, let vm = PuzzleViewModel(puzzle: p, isDaily: true) else { return }
        puzzleSession = PuzzleSession(vm: vm)
    }

    private func start(mode: GameMode, humanColor: PlayerColor) {
        parkedGame = nil
        guard store.deckIsFull else {
            Haptics.shared.play(.invalid)
            showEmptyDeck = true
            return
        }
        store.clearGame()
        // Kampf ist fest 5 | 0. Zu zweit am Gerät läuft ohne Uhr und ohne Trophäen.
        let tc: TimeControl = {
            if case .bot = mode { return .blitz5 }
            return .none
        }()
        session = GameSession(vm: GameViewModel(mode: mode, humanColor: humanColor, timeControl: tc))
    }

    /// Etwas zum Fortsetzen: eine verlassene Online-Partie, eine laufende Partie auf dem Server oder ein Spielstand.
    private var canContinue: Bool {
        (parkedGame?.canResumeOnline ?? false) || resumableMatch != nil || store.hasSavedGame
    }

    /// Fragt den Server nach einer laufenden Partie gegen einen Menschen (nur ohne offene oder geparkte Partie).
    private func refreshResumableMatch() async {
        guard OnlineConfig.isLive, session == nil, let client = Backend.client else { return }
        if parkedGame?.canResumeOnline == true { resumableMatch = nil; return }
        parkedGame = nil
        resumableMatch = await OnlineMatches.activeHumanMatch(client: client)
    }

    private func resume() {
        if let vm = parkedGame, vm.canResumeOnline {
            parkedGame = nil
            session = GameSession(vm: vm)
            return
        }
        parkedGame = nil
        if let id = resumableMatch {
            resumableMatch = nil
            Task { await startHumanMatch(id, resumed: true) }
            return
        }
        guard let saved = store.loadGame() else {
            store.clearGame()
            return
        }
        session = GameSession(vm: GameViewModel(saved: saved))
    }
}

/// Passt der Inhalt, federt der ScrollView nicht (ab iOS 16.4).
struct BounceOnlyIfNeeded: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.scrollBounceBehavior(.basedOnSize)
        } else {
            content
        }
    }
}

/// Level-Zahl im Kreis mit XP-Ring. Die Zahl selbst ist das Zeichen, ohne Logo.
struct LevelBadge: View {
    let level: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle().fill(Theme.panelRaised)
            Circle().stroke(Theme.panelHighlight, lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.manaLight, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(level)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel(L("Level {0}", level))
    }
}

/// Laufende Partie – golden umrandet, mit pulsierendem Play-Symbol.
struct ContinueBanner: View {
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(Theme.navy)
                    .frame(width: compact ? 30 : 38, height: compact ? 30 : 38)
                    .background(Circle().fill(Theme.gold))
                    .modifier(PulseGlow(color: Theme.gold, active: true))
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Partie fortsetzen"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text(L("Dein Gegner wartet auf deinen Zug"))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.textMuted)
            }
            .padding(compact ? 8 : 12)
        }
        .buttonStyle(PanelButtonStyle())
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.gold.opacity(0.8), lineWidth: 1.5))
    }
}

/// Das Herzstück der Startseite: eine Bühne in der Landschaft deiner Arena. Oben der Weg zur nächsten Belohnung,
/// darunter du und dein Deck untereinander, dann der große Kampf-Knopf. Die Truhen sitzen klein in der Ecke.
/// Seit v0.9.24 ohne festen Gegner („vs Bot …“): Gegner werden nach Trophäen gesucht – bereit für Online-Kämpfe.
struct BattleHeroCard: View {
    @Environment(\.liveAnimations) private var live
    @ObservedObject var store = ProfileStore.shared
    @ObservedObject private var rules = OnlineRules.shared
    @ObservedObject private var network = NetworkMonitor.shared
    var compact = false
    /// Viel Platz: größerer Avatar und größere Karten, die Bühne wächst mit
    var large = false
    let onBattle: () -> Void
    let onChests: () -> Void
    let onDeck: () -> Void
    let onArena: () -> Void

    var body: some View {
        let arena = store.arena
        let colors = ArenaPalette.colors(arena.number)
        VStack(spacing: compact ? 12 : 16) {
            arenaRow
            stage(colors: colors)
                .frame(maxHeight: .infinity)
            battleButton
            matchRow
        }
        .padding(compact ? 12 : 16)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                LinearGradient(colors: [Theme.blueDark, Theme.panelRaised, Color(hex: 0x3A1C2A)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                BiomeBackdrop(arena: arena.number, colors: colors, reached: true, animated: true, scrim: 0.42)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(colors[0].opacity(0.55), lineWidth: 1.5))
    }

    // MARK: Bühne

    /// Du auf dem Podest, darunter das Deck – der leere Platz in der Bühne wird dafür genutzt.
    private func stage(colors: [Color]) -> some View {
        let avatarSize: CGFloat = compact ? 92 : (large ? 128 : 112)
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: compact ? 14 : 18) {
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Ellipse()
                            .fill(RadialGradient(colors: [colors[0].opacity(0.75), colors[0].opacity(0)], center: .center,
                                                 startRadius: 2, endRadius: avatarSize * 0.7))
                            .frame(width: avatarSize * 1.5, height: avatarSize * 0.36)
                            .offset(y: avatarSize * 0.1)
                        PlayerAvatar(size: avatarSize)
                            .modifier(RoadBob(active: true, amplitude: 3, speed: 2.2))
                            .padding(.bottom, avatarSize * 0.06)
                    }
                    Text(store.profile.name)
                        .font(.system(size: compact ? 18 : 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text((store.activeTitle ?? ProfileStore.rank(for: store.level)).uppercased())
                        .font(.system(size: compact ? 11 : 13, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Theme.blueLight)
                        .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .accessibilityElement(children: .combine)
                deckFan
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            chestButton
        }
    }

    /// Kleines Truhen-Symbol in der Bühne, nicht in der Kopfzeile.
    private var chestButton: some View {
        let waiting = store.pendingChests.count + (store.dailyChestReady ? 1 : 0)
        return Button {
            Haptics.shared.play(.select)
            onChests()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(waiting > 0 ? Theme.gold : Theme.textSecondary)
                    .frame(width: 40, height: 36)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .overlay(Capsule().strokeBorder(Theme.gold.opacity(waiting > 0 ? 0.7 : 0.25), lineWidth: 1))
                if waiting > 0 {
                    Text("\(min(waiting, 9))")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Theme.red))
                        .offset(x: 4, y: -4)
                }
            }
            .modifier(Jiggle(active: waiting > 0, amplitude: 3, period: 1.4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Truhen"))
    }

    // MARK: Deck

    /// Dein Deck als aufgefächerte Hand mit den gemalten Kartenbildern (Tipp → Deck-Tab).
    private var deckFan: some View {
        // Freie Deckplätze erscheinen als gestrichelte Platzhalter (leerer Name) – v0.9.31
        let cards = store.activeDeck
        let deck: [(String, Color)] = [("art-ult-\(store.activeUltimate.rawValue)", CardStyle.ultimate)]
            + cards.map { ("art-card-\($0.rawValue)", Color(hex: $0.tier.colorHex)) }
            + Array(repeating: ("", Theme.gold), count: max(0, PlayerDeck.size - cards.count))
        let mid = Double(deck.count - 1) / 2
        let avgMana = store.activeDeck.isEmpty ? 0 : Double(store.activeDeck.map(\.cost).reduce(0, +)) / Double(store.activeDeck.count)
        return Button(action: onDeck) {
            VStack(spacing: compact ? 4 : 6) {
                HStack(spacing: 5) {
                    Text(L("DEIN DECK"))
                        .font(.system(size: compact ? 11 : 13, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(Theme.gold)
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: compact ? 14 : 16, weight: .bold))
                        .foregroundColor(Theme.blueLight)
                }
                HStack(spacing: compact ? -16 : -14) {
                    ForEach(Array(deck.enumerated()), id: \.offset) { i, item in
                        let k = Double(i) - mid
                        let w: CGFloat = compact ? 48 : (large ? 68 : 60)
                        Group {
                            if item.0.isEmpty {
                                RoundedRectangle(cornerRadius: w * 0.2)
                                    .fill(Color.black.opacity(0.35))
                                    .overlay(RoundedRectangle(cornerRadius: w * 0.2)
                                        .strokeBorder(Theme.gold.opacity(0.75), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])))
                                    .overlay(Image(systemName: "plus").font(.system(size: w * 0.32, weight: .black)).foregroundColor(Theme.gold))
                                    .frame(width: w, height: w / 0.8)
                            } else {
                                CardArtThumb(art: item.0, width: w, border: item.1)
                            }
                        }
                            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
                            .rotationEffect(.degrees(k * 8), anchor: .bottom)
                            .offset(y: CGFloat(k * k) * 2.5)
                            .zIndex(-abs(k))
                    }
                }
                .padding(.bottom, 6)
                HStack(spacing: 4) {
                    SettingChip(icon: "sparkles", text: store.activeUltimate.name, gold: true)
                    if cards.count < PlayerDeck.size {
                        SettingChip(icon: "plus.circle.fill", text: cards.isEmpty ? L("Deck bauen") : L("{0}/{1} Karten", cards.count, PlayerDeck.size), gold: true)
                            .modifier(Jiggle(active: cards.isEmpty, amplitude: 4, period: 1.4))
                    } else {
                        SettingChip(icon: "drop.fill", text: String(format: "Ø %.1f", avgMana))
                    }
                }
            }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(L("Dein Deck: {0}, ", store.activeUltimate.name) + store.activeDeck.map(\.name).joined(separator: ", ") + L(". Tippen zum Ändern"))
    }

    // MARK: Gegnersuche

    /// Unter dem Kampf-Knopf: feste Zeit 5 | 0 und wie der Gegner gesucht wird.
    private var matchRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11, weight: .black))
                Text(L("Gegner mit ähnlich vielen Trophäen"))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(Theme.textSecondary)
            .layoutPriority(-1)
            Spacer(minLength: 4)
            if OnlineConfig.isLive, let notice = rules.lock.title {
                SettingChip(icon: "exclamationmark.triangle.fill", text: notice, gold: true)
            } else {
                SettingChip(icon: "timer", text: TimeControl.blitz5.name, gold: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Kampf-Knopf

    @ViewBuilder
    private var battleButton: some View {
        VStack(spacing: 8) {
            if store.deckIsFull {
                fightButton
            } else {
                buildDeckButton
            }
            if store.deckIsFull, !network.isOnline {
                Label(L("Keine Internetverbindung. Kampf ist gerade nicht möglich."), systemImage: "wifi.slash")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.gold)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Deck unvollständig: statt „KAMPF!“ ein blauer Knopf zum Deck – mit Platzanzeige (v0.9.31).
    private var buildDeckButton: some View {
        let n = store.activeDeck.count
        return Button(action: onDeck) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .modifier(Jiggle(active: true, amplitude: 6, period: 1.2))
                VStack(alignment: .leading, spacing: 0) {
                    Text(n == 0 ? L("DECK BAUEN") : L("DECK FERTIG BAUEN"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(L("Für Kämpfe brauchst du 4 Karten"))
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.85)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                HStack(spacing: 3) {
                    ForEach(0..<PlayerDeck.size, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < n ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 8, height: 12)
                    }
                }
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(Capsule().fill(Color.black.opacity(0.2)))
            }
        }
        .buttonStyle(ChunkyButtonStyle(color: Theme.blue, shadow: Theme.blueDark, height: compact ? 54 : (large ? 66 : 62), textColor: .white))
        .modifier(PulseGlow(color: Theme.blueLight, active: true, strength: 0.8))
        .accessibilityLabel(L("Deck fertig bauen: {0} von {1} Karten", n, PlayerDeck.size))
    }

    private var fightButton: some View {
        let offline = !network.isOnline
        return Button(action: onBattle) {
            HStack(spacing: 8) {
                Image(systemName: offline ? "wifi.slash" : "bolt.fill")
                    .modifier(Jiggle(active: !offline, amplitude: 8, period: 0.9))
                Text(L("KAMPF!"))
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .black))
            }
        }
        .buttonStyle(ChunkyButtonStyle(color: offline ? Theme.panelHighlight : Theme.gold,
                                       shadow: offline ? Theme.panel : CardStyle.ultimateDeep,
                                       height: compact ? 54 : (large ? 66 : 62),
                                       textColor: offline ? Theme.textMuted : Theme.navy))
        .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false).opacity(offline ? 0 : 1))
        .modifier(PulseGlow(color: Theme.gold, active: !offline, strength: 0.9))
        .disabled(offline)
        .accessibilityLabel(offline ? L("Keine Internetverbindung. Kampf ist gerade nicht möglich.") : L("KAMPF!"))
        .overlay(alignment: .topTrailing) {
            // Was der nächste Sieg bringt
            if store.winChestsLeftToday > 0 {
                HStack(spacing: 3) {
                    ChestView(rarity: .wood, size: 18)
                    Text("+1").font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(Capsule().fill(Theme.red))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                .modifier(RoadBob(active: true, amplitude: 2, speed: 4))
                .offset(x: 6, y: -10)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: Arena-Leiste

    /// Fortschritt zur nächsten Belohnung auf dem Trophäenpfad – oder „Abholen“, wenn schon etwas wartet.
    private var arenaRow: some View {
        let arena = store.arena
        let colors = ArenaPalette.colors(arena.number)
        let ready = store.claimableRoadSteps.count
        let next = store.nextRoadStep
        let prev = next.flatMap { n in ProfileStore.road.last { $0.trophies < n.trophies }?.trophies } ?? 0
        let progress: Double = {
            guard let next else { return 1 }
            return min(1, max(0, Double(store.roadTrophies - prev) / Double(max(1, next.trophies - prev))))
        }()
        return Button(action: onArena) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                    Image(systemName: arena.icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundColor(.white)
                }
                .frame(width: 36, height: 36)
                .shadow(color: colors[0].opacity(0.7), radius: 6)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(L("ARENA {0} · {1}", arena.number, arena.name.uppercased()))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundColor(Theme.gold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        if ready > 0 {
                            Text(ready == 1 ? L("BELOHNUNG ABHOLEN") : L("{0} BELOHNUNGEN", ready))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(Theme.navy)
                                .padding(.horizontal, 8)
                                .frame(height: 20)
                                .background(Capsule().fill(Theme.gold))
                                .modifier(PulseGlow(color: Theme.gold, active: true))
                        } else if let next {
                            Text(L("{0} bei {1}", next.reward.title, next.trophies))
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.35))
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.gold, Color(hex: 0xFFA000)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, geo.size.width * (ready > 0 ? 1 : progress)))
                                .overlay(ShineSweep().clipShape(Capsule()))
                        }
                    }
                    .frame(height: 7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ready > 0 ? L("Trophäenpfad: {0} Belohnungen abholen", ready) : L("Trophäenpfad öffnen"))
    }
}

/// Kleine Anzeige einer gewählten Einstellung unter dem Kampf-Knopf.
struct SettingChip: View {
    let icon: String
    let text: String
    var gold = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(gold ? CardStyle.ultimate : Theme.textSecondary)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(gold ? CardStyle.ultimate.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
    }
}

/// Lichtstreifen, der regelmäßig über den Kampf-Knopf wischt (über die Uhrzeit, keine Endlos-Animation).
struct ShineSweep: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { tl in
            let cycle = 2.2
            let t = clock.time(tl.date).truncatingRemainder(dividingBy: cycle)
            let p = min(1, t / 1.3)
            let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            GeometryReader { geo in
                LinearGradient(colors: [.clear, Color.white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.25)
                    .rotationEffect(.degrees(20))
                    .offset(x: CGFloat(-1.2 + 2.4 * eased) * geo.size.width)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Willkommen


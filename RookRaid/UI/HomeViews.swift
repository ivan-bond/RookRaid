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
    /// Flammen-Fenster bzw. Splitter-Laden öffnen (Pillen oben rechts, Profil). RootView zeigt sie.
    static let showFlame = Notification.Name("RookRaidShowFlame")
    static let showShardShop = Notification.Name("RookRaidShowShardShop")
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

/// Main tabs (redesign V2): Puzzles · Play · Deck · Profile. The trophy road (formerly the Path tab) opens as a sheet.
enum RootTab: Hashable {
    case play, puzzles, deck, profile
}

/// Sheets der Pillen oben rechts – eine einzige Stelle zeigt sie (RootView).
enum RootSheet: String, Identifiable {
    case flame, shop, road
    var id: String { rawValue }
}

struct RootView: View {
    @ObservedObject private var store = ProfileStore.shared
    @State private var tab: RootTab = RootView.startTab
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
    /// Trophy road as a sheet (the Path tab is gone; the Magic Chest bar on Play opens it).
    @State private var rootSheet: RootSheet?
    @Environment(\.scenePhase) private var scenePhase

    /// Debug builds only: start on a given tab for screenshots (`xcrun simctl launch <device> com.ivan.rookraid -RRStartTab deck`).
    private static var startTab: RootTab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "RRStartTab") {
        case "puzzles": return .puzzles
        case "deck": return .deck
        case "profile": return .profile
        default: return .play
        }
        #else
        return .play
        #endif
    }

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
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Seiten-Container: Zwischen den Tabs lässt sich mit dem Finger wischen.
                // Reihenfolge wie die Tab-Leiste: Puzzle · Spielen (Start) · Deck · Profil
                // Eigener Pager statt TabView(.page): Der UIKit-Seitenwechsler zeigte nach Sprüngen über mehrere Tabs
                // oder nach dem Schließen einer Partie manchmal eine leere Seite, und Seiten außerhalb seines
                // Fensters konnten keine Fenster öffnen (Pillen ohne Wirkung).
                TabPager(tab: $tab, pages: [.puzzles, .play, .deck, .profile]) { t in
                    switch t {
                    case .puzzles: page(.puzzles, PuzzleHubView(session: $puzzleSession))
                    case .play: page(.play, HomeView(session: $session, puzzleSession: $puzzleSession, tab: $tab))
                    case .deck: page(.deck, DeckView())
                    case .profile: page(.profile, ProfileView())
                    }
                }
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
        .modifier(RootSheets(sheet: $rootSheet, tab: $tab))
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
            #if DEBUG
            // Screenshots: straight into the first battle (`-RRTutorialStep n` plays the first n tasks by itself).
            if UserDefaults.standard.object(forKey: "RRTutorialStep") != nil {
                let vm = GameViewModel(mode: .tutorial, humanColor: .white, timeControl: .none)
                session = GameSession(vm: vm)
                let steps = UserDefaults.standard.integer(forKey: "RRTutorialStep")
                let select = UserDefaults.standard.bool(forKey: "RRTutorialSelect")
                Task { @MainActor in await vm.debugAutoplayTutorial(steps: steps, select: select) }
                return
            }
            #endif
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

/// Flamme, Splitter-Laden und Trophäenpfad zentral als Sheet (die Knöpfe oben posten nur eine Notification) und
/// die Tab-Sprünge per Notification – eigener Modifier, damit RootView.body für den Compiler überschaubar bleibt.
private struct RootSheets: ViewModifier {
    @Binding var sheet: RootSheet?
    @Binding var tab: RootTab

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .showPuzzles)) { _ in tab = .puzzles }
            .onReceive(NotificationCenter.default.publisher(for: .showDeck)) { _ in tab = .deck }
            .onReceive(NotificationCenter.default.publisher(for: .showLadder)) { _ in tab = .play }
            .onReceive(NotificationCenter.default.publisher(for: .startQuickBattle)) { _ in tab = .play }
            .onReceive(NotificationCenter.default.publisher(for: .showTrophyRoad)) { _ in sheet = .road }
            .onReceive(NotificationCenter.default.publisher(for: .showFlame)) { _ in sheet = .flame }
            .onReceive(NotificationCenter.default.publisher(for: .showShardShop)) { _ in sheet = .shop }
            .sheet(item: $sheet) { which in
                switch which {
                case .flame: FlameSheet()
                case .shop: ShardShopSheet()
                case .road: TrophyRoadSheet()
                }
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
        case .play: return (store.pendingChests.count + (store.dailyChestReady ? 1 : 0) + store.claimableRoadSteps.count, false)
        case .puzzles: return (0, store.dailyBonusAvailable)
        case .deck: return (store.newCardCount, store.profile.tutorialSeen && !store.deckIsFull)
        case .profile: return (store.claimableAchievements.count + friends.incoming.count, false)
        }
    }

    private let items: [(RootTab, String, String)] = [
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
            DS.tabBar
                .overlay(Rectangle().fill(DS.divider).frame(height: 1), alignment: .top)
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
                        .fill(DS.tabPill)
                        .frame(width: 58, height: 32)
                        .shadow(color: DS.tabPill.opacity(0.6), radius: 8)
                        .opacity(active ? 1 : 0)
                        .scaleEffect(active ? 1 : 0.6)
                    Image(systemName: item.2)
                        .font(.system(size: active ? 19 : 18, weight: .bold))
                        .foregroundColor(active ? .white : DS.tabInactive)
                        .scaleEffect(active ? 1.08 : 1)
                }
                .frame(height: 32)
                .overlay(alignment: .topTrailing) { badgeView(badge(item.0)) }
                Text(item.1)
                    .font(.system(size: 13, weight: active ? .heavy : .semibold))
                    .foregroundColor(active ? .white : DS.tabInactive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Capsule()
                    .fill(DS.tabUnderline)
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
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    DS.bg.ignoresSafeArea()
                    PlayArenaArt(arena: store.arena.number)
                    ScrollView(showsIndicators: false) {
                        playContent(height: geo.size.height)
                    }
                    .modifier(BounceOnlyIfNeeded())
                }
            }
            .primaryAction { fightButton }
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

    // MARK: Play screen (redesign V2)

    /// Header, arena with the trophy-road bar, deck strip, list rows and the slim bot-ladder row.
    /// The gap above the arena block grows on tall phones so the art shows; on an iPhone SE it shrinks and the page scrolls.
    private func playContent(height: CGFloat) -> some View {
        let gap = min(130, max(20, height - 560))
        return VStack(alignment: .leading, spacing: 0) {
            playHeader
            Color.clear.frame(height: gap)
            arenaBlock
                .padding(.bottom, 18)
            deckStrip
                .padding(.bottom, 16)
            ListGroup {
                if canContinue {
                    Button { resume() } label: {
                        ListRow(title: L("Partie fortsetzen"), subtitle: L("Dein Gegner wartet auf deinen Zug")) {
                            IconTile(symbol: "play.fill", tint: DS.gold)
                        }
                    }
                    .buttonStyle(RowButtonStyle())
                }
                if OnlineAccount.shared.status != .unavailable {
                    Button {
                        NotificationCenter.default.post(name: .showFriends, object: nil)
                    } label: {
                        ListRow(title: L("Gegen Freunde spielen"), subtitle: friendsSubtitle) {
                            IconTile(symbol: "person.2.fill", tint: DS.gem)
                        }
                    }
                    .buttonStyle(RowButtonStyle())
                }
                Button { showDaily = true } label: {
                    ListRow(title: L("Truhen & Tagesziele"), subtitle: chestsSubtitle,
                            trailing: chestsWaiting > 0 ? .value("\(chestsWaiting)") : .chevron, showsDivider: false) {
                        IconTile(symbol: "shippingbox.fill", tint: DS.gold)
                    }
                }
                .buttonStyle(RowButtonStyle())
            }
            .padding(.bottom, 10)
            ladderRow
        }
        .padding(.bottom, 12)
        .frame(minHeight: height, alignment: .top)
    }

    private var playHeader: some View {
        HStack(spacing: 10) {
            Button { tab = .profile } label: {
                AvatarPortrait(avatar: store.activeAvatar, pieceColor: .white)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Profil"))
            VStack(alignment: .leading, spacing: 1) {
                Text(store.profile.name)
                    .font(DS.heading(20))
                    .foregroundColor(DS.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(L("{0} · Level {1}", store.activeTitle ?? ProfileStore.rank(for: store.level), store.level))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
            .layoutPriority(-1)
            Spacer(minLength: 4)
            ResourcePills(onArt: true)
        }
        .padding(.horizontal, DS.side)
        .padding(.top, 8)
    }

    /// Arena name and the bar to the next trophy-road reward. Tap → trophy road sheet (all rewards stay reachable).
    private var arenaBlock: some View {
        let arena = store.arena
        let ready = store.claimableRoadSteps.count
        let next = store.nextRoadStep
        let prev = next.flatMap { n in ProfileStore.road.last { $0.trophies < n.trophies }?.trophies } ?? 0
        let progress: Double = {
            guard let next else { return 1 }
            return Double(store.roadTrophies - prev) / Double(max(1, next.trophies - prev))
        }()
        let label: String = {
            if ready > 0 { return ready == 1 ? L("Belohnung abholen") : L("{0} Belohnungen abholen", ready) }
            return next?.reward.title ?? L("Pfad geschafft")
        }()
        let rarity: ChestRarity = {
            switch next?.reward {
            case .chest(let r)?, .arena(_, let r)?: return r
            default: return .magic
            }
        }()
        return Button {
            Haptics.shared.play(.select)
            NotificationCenter.default.post(name: .showTrophyRoad, object: nil)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("ARENA {0}", arena.number))
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.4)
                        .foregroundColor(DS.text.opacity(0.85))
                    Text(arena.name)
                        .font(DS.heading(26, .black))
                        .foregroundColor(DS.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .shadow(color: .black.opacity(0.7), radius: 4, y: 1)
                HStack(spacing: 12) {
                    ChestView(rarity: rarity, size: 30, glow: ready > 0 ? 0.6 : 0)
                        .frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(label)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(ready > 0 ? DS.gold : DS.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer(minLength: 6)
                            if let next, ready == 0 {
                                Text("\(store.roadTrophies) / \(next.trophies)")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
                                    .foregroundColor(DS.text)
                                    .fixedSize()
                            }
                        }
                        DSProgressBar(fraction: ready > 0 ? 1 : progress, tint: DS.gold)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 11 / 255, green: 18 / 255, blue: 32 / 255).opacity(0.7)))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.side)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Arena {0}, {1}. {2}. Trophäenpfad öffnen", arena.number, arena.name, label))
        .accessibilityAddTraits(.isButton)
    }

    /// Battle deck: four cards and the ultimate (gold edge). "Edit" and every card open the Deck tab.
    private var deckStrip: some View {
        let cards = store.activeDeck
        let avg = cards.isEmpty ? 0 : Double(cards.map(\.cost).reduce(0, +)) / Double(cards.count)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel(L("Dein Deck · Ø {0} Mana", String(format: "%.1f", avg)), actionTitle: L("Bearbeiten")) { tab = .deck }
            Button { tab = .deck } label: {
                HStack(spacing: 8) {
                    ForEach(0..<PlayerDeck.size, id: \.self) { i in
                        if i < cards.count {
                            DeckThumb(art: "art-card-\(cards[i].rawValue)")
                        } else {
                            DeckThumb(art: nil)
                        }
                    }
                    DeckThumb(art: "art-ult-\(store.activeUltimate.rawValue)", gold: true)
                }
            }
            .buttonStyle(PressScaleStyle())
            .padding(.horizontal, DS.side)
            .accessibilityLabel(L("Dein Deck: {0}, ", store.activeUltimate.name) + cards.map(\.name).joined(separator: ", ") + L(". Tippen zum Ändern"))
        }
    }

    /// Slim bot-ladder row (36 pt).
    private var ladderRow: some View {
        let next = store.ladderNext
        let beaten = store.profile.ladderBeaten
        let total = BotLevel.allCases.count
        return Button { showLadder = true } label: {
            HStack(spacing: 10) {
                if let next {
                    BotAvatar(level: next, size: 24)
                } else {
                    Image(systemName: "crown.fill").foregroundColor(DS.gold).frame(width: 24, height: 24)
                }
                (Text(L("Bot-Leiter")).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(DS.text)
                 + Text(next.map { L(" · nächster: {0} · {1}/{2}", $0.displayName, beaten, total) } ?? L(" · alle besiegt"))
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(DS.textMuted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DS.chevron)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 12).fill(DS.group))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DS.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.side)
    }

    /// The one gold button: Fight (5 | 0, ranked). Without a full deck it leads to the Deck tab; offline it is disabled.
    @ViewBuilder
    private var fightButton: some View {
        VStack(spacing: 6) {
            if store.deckIsFull, !NetworkMonitor.shared.isOnline {
                Label(L("Keine Internetverbindung. Kampf ist gerade nicht möglich."), systemImage: "wifi.slash")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DS.gold)
                    .multilineTextAlignment(.center)
            } else if store.deckIsFull, OnlineConfig.isLive, let notice = OnlineRules.shared.lock.title {
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(DS.gold)
            }
            if store.deckIsFull {
                PrimaryButton(title: L("Kampf"), subtitle: L("5 Min · gewertet"), icon: "bolt.fill",
                              enabled: NetworkMonitor.shared.isOnline) { quickBattle() }
            } else {
                PrimaryButton(title: store.activeDeck.isEmpty ? L("Deck bauen") : L("Deck fertig bauen"),
                              subtitle: L("{0}/{1} Karten", store.activeDeck.count, PlayerDeck.size),
                              icon: "rectangle.stack.badge.plus") { tab = .deck }
            }
        }
    }

    private var chestsWaiting: Int { store.pendingChests.count + (store.dailyChestReady ? 1 : 0) }

    private var chestsSubtitle: String {
        if chestsWaiting > 0 { return chestsWaiting == 1 ? L("1 Truhe wartet") : L("{0} Truhen warten", chestsWaiting) }
        let goals = store.dailyGoals
        return L("Tagesziele {0}/{1}", goals.filter(\.done).count, goals.count)
    }

    private var friendsSubtitle: String {
        let n = FriendsStore.shared.friends.count
        return n == 0 ? L("Freunde einladen und herausfordern") : (n == 1 ? L("Herausfordern oder Revanche · 1 Freund") : L("Herausfordern oder Revanche · {0} Freunde", n))
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
                                                timeControl: found.timeControl,
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
                               rated: info.rated, timeControl: info.timeControl)
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

/// Painted art of the current arena behind the top of the Play screen, fading into the background
/// (transparent fade from ~35 %, solid at the bottom).
struct PlayArenaArt: View {
    let arena: Int

    var body: some View {
        Image(ArenaArt.imageName(arena))
            .resizable()
            .scaledToFill()
            .frame(height: 530)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(stops: [.init(color: DS.bg.opacity(0.15), location: 0),
                                       .init(color: DS.bg.opacity(0), location: 0.12),
                                       .init(color: DS.bg.opacity(0.35), location: 0.35),
                                       .init(color: DS.bg.opacity(0.85), location: 0.75),
                                       .init(color: DS.bg, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// One card of the deck strip (art only, 4:5). `nil` = free slot; `gold` = the ultimate.
struct DeckThumb: View {
    let art: String?
    var gold = false

    var body: some View {
        ZStack {
            if let art {
                CardArtImage(name: art, thumb: true)
                    .aspectRatio(0.8, contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.3))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(DS.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.8, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(gold ? DS.gold : (art == nil ? DS.textMuted.opacity(0.6) : Color.white.opacity(0.12)),
                              style: StrokeStyle(lineWidth: gold ? 2 : 1, dash: art == nil ? [4, 3] : []))
        )
        .accessibilityHidden(true)
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


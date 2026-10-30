import SwiftUI

@main
struct RookRaidApp: App {
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
    /// Zum Spielen-Tab wechseln und die erste wartende Truhe öffnen (Rockys Einladung)
    static let openPendingChest = Notification.Name("RookRaidOpenPendingChest")
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
            let next = GameViewModel(mode: mode, humanColor: settings.playAsWhite ? .white : .black,
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
    @State private var showSplash = true
    @State private var lastTab: RootTab = .play
    /// Der zuletzt ruhende Tab. Er folgt `tab` erst nach dem Seitenwechsel – so animiert der alte Tab weiter,
    /// während er hinausgleitet, und wird erst danach angehalten (v0.9.28: der neue startet sofort, siehe `isLive`).
    @State private var liveTab: RootTab = .play
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
    @Environment(\.scenePhase) private var scenePhase

    /// Nur der sichtbare Tab animiert – und keiner, solange eine Partie oder ein Puzzle im Vollbild läuft.
    /// Der neue Tab animiert sofort (v0.9.28), der alte läuft weiter, bis er aus dem Bild geglitten ist.
    private func isLive(_ t: RootTab) -> Bool {
        (tab == t || liveTab == t) && session == nil && puzzleSession == nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Seiten-Container: Zwischen den Tabs lässt sich mit dem Finger wischen.
                // Reihenfolge wie die Tab-Leiste: Pfad · Puzzle · Spielen (Mitte, Start) · Deck · Profil
                TabView(selection: $tab) {
                    TrophyRoadView()
                        .environment(\.liveAnimations, isLive(.arena))
                        .tag(RootTab.arena)
                    PuzzleHubView(session: $puzzleSession)
                        .environment(\.liveAnimations, isLive(.puzzles))
                        .tag(RootTab.puzzles)
                    HomeView(session: $session, puzzleSession: $puzzleSession, tab: $tab)
                        .environment(\.liveAnimations, isLive(.play))
                        .tag(RootTab.play)
                    DeckView()
                        .environment(\.liveAnimations, isLive(.deck))
                        .tag(RootTab.deck)
                    ProfileView()
                        .environment(\.liveAnimations, isLive(.profile))
                        .tag(RootTab.profile)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Theme.background.ignoresSafeArea())

                RootTabBar(tab: $tab)
                    .environment(\.liveAnimations, session == nil && puzzleSession == nil)
            }
            // Sprachwechsel: Oberfläche neu aufbauen (Tab und Startbildschirm-Zustand bleiben)
            .id(store.profile.settings.language)
            .environment(\.locale, store.profile.settings.language.locale)
            .background(Theme.background.ignoresSafeArea())
            .onAppear {
                Feedback.apply(settings: store.profile.settings)
                store.checkStreak()
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active { store.checkStreak() }
                if phase != .active { store.flushSave() }
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
                // Profil speichern und Animationen umschalten erst nach der Seitenbewegung – sonst baut sich
                // während des Wischens jeder Tab neu auf und die Bewegung ruckelt.
                settleTask?.cancel()
                settleTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    guard !Task.isCancelled else { return }
                    if seenPending && tab != .deck {
                        seenPending = false
                        store.markAllSeen()
                    }
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) { liveTab = tab }
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

            if showRockyInvite && !showSplash {
                RockyInviteOverlay(chestsWaiting: !store.pendingChests.isEmpty, onPrimary: {
                    if store.pendingChests.isEmpty {
                        withAnimation(.easeOut(duration: 0.25)) { showRockyInvite = false }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .deck }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { showRockyInvite = false }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .play }
                        NotificationCenter.default.post(name: .openPendingChest, object: nil)
                    }
                }, onSecondary: {
                    withAnimation(.easeOut(duration: 0.25)) { showRockyInvite = false }
                    if store.pendingChests.isEmpty {
                        inviteSnoozed = true
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .deck }
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

            if !showSplash, let days = store.profile.freezeNotice {
                FreezeNoticeOverlay(days: days, streak: store.currentStreak) {
                    withAnimation(.easeOut(duration: 0.25)) { store.profile.freezeNotice = nil }
                }
                .transition(.opacity)
                .zIndex(9)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in showSettings = true }
        .onReceive(NotificationCenter.default.publisher(for: .showPuzzles)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .puzzles }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTrophyRoad)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .arena }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDeck)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .deck }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showLadder)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .play }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startQuickBattle)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = .play }
        }
        // Rockys Einladung: nach jeder geschlossenen Partie bzw. sobald alle Truhen offen sind
        .onChange(of: session?.id) { id in
            if id == nil {
                scheduleRockyInvite(after: 0.9)
                scheduleAppleSecure(after: 1.1)
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
            session = GameSession(vm: GameViewModel(mode: .tutorial, humanColor: .white, timeControl: .none))
        }
        .task {
            // Startbildschirm kurz zeigen, dann – beim ersten Start – direkt in die erste Schlacht
            try? await Task.sleep(nanoseconds: UInt64((SplashView.duration + 0.35) * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            // Kartenbilder im Hintergrund vorbereiten, ohne den Start aufzuhalten (v0.9.25)
            Task { await CardArtImage.preload() }
            if !store.profile.tutorialSeen {
                try? await Task.sleep(nanoseconds: 250_000_000)
                session = GameSession(vm: GameViewModel(mode: .tutorial, humanColor: .white, timeControl: .none))
            } else {
                scheduleRockyInvite(after: 0.5)
            }
        }
    }

    /// Rocky lädt in die Deck-Werkstatt ein – nur auf der Startseite, ohne laufende Partie und nur, solange die Tour aussteht.
    private func scheduleRockyInvite(after delay: Double) {
        guard store.needsDeckTour, !inviteSnoozed, !showRockyInvite else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard store.needsDeckTour, !inviteSnoozed, !showRockyInvite, !showSplash,
                  session == nil, puzzleSession == nil, tab == .play else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showRockyInvite = true }
        }
    }

    /// Einmalig, nachdem Rocky mit der Deck-Einladung fertig ist und keine Partie offen ist.
    private func scheduleAppleSecure(after delay: Double) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !showAppleSecure, !showRockyInvite, !showSplash, session == nil else { return }
            guard account.consumeApplePrompt() else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showAppleSecure = true }
        }
    }
}

/// Eigene Tab-Leiste: folgt dem Wischen zwischen den Seiten, die aktive Seite trägt eine blaue Kapsel.
struct RootTabBar: View {
    @Binding var tab: RootTab
    @ObservedObject var store = ProfileStore.shared

    /// Zahl oder Punkt am Tab: wartende Truhen, Tagespuzzle, neue Karten, abholbare Pfad-Belohnungen.
    private func badge(_ t: RootTab) -> (count: Int, dot: Bool) {
        switch t {
        case .play: return (store.pendingChests.count + (store.dailyChestReady ? 1 : 0), false)
        case .puzzles: return (0, store.dailyBonusAvailable)
        case .deck: return (store.newCardCount, store.profile.tutorialSeen && !store.deckIsFull)
        case .arena: return (store.claimableRoadSteps.count, false)
        case .profile: return (store.claimableAchievements.count, false)
        }
    }

    private let left: [(RootTab, String, String)] = [
        (.arena, L("Pfad"), "trophy.fill"),
        (.puzzles, L("Puzzles"), "puzzlepiece.fill")
    ]
    private let right: [(RootTab, String, String)] = [
        (.deck, L("Deck"), "rectangle.stack.fill"),
        (.profile, L("Profil"), "person.crop.circle.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(left.indices, id: \.self) { i in sideItem(left[i]) }
            // Platzhalter für den Spielen-Knopf – feste Höhe, sonst dehnt er sich über den halben Bildschirm aus
            Color.clear.frame(width: 76, height: 1)
            ForEach(right.indices, id: \.self) { i in sideItem(right[i]) }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Theme.backgroundDeep
                .overlay(Rectangle().fill(Theme.panelHighlight).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
        // Der Spielen-Knopf ragt über die Leiste hinaus, ohne den Seiteninhalt zu verkleinern
        .overlay(alignment: .bottom) {
            playButton
                .padding(.bottom, 4)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: store.pendingChests.count)
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: store.claimableRoadSteps.count)
    }

    private func sideItem(_ item: (RootTab, String, String)) -> some View {
        let active = tab == item.0
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = item.0 }
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

    /// „Spielen“ in der Mitte (v0.9.26 kleiner): Aktiv ist der Knopf eine goldene Scheibe mit Strahlenkranz und
    /// goldenem Balken unter der Schrift; inaktiv ein dunkler Knopf mit goldenem Ring, gedämpftem Rocky und grauer Schrift.
    private var playButton: some View {
        let active = tab == .play
        let disc: CGFloat = 48
        return Button {
            Haptics.shared.play(active ? .select : .cardWhoosh)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { tab = .play }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    // Strahlenkranz nur, wenn „Spielen“ aktiv ist
                    LightRays(color: Theme.gold, count: 10, speed: 0.35, paused: !active)
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .opacity(active ? 0.6 : 0)
                    Circle()
                        .fill(active
                              ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold, Color(hex: 0xD9861C)], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(LinearGradient(colors: [Theme.panelRaised, Theme.backgroundDeep], startPoint: .top, endPoint: .bottom)))
                        .frame(width: disc, height: disc)
                        .shadow(color: active ? Color(hex: 0x8A5410) : .black.opacity(0.5), radius: 0, y: 3)
                    Image("Logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: disc - 10, height: disc - 10)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.navy, lineWidth: 2))
                        .saturation(active ? 1 : 0.55)
                        .opacity(active ? 1 : 0.85)
                    Circle()
                        .strokeBorder(active ? Color.white.opacity(0.9) : Theme.gold.opacity(0.7), lineWidth: 2)
                        .frame(width: disc, height: disc)
                }
                .frame(width: 72, height: 50)
                .scaleEffect(active ? 1.06 : 1)
                .overlay(alignment: .topTrailing) {
                    badgeView(badge(.play))
                        .offset(x: -6, y: 2)
                }
                Text(L("Spielen"))
                    .font(.system(size: 10, weight: active ? .black : .semibold, design: .rounded))
                    .foregroundColor(active ? Theme.gold : Theme.textMuted)
                Capsule()
                    .fill(Theme.gold)
                    .frame(width: active ? 20 : 0, height: 3)
                    .opacity(active ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(badge(.play).count > 0 ? L("{0}, {1} neu", L("Spielen"), badge(.play).count) : L("Spielen"))
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
    @State var showSetup = false
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
            .onReceive(NotificationCenter.default.publisher(for: .openPendingChest)) { _ in
                afterSheet { chestToOpen = store.pendingChests.first }
            }
            .fullScreenCover(item: $chestToOpen) { c in ChestOpeningView(start: c) }
            .sheet(isPresented: $showLadder) {
                LadderView { level in
                    showLadder = false
                    guard store.deckIsFull else {
                        afterSheet { showEmptyDeck = true }
                        return
                    }
                    let s = store.profile.settings
                    store.clearGame()
                    // Bot-Leiter ohne Uhr (v0.9.34)
                    session = GameSession(vm: GameViewModel(mode: .ladder(level), humanColor: s.playAsWhite ? .white : .black,
                                                            timeControl: .none))
                }
            }
            .sheet(isPresented: $showSetup) {
                PlaySetupSheet(onSave: { time, white in
                    var settings = store.profile.settings
                    settings.timeControl = time
                    settings.playAsWhite = white
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.profile.settings = settings }
                    Haptics.shared.play(.select)
                    showSetup = false
                }, onHotSeat: {
                    showSetup = false
                    afterSheet { start(mode: .hotSeat, humanColor: .white) }
                })
            }
            // Ohne volles Deck kein Spiel (v0.9.31) – falls ein Weg am Kampf-Knopf vorbeiführt (Tagesziel, Zu zweit)
            .alert(L("Dein Deck braucht 4 Karten"), isPresented: $showEmptyDeck) {
                Button(L("Zum Deck")) { withAnimation { tab = .deck } }
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
                if id == nil { OnlineRules.shared.applyPending(deferAdopt: store.hasSavedGame) }
            }
            .onChange(of: matchmaking.phase) { phase in
                handleMatchmaking(phase)
            }
        }
    }

    private func page(compact: Bool, large: Bool = false) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            header
            if store.hasSavedGame {
                ContinueBanner(compact: compact) { resume() }
            }
            BattleHeroCard(compact: compact, large: large,
                           onBattle: quickBattle,
                           onSettings: { showSetup = true },
                           onDeck: { withAnimation { tab = .deck } },
                           onArena: { withAnimation { tab = .arena } })
            ChestSlotsBar(compact: compact, onOpen: { chestToOpen = $0 }, onDaily: { showDaily = true })
            HStack(alignment: .top, spacing: 10) {
                LadderTile(compact: compact) { showLadder = true }
                RockyTipCard(compact: compact)
            }
            .fixedSize(horizontal: false, vertical: true)
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
            Spacer(minLength: 2)
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
            .onTapGesture { withAnimation { tab = .arena } }
        }
    }

    /// Ein Tipp auf „Kampf!“ startet sofort: Gegner passend zu den Trophäen (alle 200 eine Stufe).
    /// Online (Schritt 8): erst Konto, dann Suche; nach 10 s Bot-Ersatz.
    /// Weichen die Regeln vom Server ab, bleibt die Suche zu (Schritt 10).
    private func quickBattle() {
        if OnlineConfig.isLive {
            guard store.deckIsFull else {
                Haptics.shared.play(.invalid)
                showEmptyDeck = true
                return
            }
            Task { await beginOnline() }
            return
        }
        let s = store.profile.settings
        start(mode: .bot(BotLevel.forTrophies(store.profile.trophies)), humanColor: s.playAsWhite ? .white : .black)
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
            showMatchmaking = false
            matchmaking.phase = .idle
            startFoundMatch(found)
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
        store.clearGame()
        let play = OnlineBotPlay(matchId: id, opponent: found.opponent)
        session = GameSession(vm: GameViewModel(mode: .bot(level),
                                                humanColor: found.youAreWhite ? .white : .black,
                                                timeControl: OnlineConfig.timeControl,
                                                onlineBotPlay: play))
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
        guard store.deckIsFull else {
            Haptics.shared.play(.invalid)
            showEmptyDeck = true
            return
        }
        store.clearGame()
        let tc = mode.isBot ? store.profile.settings.timeControl : .none
        session = GameSession(vm: GameViewModel(mode: mode, humanColor: humanColor, timeControl: tc))
    }

    private func resume() {
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

/// Level im Kreis mit XP-Ring.
struct LevelBadge: View {
    let level: Int
    let progress: Double

    var body: some View {
        ZStack {
            Circle().fill(Theme.panelRaised)
            Circle().stroke(Theme.panelHighlight, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.manaLight, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .clipShape(Circle())
                .padding(6)
            Text("\(level)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(Theme.manaText)
                .frame(minWidth: 18, minHeight: 18)
                .background(Circle().fill(Theme.manaLight))
                .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                .offset(x: 17, y: 17)
        }
        .frame(width: 48, height: 48)
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
/// in der Mitte du auf deinem Podest mit deinem Deck als aufgefächerter Hand, darunter der große Kampf-Knopf.
/// Seit v0.9.24 ohne festen Gegner („vs Bot …“): Gegner werden nach Trophäen gesucht – bereit für Online-Kämpfe.
struct BattleHeroCard: View {
    @Environment(\.liveAnimations) private var live
    @ObservedObject var store = ProfileStore.shared
    @ObservedObject private var rules = OnlineRules.shared
    var compact = false
    /// Viel Platz: größerer Avatar und größere Karten, die Bühne wächst mit
    var large = false
    let onBattle: () -> Void
    let onSettings: () -> Void
    let onDeck: () -> Void
    let onArena: () -> Void

    var body: some View {
        let arena = store.arena
        let colors = ArenaPalette.colors(arena.number)
        VStack(spacing: compact ? 10 : 14) {
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
                BiomeBackdrop(arena: arena.number, colors: colors, reached: true, animated: true)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(colors[0].opacity(0.55), lineWidth: 1.5))
    }

    // MARK: Bühne

    /// Links du auf einem leuchtenden Podest, rechts dein Deck – beides tippbar.
    private func stage(colors: [Color]) -> some View {
        let s = store.profile.settings
        let avatarSize: CGFloat = compact ? 66 : (large ? 108 : 86)
        return HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 3) {
                ZStack(alignment: .bottom) {
                    // Podest in Arenafarbe
                    Ellipse()
                        .fill(RadialGradient(colors: [colors[0].opacity(0.75), colors[0].opacity(0)], center: .center,
                                             startRadius: 2, endRadius: avatarSize * 0.6))
                        .frame(width: avatarSize * 1.35, height: avatarSize * 0.32)
                        .offset(y: avatarSize * 0.1)
                    PlayerAvatar(size: avatarSize, pieceColor: s.playAsWhite ? .white : .black)
                        .modifier(RoadBob(active: true, amplitude: 2.5, speed: 2.2))
                        .padding(.bottom, avatarSize * 0.06)
                }
                Text(store.profile.name)
                    .font(.system(size: compact ? 14 : 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text((store.activeTitle ?? ProfileStore.rank(for: store.level)).uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundColor(Theme.blueLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            deckFan
                .frame(maxWidth: .infinity)
        }
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
                HStack(spacing: 4) {
                    Text(L("DEIN DECK"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Theme.gold)
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.blueLight)
                }
                HStack(spacing: compact ? -12 : -10) {
                    ForEach(Array(deck.enumerated()), id: \.offset) { i, item in
                        let k = Double(i) - mid
                        let w: CGFloat = compact ? 34 : (large ? 50 : 40)
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

    /// Unter dem Kampf-Knopf: wie gesucht wird (Trophäen) und mit welcher Uhr und Farbe – Tipp öffnet die Einstellungen.
    private var matchRow: some View {
        let s = store.profile.settings
        return Button(action: onSettings) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10, weight: .black))
                    Text(L("Gegner mit ähnlich vielen Trophäen"))
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(Theme.textSecondary)
                .layoutPriority(-1)
                Spacer(minLength: 4)
                if OnlineConfig.isLive, let notice = rules.lock.title {
                    SettingChip(icon: "exclamationmark.triangle.fill", text: notice, gold: true)
                } else {
                    SettingChip(icon: "timer", text: OnlineConfig.isLive ? OnlineConfig.timeControl.name : s.timeControl.name)
                }
                SettingChip(icon: "circle.lefthalf.filled", text: s.playAsWhite ? L("Weiß") : L("Schwarz"))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Einstellungen: {0}, {1}. Tippen zum Ändern", s.timeControl.name, s.playAsWhite ? L("Weiß") : L("Schwarz")))
    }

    // MARK: Kampf-Knopf

    @ViewBuilder
    private var battleButton: some View {
        if store.deckIsFull {
            fightButton
        } else {
            buildDeckButton
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
        Button(action: onBattle) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .modifier(Jiggle(active: true, amplitude: 8, period: 0.9))
                Text(L("KAMPF!"))
                HStack(spacing: 2) {
                    Image(systemName: "trophy.fill").font(.system(size: 11, weight: .black))
                    Text("+30").font(.system(size: 12, weight: .black, design: .rounded))
                }
                .foregroundColor(Theme.navy.opacity(0.75))
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background(Capsule().fill(Color.white.opacity(0.35)))
            }
        }
        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: compact ? 54 : (large ? 66 : 62), textColor: Theme.navy))
        .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
        .modifier(PulseGlow(color: Theme.gold, active: true, strength: 0.9))
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

/// Rocky gibt Tipps – ein Tipp auf die Kachel zeigt den nächsten. Seit v0.9.24 eine halbe Kachel neben der Bot-Leiter.
struct RockyTipCard: View {
    var compact = false
    @State private var index = Int.random(in: 0..<8)

    private var tips: [String] {
        [L("Frost stoppt eine gegnerische Figur – und danach ziehst du trotzdem noch selbst."),
         L("Jeder Zug bringt +1 Mana – schlägst du, gibst Schach oder spielst eine Taktik, gibt es +1 extra."),
         L("Gabeln, Fesselungen und Spieße bringen dir extra Mana."),
         L("Der König ist immun gegen Karten – gegen ein gutes Matt aber nicht."),
         L("Spar dir Mana für deine Ultimate: Zur rechten Zeit dreht sie jede Partie."),
         L("Jedes 5. gelöste Puzzle bringt eine Truhe."),
         L("Auf dem Trophäenpfad zählt dein Rekord – wer abrutscht, behält seine Belohnungen."),
         L("Schild schützt eine Figur bis zum Ende des nächsten gegnerischen Zugs.")]
    }

    var body: some View {
        let list = tips
        Button {
            Haptics.shared.play(.select)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { index = (index + 1) % list.count }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image("Logo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 1.5))
                        .modifier(Jiggle(active: true, amplitude: 4, period: 2.6))
                    Text(L("ROCKYS TIPP"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Theme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
                Text(list[index % list.count])
                    .font(.system(size: compact ? 11 : 12, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(compact ? 3 : 4)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .id(index)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: compact ? 92 : 108)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.gold.opacity(0.25), lineWidth: 1))
            .clipped()
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint(L("Tippen für den nächsten Tipp"))
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
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { tl in
            let cycle = 2.2
            let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
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

/// Tagesziele mit Flammen-Serie und Truhe.
struct DailyGoalsCard: View {
    @ObservedObject var store = ProfileStore.shared
    let onGoal: (ProfileStore.DailyGoal.Kind) -> Void
    let onChest: () -> Void
    @State var wobble = false

    var body: some View {
        let goals = store.dailyGoals
        let done = goals.filter(\.done).count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("TAGESZIELE"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(Theme.textMuted)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(store.flameLitToday
                                         ? AnyShapeStyle(LinearGradient(colors: [FlameStyle.glow, FlameStyle.lit], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(FlameStyle.off))
                    Text(store.currentStreak == 1 ? L("1 Tag in Folge") : L("{0} Tage in Folge", store.currentStreak))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(store.flameLitToday ? FlameStyle.lit : Theme.textSecondary)
                }
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(spacing: 6) {
                    ForEach(goals) { g in
                        Button { if !g.done { onGoal(g.kind) } } label: {
                            HStack(spacing: 10) {
                                Image(systemName: g.done ? "checkmark" : g.icon)
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundColor(g.done ? Theme.navy : Theme.textSecondary)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(g.done ? Theme.gold : Theme.panelHighlight))
                                Text(g.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(g.done ? Theme.textMuted : Theme.textPrimary)
                                    .strikethrough(g.done, color: Theme.textMuted)
                                Spacer(minLength: 0)
                                if !g.done {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Theme.textMuted)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                chest(done: done, total: goals.count)
            }
            WeekStrip()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
        .onAppear {
            foreverAnimation(.easeInOut(duration: 0.18).repeatForever(autoreverses: true)) { wobble = true }
        }
    }

    private func chest(done: Int, total: Int) -> some View {
        let ready = store.dailyChestReady
        let opened = store.dailyChestOpened
        return Button(action: onChest) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: Double(done) / Double(max(1, total)))
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Circle().stroke(Theme.panelHighlight, lineWidth: 4).opacity(done == total ? 0 : 1)
                    if opened {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.gold)
                    } else {
                        ChestView(rarity: .gold, size: 36, glow: ready ? 0.7 : 0)
                            .saturation(ready ? 1 : 0.2)
                            .rotationEffect(.degrees(ready ? (wobble ? 8 : -8) : 0))
                    }
                }
                .frame(width: 60, height: 60)
                Text(opened ? L("Geöffnet") : (ready ? L("Öffnen!") : "\(done)/\(total)"))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(ready ? Theme.gold : Theme.textSecondary)
                Text(L("Goldtruhe"))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.gold)
                    .opacity(opened ? 0.4 : 1)
            }
            .frame(width: 76)
        }
        .buttonStyle(.plain)
        .disabled(!ready)
        .accessibilityLabel(opened ? L("Tagestruhe geöffnet") : L("Tagestruhe, {0} von {1} Zielen", done, total))
    }
}

/// Kachel für weitere Spielmodi.
struct ModeTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(tint)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(tint.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 15, weight: .bold))
                    Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .buttonStyle(PanelButtonStyle())
    }
}

/// Dekoratives Mini-Brett auf der Startseite.
struct MiniBoardHero: View {
    private let pieces: [(Int, Int, PieceType, PlayerColor)] = [
        (0, 4, .king, .black), (1, 3, .pawn, .black), (1, 5, .pawn, .black), (2, 2, .knight, .black),
        (3, 4, .pawn, .black), (4, 4, .pawn, .white), (5, 5, .knight, .white), (6, 3, .pawn, .white),
        (7, 4, .king, .white), (4, 2, .bishop, .white), (2, 6, .queen, .black)
    ]

    var body: some View {
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
                ForEach(0..<pieces.count, id: \.self) { i in
                    let p = pieces[i]
                    PieceImage(type: p.2, color: p.3)
                        .frame(width: s * 0.92, height: s * 0.92)
                        .offset(x: CGFloat(p.1) * s + s * 0.04, y: CGFloat(p.0) * s + s * 0.04)
                }
                // Karten-Akzente
                Image(systemName: "snowflake")
                    .font(.system(size: s * 0.35, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color(hex: 0x0288D1)))
                    .offset(x: 2.6 * s, y: 2 * s)
                Image(systemName: "shield.fill")
                    .font(.system(size: s * 0.35, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color(hex: 0x1976D2)))
                    .offset(x: 5.6 * s, y: 5 * s)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
    }
}

// MARK: - Spiel einrichten

struct PlaySetupSheet: View {
    @ObservedObject private var store = ProfileStore.shared
    /// Speichert die Auswahl – gestartet wird auf der Startseite mit „Kampf!“.
    let onSave: (TimeControl, Bool) -> Void
    /// „Zu zweit an einem Gerät“ starten
    var onHotSeat: (() -> Void)? = nil
    @State private var time: TimeControl = .blitz3
    @State private var white = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // Passt der Inhalt auf den Bildschirm, gibt es keinen ScrollView – dann greift
            // das Herunterwischen des Fensters immer. Nur bei großer Schrift wird gescrollt.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .onAppear {
            time = store.profile.settings.timeControl
            white = store.profile.settings.playAsWhite
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L("Partie einstellen"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.panelRaised))
                }
                .accessibilityLabel(L("Schließen"))
            }
            .padding(.top, 20)

            SectionHeader(title: L("Bedenkzeit"))
            segmented(TimeControl.offlineChoices.map { t in (t.name, t == time, { time = t }) })

            SectionHeader(title: L("Deine Farbe"))
            segmented([(L("Weiß"), white, { white = true }), (L("Schwarz"), !white, { white = false })])

            Text(L("Deck und Ultimate stellst du im Tab „Deck“ ein. Den Gegner bestimmen deine Trophäen."))
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)

            Button {
                onSave(time, white)
            } label: {
                Label(L("Speichern"), systemImage: "checkmark")
            }
            .buttonStyle(ChunkyButtonStyle())
            .padding(.top, 6)

            if let onHotSeat {
                Button(action: onHotSeat) {
                    Label(L("Zu zweit an einem Gerät spielen"), systemImage: "person.2.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private func segmented(_ items: [(String, Bool, () -> Void)]) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<items.count, id: \.self) { i in
                let item = items[i]
                Button {
                    item.2()
                    Haptics.shared.play(.select)
                } label: {
                    Text(item.0)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(item.1 ? .white : Theme.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(RoundedRectangle(cornerRadius: 8).fill(item.1 ? Theme.greenDark : Theme.panelRaised))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(item.1 ? Theme.green : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Willkommen

struct WelcomeView: View {
    @ObservedObject private var store = ProfileStore.shared
    let onDone: () -> Void
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("crown.fill", L("Willkommen bei Rook Raid"),
         L("Es gelten alle Schachregeln. Gewonnen wird nur durch Schachmatt oder wenn die Uhr des Gegners abläuft.")),
        ("drop.fill", L("Zug oder Karte"),
         L("Jede Runde machst du genau eine Aktion: einen Schachzug oder eine Karte. Karten kosten Mana – einfrieren, schützen, Bauern verstärken.")),
        ("star.fill", L("Mana sammeln"),
         L("Jeder Zug lädt +1 Mana, ein guter Zug – Schlagen, Schach oder eine Taktik – nochmal +1. Ab 8 Mana zündest du deine Ultimate."))
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                if page < pages.count {
                    let p = pages[page]
                    Image(systemName: p.0)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(page == 1 ? Theme.mana : Theme.gold)
                        .frame(height: 90)
                        .id(page)
                        .transition(.scale.combined(with: .opacity))
                    Text(p.1)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(p.2)
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                } else {
                    Text(L("Wie gut kennst du Schach?"))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    VStack(spacing: 10) {
                        experienceButton(L("Ich bin neu"), hints: true, level: .easy)
                        experienceButton(L("Ich kenne die Regeln"), hints: true, level: .medium)
                        experienceButton(L("Ich spiele regelmäßig"), hints: false, level: .hard)
                    }
                    .padding(.horizontal, 24)
                }
                Spacer()
                if page < pages.count {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Circle().fill(i == page ? Theme.green : Theme.panelHighlight).frame(width: 8, height: 8)
                        }
                    }
                    Button(L("Weiter")) {
                        withAnimation(.spring()) { page += 1 }
                        Haptics.shared.play(.select)
                    }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func experienceButton(_ title: String, hints: Bool, level: BotLevel) -> some View {
        Button {
            var settings = store.profile.settings
            settings.hints = hints
            settings.botLevel = level
            store.profile.settings = settings
            store.profile.tutorialSeen = true
            Haptics.shared.play(.victory)
            onDone()
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(PanelButtonStyle())
    }
}

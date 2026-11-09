import SwiftUI

// MARK: - Duell-Intro

/// Kurzes Intro vor jeder Bot-Partie: Beide Seiten knallen ins Bild, „VS“ schlägt ein. Tippen überspringt.
struct VersusIntro: View {
    @ObservedObject var vm: GameViewModel
    let onFinish: () -> Void
    @ObservedObject private var store = ProfileStore.shared
    @State private var slide: CGFloat = 1
    @State private var vsScale: CGFloat = 3.5
    @State private var vsOpacity: Double = 0
    @State private var flash: Double = 0
    @State private var leaving = false
    @State private var done = false

    var body: some View {
        let level = vm.botLevel ?? .easy
        let opp = vm.humanColor.opponent
        let disguise = vm.opponentCard
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.88).ignoresSafeArea()
                VStack(spacing: 0) {
                    // Gegner oben (rot), von rechts
                    side(color: Theme.red, alignment: .trailing) {
                        HStack(spacing: 14) {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(disguise?.name ?? level.displayName)
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text(disguise.map { L("{0} Trophäen", $0.trophies) }
                                     ?? (vm.mode.isLadder ? level.title : (vm.mode.isPractice ? L("Übungspartie") : level.name)))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.redLight)
                                if vm.onlineBotPlay != nil { TrainingTag(large: true, botPlayer: vm.botPlayerCard != nil) }
                                if vm.isFriendly { FriendlyTag() }
                                deckIcons(vm.state.decks[opp]?.hand ?? [], ultimate: vm.state.ultimates[opp])
                            }
                            if let disguise, let avatar = Avatar(rawValue: disguise.avatar) {
                                PlayerAvatar(size: 92, pieceColor: opp, frame: disguise.frame.flatMap(AvatarFrame.init(rawValue:)), avatar: avatar)
                            } else {
                                BotAvatar(level: level, size: 92)
                            }
                        }
                    }
                    .offset(x: slide * geo.size.width)

                    ZStack {
                        Text(L("VS"))
                            .font(.system(size: 76, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .shadow(color: Theme.gold.opacity(0.8), radius: 20)
                            .scaleEffect(vsScale)
                            .opacity(vsOpacity)
                    }
                    .frame(height: 130)

                    // Spieler unten (blau), von links
                    side(color: Theme.blue, alignment: .leading) {
                        HStack(spacing: 14) {
                            PlayerAvatar(size: 92, pieceColor: vm.humanColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.profile.name)
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                if let title = store.activeTitle {
                                    Text(title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Theme.blueLight)
                                }
                                deckIcons(vm.state.decks[vm.humanColor]?.hand ?? [], ultimate: vm.state.ultimates[vm.humanColor])
                            }
                        }
                    }
                    .offset(x: -slide * geo.size.width)
                }
                Color.white.opacity(flash).ignoresSafeArea().allowsHitTesting(false)
            }
            .opacity(leaving ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .onAppear { play() }
        .accessibilityLabel(L("Duell gegen {0}. Tippen zum Überspringen.", vm.name(for: vm.humanColor.opponent)))
    }

    private func side<C: View>(color: Color, alignment: HorizontalAlignment, @ViewBuilder content: () -> C) -> some View {
        content()
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            .frame(height: 150)
            .background(
                LinearGradient(colors: alignment == .leading ? [color.opacity(0.7), color.opacity(0.05)] : [color.opacity(0.05), color.opacity(0.7)],
                               startPoint: .leading, endPoint: .trailing)
                    .rotationEffect(.degrees(-4))
                    .scaleEffect(1.2)
            )
            .clipped()
    }

    private func deckIcons(_ cards: [CardType], ultimate: Ultimate?) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                CardArtThumb(art: "art-card-\(card.rawValue)", width: 22)
            }
            if let ultimate {
                CardArtThumb(art: "art-ult-\(ultimate.rawValue)", width: 22, border: CardStyle.ultimate)
            }
        }
    }

    private func play() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) { slide = 0 }
        later(0.18) { Haptics.shared.play(.chestCharge1) }
        later(0.36) {
            Haptics.shared.play(.chestLand)
            SoundPlayer.shared.play(.chestLand)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                vsScale = 1
                vsOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.06)) { flash = 0.5 }
            later(0.06) { withAnimation(.easeOut(duration: 0.4)) { flash = 0 } }
        }
        later(1.75) { finish() }
    }

    private func finish() {
        guard !done else { return }
        done = true
        withAnimation(.easeIn(duration: 0.25)) { leaving = true }
        later(0.25) { onFinish() }
    }

    private func later(_ s: Double, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
            action()
        }
    }
}

// MARK: - Truhen-Plätze

/// Hintergrund einer Schatzkiste: warmes Holz mit Maserung, goldener Beschlag mit Nieten und funkelndem Goldstaub.
struct TreasureBackdrop: View {
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x4A2F14), Color(hex: 0x2E1D10), Color(hex: 0x1C1530)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Holzmaserung: feine waagerechte Bretter (einmal gezeichnet)
            Canvas { ctx, size in
                var y: CGFloat = 0
                var k = 0
                while y < size.height {
                    let h: CGFloat = 13 + CGFloat(k % 3) * 3
                    ctx.fill(Path(CGRect(x: 0, y: y + h - 1, width: size.width, height: 1)), with: .color(.black.opacity(0.22)))
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.04)))
                    y += h
                    k += 1
                }
            }
            TwinkleField(count: 10, colors: [Theme.gold, Color(hex: 0xFFE38A), .white])
                .opacity(0.45)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold, Color(hex: 0x8A5A1C)],
                                             startPoint: .top, endPoint: .bottom), lineWidth: 2)
        )
        .overlay(alignment: .topLeading) { rivet.padding(6) }
        .overlay(alignment: .topTrailing) { rivet.padding(6) }
        .overlay(alignment: .bottomLeading) { rivet.padding(6) }
        .overlay(alignment: .bottomTrailing) { rivet.padding(6) }
        .shadow(color: Color(hex: 0xF2A93B).opacity(0.18), radius: 10, y: 3)
    }

    private var rivet: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFFF1B8), Theme.gold, Color(hex: 0x8A5A1C)], center: .topLeading, startRadius: 0, endRadius: 4))
            .frame(width: 5, height: 5)
            .allowsHitTesting(false)
    }
}

// MARK: - Tagesziele

extension ProfileStore {
    /// Zeit bis Mitternacht, wenn Tagesziele, Tagestruhe und Tagesangebote neu starten.
    static func untilMidnight(_ now: Date = Date()) -> (hours: Int, minutes: Int) {
        let cal = Calendar.current
        let next = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now) ?? now)
        let secs = max(0, Int(next.timeIntervalSince(now)))
        return (secs / 3600, (secs % 3600) / 60)
    }

    static func untilMidnightText(_ now: Date = Date()) -> String {
        let t = untilMidnight(now)
        return t.hours > 0 ? L("{0} h {1} min", t.hours, t.minutes) : L("{0} min", t.minutes)
    }

    static func untilMidnightShort(_ now: Date = Date()) -> String {
        let t = untilMidnight(now)
        return String(format: "%d:%02d", t.hours, t.minutes)
    }
}


// MARK: - Schatzkammer (Truhen-Fenster)

/// Truhen-Fenster (v0.9.29 neu): Schatzkammer mit den Siegtruhen des Tages auf Podesten, der Tagestruhe im
/// Zielring samt Tageszielen, dem Truhenlager zum direkten Öffnen und einer Übersicht der Truhenarten.
/// Ersetzt das frühere Tagestruhen-Fenster (gleiche Aufrufe für Ziele und Tagestruhe).
struct ChestHubSheet: View {
    @ObservedObject var store = ProfileStore.shared
    let onGoal: (ProfileStore.DailyGoal.Kind) -> Void
    let onChest: () -> Void
    var onOpen: (Chest) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    private var earnedToday: Int {
        store.profile.winChestDay == ProfileStore.dayKey() ? store.profile.winChestsToday : 0
    }
    private var pendingWin: [Chest] { store.pendingChests.filter { $0.source == .win } }
    private var unopenedToday: Int { min(earnedToday, pendingWin.count) }
    /// Alles im Lager außer der Tagestruhe
    private var stored: [Chest] { store.pendingChests.filter { $0.source != .daily }.sorted { $0.rarity > $1.rarity } }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2A1A0C), Theme.background, Color(hex: 0x1A1230)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                RadialGradient(colors: [Theme.gold.opacity(0.22), .clear], center: .top, startRadius: 10, endRadius: 420)
                    .ignoresSafeArea()
                TwinkleField(count: 18, colors: [Theme.gold, Color(hex: 0xFFE38A), .white])
                    .opacity(0.45)
                    .ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                        statsStrip
                        winSection
                        dailySection
                        if !stored.isEmpty { storageSection }
                        moreChestsSection
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { appeared = true }
            if store.dailyChestReady || !store.pendingChests.isEmpty { Haptics.shared.play(.chestLand) }
        }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                LightRays(color: Theme.gold, count: 10, speed: 0.3)
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())
                    .opacity(0.6)
                ChestView(rarity: .legendary, size: 52, glow: 0.6)
                    .scaleEffect(appeared ? 1 : 0.5)
                    .modifier(RoadBob(active: true, amplitude: 2, speed: 2.5))
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("SCHATZKAMMER"))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF1B8), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(L("Siege, Tagesziele und Belohnungen füllen deine Truhen."))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.panelRaised))
            }
            .accessibilityLabel(L("Schließen"))
        }
        .padding(.top, 12)
    }

    private func sectionTitle(_ text: String, icon: String, trailing: String? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(Theme.gold)
            Text(text)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Theme.gold)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    // MARK: Siegtruhen

    private var winSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L("SIEGTRUHEN HEUTE"), icon: "trophy.fill",
                         trailing: "\(earnedToday)/\(ProfileStore.winChestsPerDay)")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<ProfileStore.winChestsPerDay, id: \.self) { i in
                    pedestal(i)
                }
            }
            TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                Label(earnedToday >= ProfileStore.winChestsPerDay
                      ? L("Alle Siegtruhen für heute geholt – neue in {0}", ProfileStore.untilMidnightText(ctx.date))
                      : L("Jeder Sieg im Kampf füllt einen Platz – bis zu {0} pro Tag.", ProfileStore.winChestsPerDay),
                      systemImage: "info.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(14)
        .background(TreasureBackdrop(cornerRadius: 20))
    }

    /// Ein Podest pro Siegtruhe: Schatten-Truhe, nächster Platz, wartende Truhe (öffnen!) oder geöffnet.
    private func pedestal(_ i: Int) -> some View {
        let closed = i < earnedToday && i >= earnedToday - unopenedToday
        let opened = i < earnedToday && !closed
        let next = i == earnedToday
        return Button {
            if closed, let chest = pendingWin.first {
                dismiss()
                onOpen(chest)
            } else {
                Haptics.shared.play(.select)
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if closed {
                        LightRays(color: Theme.gold, count: 8, speed: 0.4)
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                            .opacity(0.6)
                    }
                    ChestView(rarity: .wood, size: 62, lid: opened ? 1 : 0, glow: closed ? 0.8 : 0)
                        .saturation(closed ? 1 : 0)
                        .opacity(closed ? 1 : (opened ? 0.4 : (next ? 0.5 : 0.25)))
                        .modifier(Jiggle(active: closed, amplitude: 5, period: 0.7))
                        .modifier(RoadBob(active: closed, amplitude: 2, speed: 4))
                    if opened {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.green)
                            .background(Circle().fill(Theme.background).padding(2))
                    } else if !closed {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white.opacity(next ? 0.9 : 0.5))
                            .offset(y: 8)
                    }
                }
                .frame(height: 78)
                // Steinpodest
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [Color(hex: 0x6B5A44), Color(hex: 0x3B2F22)], startPoint: .top, endPoint: .bottom))
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(closed ? Theme.gold : (next ? Theme.gold.opacity(0.6) : Color.white.opacity(0.1)), lineWidth: 1.2)
                        .frame(height: 14)
                }
                .padding(.horizontal, 6)
                Text(closed ? L("Öffnen!") : (opened ? L("Geöffnet") : (next ? L("Nächster Sieg") : L("Sieg {0}", i + 1))))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(closed ? Theme.navy : (next ? Theme.gold : Theme.textMuted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, closed ? 8 : 0)
                    .frame(height: 20)
                    .background(Capsule().fill(closed ? Theme.gold : Color.clear))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.25)))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(next ? Theme.gold.opacity(0.7) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .modifier(PulseGlow(color: Theme.gold, active: closed || next, strength: closed ? 0.7 : 0.35))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(closed ? L("Siegtruhe bereit, öffnen") : (opened ? L("Siegtruhe geöffnet") : L("Siegtruhe {0}: noch nicht gewonnen", i + 1)))
    }

    // MARK: Tagestruhe

    private func explain(_ kind: ProfileStore.DailyGoal.Kind) -> String {
        switch kind {
        case .flame: return L("Löse ein Puzzle oder beende eine Partie")
        case .puzzle: return L("Das Rätsel des Tages im Puzzle-Tab")
        case .win: return L("Gewinne eine Partie – Kampf oder Leiter")
        }
    }

    private var dailySection: some View {
        let goals = store.dailyGoals
        let done = goals.filter(\.done).count
        let pending = store.pendingChests.first { $0.source == .daily }
        let ready = store.dailyChestReady || pending != nil
        let opened = store.dailyChestOpened && pending == nil
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L("TAGESTRUHE"), icon: "sun.max.fill", trailing: "\(done)/\(goals.count)")
            HStack(spacing: 14) {
                ZStack {
                    if ready {
                        LightRays(color: Theme.gold, count: 12, speed: 0.45)
                            .frame(width: 130, height: 130)
                            .clipShape(Circle())
                            .opacity(0.65)
                    }
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 100, height: 100)
                    Circle()
                        .trim(from: 0, to: appeared ? Double(done) / Double(max(1, goals.count)) : 0)
                        .stroke(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold, Color(hex: 0xD98A1F)], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 100)
                    ChestView(rarity: .gold, size: 70, lid: opened ? 1 : 0, glow: ready ? 0.9 : 0.15)
                        .saturation(opened ? 0.3 : (ready ? 1 : 0.6))
                        .scaleEffect(appeared ? 1 : 0.7)
                        .modifier(Jiggle(active: ready, amplitude: 4, period: 0.8))
                        .modifier(RoadBob(active: ready, amplitude: 2, speed: 3.5))
                }
                .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 6) {
                    Text(opened ? L("Tagestruhe geöffnet!") : (ready ? L("Alle Ziele geschafft!") : L("Goldtruhe")))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(opened ? L("Morgen gibt es neue Ziele und eine neue Goldtruhe.")
                                : (ready ? L("Deine Goldtruhe wartet.") : L("Schaffe alle 3 Ziele – dann gehört dir die Goldtruhe.")))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                        Label(L("Neue Ziele in {0}", ProfileStore.untilMidnightText(ctx.date)), systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            VStack(spacing: 8) {
                ForEach(goals) { g in goalRow(g) }
            }
            if ready {
                Button {
                    dismiss()
                    onChest()
                } label: {
                    Label(L("Goldtruhe öffnen"), systemImage: "hand.tap.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 56, textColor: Theme.navy))
                .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
                .modifier(PulseGlow(color: Theme.gold, active: true))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Theme.gold.opacity(0.16), Theme.panelRaised], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1.5))
    }

    private func goalRow(_ g: ProfileStore.DailyGoal) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(g.done ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                                 : AnyShapeStyle(Color.white.opacity(0.08)))
                Image(systemName: g.done ? "checkmark" : g.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(g.done ? Theme.navy : Theme.textSecondary)
            }
            .frame(width: 38, height: 38)
            .modifier(PulseGlow(color: Theme.gold, active: g.done, strength: 0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text(g.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(g.done ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(g.done, color: Theme.textMuted)
                Text(explain(g.kind))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            if g.done {
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.gold)
                    .accessibilityLabel(L("Erledigt"))
            } else {
                Button {
                    dismiss()
                    onGoal(g.kind)
                } label: {
                    Text(L("Los"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(LinearGradient(colors: [Theme.blueLight, Theme.blue], startPoint: .top, endPoint: .bottom)))
                        .shadow(color: Theme.blueDark, radius: 0, y: 2)
                }
                .buttonStyle(PressScaleStyle())
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.22)))
    }

    // MARK: Lager

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(L("IM LAGER"), icon: "shippingbox.fill", trailing: "\(stored.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(stored) { chest in
                    Button {
                        dismiss()
                        onOpen(chest)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(RadialGradient(colors: [chest.rarity.glowColor.opacity(0.45), .clear], center: .center, startRadius: 2, endRadius: 40))
                                    .frame(width: 76, height: 76)
                                ChestView(rarity: chest.rarity, size: 54, glow: 0.5)
                                    .modifier(Jiggle(active: true, amplitude: 4, period: 1.0))
                            }
                            .frame(height: 64)
                            Text(chest.rarity.name)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundColor(chest.rarity.glowColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(chest.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(L("Öffnen"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundColor(Theme.navy)
                                .padding(.horizontal, 10)
                                .frame(height: 22)
                                .background(Capsule().fill(Theme.gold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.25)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(chest.rarity.glowColor.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel(L("{0} öffnen", chest.title))
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.panelRaised.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: Kennzahlen

    /// Bereit, geöffnet, Glücksschutz – und ein großer Knopf für die beste wartende Truhe.
    private var statsStrip: some View {
        let allCards = CardType.allCases.allSatisfy { store.isUnlocked($0) }
        let left = max(1, ProfileStore.pityLimit - store.profile.pityCounter)
        let pity = allCards ? L("Alle Karten gesammelt")
            : (left == 1 ? L("Neue Karte spätestens in der nächsten Truhe") : L("Neue Karte spätestens in {0} Truhen", left))
        let best = store.pendingChests.max { $0.rarity < $1.rarity }
        return VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) { chip("shippingbox.fill", L("{0} bereit", store.pendingChests.count), hot: best != nil); chip("checkmark.circle.fill", L("{0} geöffnet", store.profile.chestsOpened)); chip("rectangle.stack.fill", pity, tint: Color(hex: 0xC084FC)) }
                VStack(spacing: 6) {
                    HStack(spacing: 6) { chip("shippingbox.fill", L("{0} bereit", store.pendingChests.count), hot: best != nil); chip("checkmark.circle.fill", L("{0} geöffnet", store.profile.chestsOpened)) }
                    chip("rectangle.stack.fill", pity, tint: Color(hex: 0xC084FC))
                }
            }
            if let best {
                Button {
                    dismiss()
                    if best.source == .daily { onChest() } else { onOpen(best) }
                } label: {
                    HStack(spacing: 10) {
                        ChestView(rarity: best.rarity, size: 34, glow: 0.6)
                            .modifier(Jiggle(active: true, amplitude: 4, period: 0.8))
                        Text(L("{0} öffnen", best.rarity.name))
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 56, textColor: Theme.navy))
                .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
                .modifier(PulseGlow(color: Theme.gold, active: true))
            }
        }
    }

    private func chip(_ icon: String, _ text: String, hot: Bool = false, tint: Color = Theme.gold) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .black)).foregroundColor(tint)
            Text(text).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundColor(hot ? Theme.gold : Theme.textPrimary).lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Capsule().fill(hot ? Theme.gold.opacity(0.15) : Color.black.opacity(0.3)))
        .overlay(Capsule().strokeBorder(hot ? Theme.gold.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
    }

    // MARK: Mehr Truhen

    private struct Source: Identifiable {
        let id: String; let icon: String; let title: String; let sub: String; let fraction: Double; let rarity: ChestRarity?; let tint: Color
    }

    /// Woher die nächsten Truhen kommen – mit echtem Fortschritt.
    private var sources: [Source] {
        let lp = store.levelProgress
        let solved = store.profile.solvedPuzzles.count % ProfileStore.puzzlesPerChest
        let road = store.roadTrophies
        let nextRoad = ProfileStore.road.first { $0.trophies > road }
        let prevRoad = ProfileStore.road.last { $0.trophies <= road }?.trophies ?? 0
        let roadRarity: ChestRarity? = {
            switch nextRoad?.reward {
            case .chest(let r)?: return r
            case .arena(_, let r)?: return r
            default: return nil
            }
        }()
        let streak = store.currentStreak
        let nextFlame = ProfileStore.streakMilestones.first { $0.chest != nil && $0.days > streak && !store.profile.streakMilestones.contains($0.days) }
        let prevFlame = ProfileStore.streakMilestones.last { $0.days <= streak }?.days ?? 0
        let nextBot = store.ladderNext
        return [
            Source(id: "level", icon: "arrow.up.circle.fill", title: L("Level-Truhe"), sub: L("{0} XP bis Level {1}", lp.remaining, store.level + 1),
                   fraction: lp.fraction, rarity: LevelRoadStep.step(for: store.level + 1).rarity, tint: Theme.blueLight),
            Source(id: "puzzle", icon: "puzzlepiece.fill", title: L("Rätseltruhe"), sub: L("{0}/{1} gelöst", solved, ProfileStore.puzzlesPerChest),
                   fraction: Double(solved) / Double(ProfileStore.puzzlesPerChest), rarity: .silver, tint: Theme.gold),
            Source(id: "road", icon: "trophy.fill", title: L("Trophäenpfad"), sub: nextRoad.map { L("Noch {0} Trophäen", $0.trophies - road) } ?? L("Alles erreicht"),
                   fraction: nextRoad.map { Double(road - prevRoad) / Double(max(1, $0.trophies - prevRoad)) } ?? 1, rarity: roadRarity, tint: Theme.redLight),
            Source(id: "flame", icon: "flame.fill", title: L("Flammentruhe"), sub: nextFlame.map { L("Noch {0} Tage", $0.days - streak) } ?? L("Alles erreicht"),
                   fraction: nextFlame.map { Double(streak - prevFlame) / Double(max(1, $0.days - prevFlame)) } ?? 1, rarity: nextFlame?.chest, tint: Color(hex: 0xFF8A3D)),
            Source(id: "ladder", icon: "figure.stairs", title: L("Leiter-Truhe"), sub: nextBot.map { L("Nächster: {0}", $0.displayName) } ?? L("Alles erreicht"),
                   fraction: Double(store.profile.ladderBeaten) / Double(BotLevel.allCases.count), rarity: nextBot?.ladderChest, tint: Color(hex: 0xC084FC))
        ]
    }

    private var moreChestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L("MEHR TRUHEN"), icon: "plus.circle.fill")
            ForEach(sources) { src in
                let f = min(1, max(0, src.fraction))
                HStack(spacing: 10) {
                    Image(systemName: src.icon)
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [src.tint, src.tint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(src.title).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(Theme.textPrimary)
                        Text(src.sub).font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
                                Capsule().fill(LinearGradient(colors: [src.tint.opacity(0.7), src.tint], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: g.size.width * (appeared ? f : 0))
                            }
                        }
                        .frame(height: 6)
                    }
                    if let r = src.rarity {
                        ChestView(rarity: r, size: 38, glow: f >= 0.8 ? 0.6 : 0)
                            .modifier(Jiggle(active: f >= 0.8, amplitude: 4, period: 0.9))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.22)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(src.tint.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.panelRaised.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

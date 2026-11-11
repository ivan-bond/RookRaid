import SwiftUI

// MARK: - Profil-Tab: Ruhmeshalle, Bot-Bezwinger, Sammlung
//
// Bausteine für den Profil-Tab: große Zahlen, die beim Öffnen hochzählen, die zwölf Bots als Königsfiguren
// ihres Figurensets (bezwungen in Farbe mit Krone, der nächste pulsiert, der Rest als Schatten) und
// Sammelringe für Karten, Ultimates, Avatare, Rahmen und Bretter.

/// Zahl, die beim Erscheinen von 0 hochzählt (Animatable: SwiftUI rechnet die Zwischenwerte).
struct CountUpText: View, Animatable {
    var value: Double
    var font: Font = .system(size: 26, weight: .black, design: .rounded)
    var color: Color = .white

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded()))")
            .font(font)
            .monospacedDigit()
            .foregroundColor(color)
    }
}

/// Funkelnde Sterne auf festen, zufällig wirkenden Plätzen (zeitgesteuert).
struct TwinkleField: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    var count = 16
    var colors: [Color] = [.white]
    var active = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active || !live)) { tl in
            let t = clock.time(tl.date)
            Canvas { ctx, size in
                for i in 0..<count {
                    let r1 = BiomeParticles.rand(i, 7), r2 = BiomeParticles.rand(i, 8), r3 = BiomeParticles.rand(i, 9)
                    let a = max(0, sin(t * (1 + r3 * 1.5) + r1 * 12))
                    guard a > 0.05 else { continue }
                    let c = colors[i % max(1, colors.count)]
                    ctx.fill(ParticleCanvas.star(radius: CGFloat(1.5 + 3.5 * a)).offsetBy(dx: r1 * size.width, dy: r2 * size.height),
                             with: .color(c.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Band mit eingekerbten Enden (für Titel).
struct RibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        let notch = min(8, r.height * 0.4)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - notch, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + notch, y: r.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Ruhmeshalle

/// Vier große Kacheln mit hochzählenden Zahlen.
struct HallOfFameRow: View {
    @ObservedObject var store = ProfileStore.shared
    var onAchievements: () -> Void = {}
    @State private var shown = false

    var body: some View {
        let p = store.profile
        let all = store.achievements
        let done = all.filter(\.unlocked).count
        let rate = p.gamesPlayed == 0 ? 0 : Int((p.winRate * 100).rounded())
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(icon: "building.columns.fill", title: L("Ruhmeshalle"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(icon: "crown.fill", tint: Theme.gold, value: p.wins, label: L("Siege"),
                     sub: p.gamesPlayed == 0 ? L("Noch keine Partien") : L("{0} % Siegquote", rate), phase: 0) {}
                tile(icon: "puzzlepiece.fill", tint: Theme.manaLight, value: p.solvedPuzzles.count, label: L("Puzzles gelöst"),
                     sub: L("Zum Puzzle-Tab"), phase: 1) {
                    NotificationCenter.default.post(name: .showPuzzles, object: nil)
                }
                tile(icon: "rosette", tint: Color(hex: 0xF0B07A), value: done, label: L("Erfolge"),
                     sub: L("von {0}", all.count), phase: 2, action: onAchievements)
                tile(icon: "calendar", tint: FlameStyle.lit, value: p.activeDays.count, label: L("Aktive Tage"),
                     sub: L("Rekordflamme {0}", p.bestStreak), phase: 3) {}
            }
        }
        .onAppear {
            guard !shown else { return }
            withAnimation(.easeOut(duration: 1.1).delay(0.15)) { shown = true }
        }
    }

    private func tile(icon: String, tint: Color, value: Int, label: String, sub: String, phase: Double,
                      action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.play(.select)
            action()
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.1)], center: .center, startRadius: 2, endRadius: 24))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .shadow(color: tint, radius: 6)
                }
                .frame(width: 42, height: 42)
                .modifier(RoadBob(active: true, amplitude: 1.5, speed: 2.2, phase: phase))
                VStack(alignment: .leading, spacing: 0) {
                    CountUpText(value: shown ? Double(value) : 0, font: .system(size: 24, weight: .black, design: .rounded))
                    Text(label)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(sub)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [tint.opacity(0.2), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bot-Bezwinger

/// Die zwölf Bots der Leiter: bezwungen in Farbe mit Krone, der nächste pulsiert, der Rest als Schatten.
struct BotConquestCard: View {
    @ObservedObject var store = ProfileStore.shared

    var body: some View {
        let beaten = min(store.profile.ladderBeaten, BotLevel.allCases.count)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardTitle(icon: "figure.stairs", title: L("Bot-Bezwinger"))
                Text("\(beaten)/\(BotLevel.allCases.count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.gold)
                Spacer()
                Button {
                    NotificationCenter.default.post(name: .showLadder, object: nil)
                } label: {
                    HStack(spacing: 3) {
                        Text(L("Zur Leiter"))
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .black))
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.blueLight)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 10) {
                ForEach(BotLevel.allCases) { bot in
                    botCell(bot, beaten: bot.tier <= beaten, next: bot.tier == beaten + 1)
                }
            }
            if beaten < BotLevel.allCases.count, let next = BotLevel.allCases.first(where: { $0.tier == beaten + 1 }) {
                HStack(spacing: 6) {
                    Image(systemName: "scope").foregroundColor(Theme.redLight)
                    Text(L("Nächster Gegner: {0}, {1}", next.displayName, next.title))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 12, weight: .bold))
            } else {
                Label(L("Alle zwölf bezwungen – du bist eine Legende!"), systemImage: "crown.fill")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Theme.gold)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0x2A1838), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    private func botCell(_ bot: BotLevel, beaten: Bool, next: Bool) -> some View {
        let c = Color(hex: bot.colorHex)
        return VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [c.opacity(beaten ? 0.7 : (next ? 0.4 : 0.1)), Theme.panel],
                                         center: .center, startRadius: 2, endRadius: 26))
                Circle()
                    .strokeBorder(beaten ? c : (next ? Color.white.opacity(0.8) : Theme.panelHighlight), lineWidth: next ? 2 : 1.5)
                PieceImage(type: .king, color: .white, skin: bot)
                    .frame(width: 32, height: 32)
                    .colorMultiply(beaten || next ? .white : Color(hex: 0x10182E))
                    .saturation(next && !beaten ? 0.4 : 1)
                if !beaten && !next {
                    Text("?")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(width: 46, height: 46)
            .overlay(alignment: .top) {
                if beaten {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Theme.gold)
                        .shadow(color: .black.opacity(0.5), radius: 0, y: 1)
                        .offset(y: -7)
                }
            }
            .modifier(PulseGlow(color: Color.white, active: next, strength: 0.6))
            .modifier(RoadBob(active: next, amplitude: 2, speed: 3))
            Text(beaten || next ? bot.displayName : "\(bot.tier)")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(beaten ? Theme.textPrimary : Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(beaten ? L("{0} besiegt", bot.displayName) : (next ? L("Nächster Gegner: {0}, {1}", bot.displayName, bot.title) : L("Unbekannter Gegner")))
    }
}

// MARK: - Sammlung

/// Sammelringe: Karten, Ultimates, Avatare, Rahmen, Bretter und Figurensets.
struct CollectionRingsCard: View {
    @ObservedObject var store = ProfileStore.shared
    var onStyle: (StyleSheet.StyleTab) -> Void = { _ in }
    @State private var shown = false

    var body: some View {
        let cards = store.unlockedCards.count
        let ults = Ultimate.allCases.filter { store.isUnlocked($0) }.count
        let avatars = Avatar.allCases.filter { store.isOwned($0) }.count
        let frames = store.unlockedFrames.count
        let boards = BoardTheme.allCases.filter { store.isOwned($0) }.count
        let sets = store.unlockedSkinCount + 1
        let owned = cards + ults + avatars + frames + boards + sets
        let total = CardType.allCases.count + Ultimate.allCases.count + Avatar.allCases.count + AvatarFrame.allCases.count
            + BoardTheme.allCases.count + BotLevel.allCases.count + 1
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CardTitle(icon: "square.stack.3d.up.fill", title: L("Sammlung"))
                Spacer()
                Text(L("{0} % gesammelt", Int((Double(owned) / Double(max(1, total)) * 100).rounded())))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.gold)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 12) {
                ring(L("Karten"), icon: "rectangle.portrait.fill", tint: Theme.blueLight, have: cards, of: CardType.allCases.count) {
                    NotificationCenter.default.post(name: .showDeck, object: nil)
                }
                ring(L("Ultimates"), icon: "sparkles", tint: Theme.gold, have: ults, of: Ultimate.allCases.count) {
                    NotificationCenter.default.post(name: .showDeck, object: nil)
                }
                ring(L("Avatare"), icon: "person.fill", tint: Theme.redLight, have: avatars, of: Avatar.allCases.count) { onStyle(.avatars) }
                ring(L("Rahmen"), icon: "circle.dashed", tint: Theme.manaLight, have: frames, of: AvatarFrame.allCases.count) { onStyle(.frames) }
                ring(L("Bretter"), icon: "square.grid.2x2.fill", tint: Color(hex: 0x7FE3FF), have: boards, of: BoardTheme.allCases.count) { onStyle(.boards) }
                ring(L("Figuren"), icon: "crown.fill", tint: Color(hex: 0xF0B07A), have: sets, of: BotLevel.allCases.count + 1) { onStyle(.pieces) }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panelRaised))
        .onAppear {
            guard !shown else { return }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) { shown = true }
        }
    }

    private func ring(_ label: String, icon: String, tint: Color, have: Int, of total: Int, action: @escaping () -> Void) -> some View {
        let frac = Double(have) / Double(max(1, total))
        let full = have >= total
        return Button {
            Haptics.shared.play(.select)
            action()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: shown ? max(0.02, frac) : 0)
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: tint.opacity(0.6), radius: 4)
                    Image(systemName: full ? "checkmark" : icon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(full ? Theme.gold : .white)
                }
                .frame(width: 50, height: 50)
                .modifier(PulseGlow(color: Theme.gold, active: full, strength: 0.6))
                Text("\(have)/\(total)")
                    .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("\(label): \(have)/\(total)")
    }
}

// MARK: - Form

/// Die letzten Partien als Kugeln (Sieg blau, Niederlage rot, Remis grau), neueste rechts.
struct FormDots: View {
    let results: [GameResultKind]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(results.enumerated()), id: \.offset) { _, r in
                Circle()
                    .fill(color(r))
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8))
            }
        }
        .accessibilityHidden(true)
    }

    private func color(_ r: GameResultKind) -> Color {
        switch r {
        case .win: return Theme.blue
        case .loss: return Theme.red
        case .draw: return Theme.textMuted
        }
    }
}

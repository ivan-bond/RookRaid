import SwiftUI

// MARK: - Ende der Partie
//
// Das Fenster baut sich in Etappen auf, damit sich ein Sieg wie ein Sieg anfühlt:
// 1. Das Band („SIEG!“) knallt herein, Strahlen drehen sich, Konfetti regnet.
// 2. Die Helden: dein Avatar mit Krone, daneben der besiegte Gegner (grau, mit Riss).
// 3. Die Beute: Kacheln für Trophäen, XP und Flamme springen nacheinander auf – mit Haptik und Klang.
// 4. Truhen, Pfad-Belohnung und die Knöpfe.
// Ein Tipp beschleunigt alles auf einmal. Niederlage und Remis bleiben ruhiger, aber freundlich.

struct GameOverOverlay: View {
    let info: GameOverInfo
    let onRematch: () -> Void
    let onExit: () -> Void
    /// Direkt weiter: nächster Kampf oder nächster Leiter-Gegner (nil = nur Revanche und Menü)
    var next: NextGame? = nil
    /// Online gibt es keine Revanche – die Partie ist vorbei.
    var allowsRematch = true
    var onOpenChest: (() -> Void)? = nil

    struct NextGame {
        let title: String
        let icon: String
        let action: () -> Void
    }
    @ObservedObject private var store = ProfileStore.shared

    /// 0 nichts · 1 Band · 2 Helden · 3 Beute · 4 Truhen & Knöpfe
    @State private var stage = 0
    @State private var tilesShown = 0
    @State private var shownDelta = 0
    @State private var confettiSeed = UInt64.random(in: 1...UInt64.max)
    @State private var secondBurst = false
    @State private var crownBob = false
    @State private var sequence: Task<Void, Never>?
    @State private var cardHeight: CGFloat = 0
    /// Verdiente Truhen öffnen sich einmal von selbst, kurz nachdem sie hereingefallen sind.
    @State private var autoOpened = false

    private var victory: Bool { info.result == .win || (info.result == nil && info.hasWinner) }
    private var lost: Bool { info.result == .loss }

    var body: some View {
        ZStack {
            Color.black.opacity(victory ? 0.62 : 0.55).ignoresSafeArea()
                .onTapGesture { if stage < 4 { finishNow() } }

            if victory {
                VictoryRays(color: Theme.gold.opacity(0.22))
                    .frame(width: 720, height: 720)
                    .offset(y: -150)
                    .opacity(stage >= 1 ? 1 : 0)
                    .scaleEffect(stage >= 1 ? 1 : 0.3)
                    .animation(.easeOut(duration: 0.6), value: stage >= 1)
                    .allowsHitTesting(false)
                ConfettiView(seed: confettiSeed).ignoresSafeArea()
                if secondBurst {
                    ConfettiView(seed: confettiSeed &+ 7).ignoresSafeArea()
                }
            }

            // Kein Scrollen: Die Karte misst ihre natürliche Höhe und schrumpft, falls sie nicht auf den Bildschirm passt.
            GeometryReader { geo in
                let available = geo.size.height - 24
                let fit = cardHeight > available && cardHeight > 0 ? max(0.6, available / cardHeight) : 1
                VStack(spacing: 11) {
                    ribbon
                        .padding(.top, 2)
                    heroes
                    titles
                    if stage >= 3 { lootRow }
                    if stage >= 3, !statChips.isEmpty { statsRow }
                    if stage >= 4 { extras }
                    if stage >= 4 { buttons }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .frame(maxWidth: 360)
                .fixedSize(horizontal: false, vertical: true)
                .background(card)
                .background(GeometryReader { g in Color.clear.preference(key: CardHeightKey.self, value: g.size.height) })
                .contentShape(Rectangle())
                .onTapGesture { if stage < 4 { finishNow() } }
                .scaleEffect(fit)
                .animation(.easeOut(duration: 0.25), value: fit)
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .padding(.horizontal, 16)
            .onPreferenceChange(CardHeightKey.self) { cardHeight = $0 }
        }
        .onAppear(perform: runSequence)
        .onDisappear { sequence?.cancel() }
    }

    // MARK: Band

    private var ribbonText: String {
        if victory { return L("SIEG!") }
        if lost { return L("NIEDERLAGE") }
        return info.result == .draw ? L("REMIS") : L("PARTIE VORBEI")
    }

    private var ribbonColors: [Color] {
        if victory { return [Color(hex: 0xFFD866), Color(hex: 0xF0A419)] }
        if lost { return [Color(hex: 0xE5636A), Color(hex: 0xA8323B)] }
        return [Color(hex: 0x8FA3C7), Color(hex: 0x5D6F92)]
    }

    private var ribbon: some View {
        Text(ribbonText)
            .font(.system(size: victory ? 36 : 28, weight: .black, design: .rounded))
            .italic()
            .foregroundColor(victory ? Theme.navy : .white)
            .shadow(color: .white.opacity(victory ? 0.5 : 0), radius: 0, y: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 44)
            .padding(.vertical, 10)
            .background(
                VictoryRibbonShape()
                    .fill(LinearGradient(colors: ribbonColors, startPoint: .top, endPoint: .bottom))
                    .shadow(color: (ribbonColors.last ?? .black).opacity(0.6), radius: 0, y: 5)
            )
            .rotationEffect(.degrees(stage >= 1 ? -3 : -14))
            .scaleEffect(stage >= 1 ? 1 : 2.6)
            .opacity(stage >= 1 ? 1 : 0)
            .animation(.spring(response: 0.38, dampingFraction: 0.52), value: stage >= 1)
    }

    // MARK: Helden

    @ViewBuilder
    private var heroes: some View {
        HStack(alignment: .center, spacing: 18) {
            heroBadge(isMe: true)
            if let card = info.disguise {
                Image(systemName: victory ? "bolt.fill" : (lost ? "xmark" : "equal"))
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(victory ? Theme.gold : Theme.textMuted)
                    .rotationEffect(.degrees(stage >= 2 ? 0 : -90))
                PlayerAvatar(size: 80, pieceColor: .black,
                             frame: card.frame.flatMap(AvatarFrame.init(rawValue:)),
                             avatar: Avatar(rawValue: card.avatar))
                    .saturation(victory ? 0.35 : 1)
            } else if let level = info.opponent {
                Image(systemName: victory ? "bolt.fill" : (lost ? "xmark" : "equal"))
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(victory ? Theme.gold : Theme.textMuted)
                    .rotationEffect(.degrees(stage >= 2 ? 0 : -90))
                botBadge(level)
            }
        }
        .scaleEffect(stage >= 2 ? 1 : 0.5)
        .opacity(stage >= 2 ? 1 : 0)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: stage >= 2)
    }

    private func heroBadge(isMe: Bool) -> some View {
        let winnerIsMe = victory
        return ZStack(alignment: .top) {
            if info.result == nil, let w = info.winnerColor {
                // Zu zweit: der König der siegreichen Farbe
                ZStack {
                    Circle().fill(Theme.panelRaised)
                    Circle().strokeBorder(Theme.gold, lineWidth: 5)
                    PieceImage(type: .king, color: w).padding(18)
                }
                .frame(width: 92, height: 92)
                .shadow(color: Theme.gold.opacity(0.7), radius: 16)
            } else {
                PlayerAvatar(size: info.opponent == nil ? 92 : 80)
                .saturation(lost ? 0.35 : 1)
                .shadow(color: winnerIsMe ? Theme.gold.opacity(0.7) : .clear, radius: 16)
            }
            if winnerIsMe {
                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.4), radius: 0, y: 2)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -26, y: crownBob ? -30 : -24)
                    .scaleEffect(stage >= 2 ? 1 : 0.1)
                    .animation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.25), value: stage >= 2)
            }
        }
    }

    private func botBadge(_ level: BotLevel) -> some View {
        ZStack(alignment: .top) {
            BotAvatar(level: level, size: 64)
                .saturation(victory ? 0.15 : 1)
                .opacity(victory ? 0.75 : 1)
                .overlay(
                    // Riss über dem besiegten Gegner
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 40, weight: .black))
                        .foregroundColor(Theme.red.opacity(0.85))
                        .rotationEffect(.degrees(20))
                        .opacity(victory && stage >= 2 ? 1 : 0)
                        .scaleEffect(victory && stage >= 2 ? 1 : 2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.35), value: stage >= 2)
                )
            if lost {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Theme.gold)
                    .offset(y: -22)
            }
        }
    }

    private var titles: some View {
        VStack(spacing: 4) {
            Text(info.title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(info.subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            if lost {
                Text(L("Kopf hoch – jede Partie macht dich stärker."))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        .opacity(stage >= 2 ? 1 : 0)
        .offset(y: stage >= 2 ? 0 : 12)
        .animation(.easeOut(duration: 0.35).delay(0.1), value: stage >= 2)
    }

    // MARK: Beute

    private struct Loot: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let label: String
    }

    private var loot: [Loot] {
        var list: [Loot] = []
        if info.rated {
            list.append(Loot(id: "trophy", icon: "trophy.fill", color: info.trophyDelta >= 0 ? Theme.gold : Theme.red, label: L("Trophäen")))
        }
        if info.ladderXP != nil {
            list.append(Loot(id: "xp", icon: "sparkles", color: Theme.manaLight, label: L("Erfahrung")))
        }
        if info.streakLit != nil {
            list.append(Loot(id: "flame", icon: "flame.fill", color: FlameStyle.lit, label: L("Flamme")))
        }
        return list
    }

    private func lootValue(_ l: Loot) -> String {
        switch l.id {
        case "trophy": return shownDelta >= 0 ? "+\(shownDelta)" : "\(shownDelta)"
        case "xp": return "+\(info.ladderXP ?? 0)"
        default: return "\(info.streakLit ?? 0)"
        }
    }

    @ViewBuilder
    private var lootRow: some View {
        if !loot.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(loot.enumerated()), id: \.element.id) { i, l in
                    let shown = i < tilesShown
                    VStack(spacing: 4) {
                        Image(systemName: l.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(l.color)
                            .shadow(color: l.color.opacity(0.6), radius: shown ? 8 : 0)
                        Text(lootValue(l))
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(l.label)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.panelRaised)
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(l.color.opacity(shown ? 0.7 : 0), lineWidth: 1.5))
                    )
                    .rotation3DEffect(.degrees(shown ? 0 : 90), axis: (x: 0, y: 1, z: 0))
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)
                    .animation(.spring(response: 0.42, dampingFraction: 0.55), value: shown)
                }
            }
            .transition(.opacity)
        }
    }

    private var statChips: [(String, String)] {
        var chips: [(String, String)] = []
        if info.moveCount > 0 { chips.append(("arrow.triangle.swap", "\(info.moveCount) " + L("Züge"))) }
        if info.cardsPlayed > 0 { chips.append(("rectangle.stack.fill", "\(info.cardsPlayed) " + L("Karten"))) }
        return chips
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(statChips.enumerated()), id: \.offset) { _, c in
                Label(c.1, systemImage: c.0)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.panel))
            }
        }
        .transition(.opacity)
    }

    // MARK: Truhen, Leiter, Pfad

    @ViewBuilder
    private var extras: some View {
        VStack(spacing: 12) {
            if let next = info.ladderUnlocked {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(Theme.gold)
                    Text(L("{0} ist freigeschaltet!", next))
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Theme.gold.opacity(0.15)))
                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
            }
            if let skin = info.skinUnlocked {
                // Neues Figurenset: die Königsfigur des besiegten Bots
                HStack(spacing: 8) {
                    PieceImage(type: .king, color: .white, skin: skin)
                        .frame(width: 26, height: 26)
                    Text(L("Neues Figurenset: {0}!", skin.skinName))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: skin.colorHex).opacity(0.2)))
                .overlay(Capsule().strokeBorder(Color(hex: skin.colorHex).opacity(0.7), lineWidth: 1))
            }
            let waiting = info.chests.filter { c in store.pendingChests.contains { $0.id == c.id } }
            if !waiting.isEmpty {
                // Kein „Öffnen“-Knopf: Die Truhen öffnen sich nach der Partie von selbst.
                EarnedChestsRow(chests: waiting, onOpen: nil)
            } else if !info.chests.isEmpty {
                Label(L("Truhen geöffnet"), systemImage: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.gold)
            } else if info.winChestsUsedUp {
                Text(L("Die drei Siegtruhen für heute sind vergeben – morgen gibt es neue."))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }

            if let step = info.roadReady {
                Button {
                    onExit()
                    NotificationCenter.default.post(name: .showTrophyRoad, object: nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .bold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L("Trophäenpfad: {0} erreicht!", step.trophies))
                                .font(.system(size: 13, weight: .heavy))
                            Text(L("{0} wartet – abholen", step.reward.title))
                                .font(.system(size: 11, weight: .semibold))
                                .opacity(0.85)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(Theme.navy)
                    .padding(.horizontal, 12)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold))
                    .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)))
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Höchstens drei Knöpfe: der nächste Schritt groß, darunter Revanche und Menü.
    /// Online ohne Revanche. Brett und Nachspielen gibt es im Verlauf.
    private var buttons: some View {
        VStack(spacing: 10) {
            if let next {
                Button(action: next.action) {
                    Label(next.title, systemImage: next.icon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(victory ? ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, textColor: Theme.navy)
                                     : ChunkyButtonStyle())
                .overlay {
                    if victory {
                        ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false)
                    }
                }
            }
            if allowsRematch {
                if next != nil {
                    HStack(spacing: 10) {
                        rematchButton(height: 48, prominent: false)
                        menuButton
                    }
                } else {
                    rematchButton(height: 58, prominent: true)
                    menuButton
                }
            } else {
                menuButton
            }
        }
        .padding(.top, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func rematchButton(height: CGFloat, prominent: Bool) -> some View {
        Button(action: onRematch) {
            Label(lost && prominent ? L("Nochmal versuchen") : L("Revanche"), systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(prominent
                     ? ChunkyButtonStyle()
                     : ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: height))
    }

    private var menuButton: some View {
        Button(L("Zum Menü"), action: onExit)
            .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 48))
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(LinearGradient(colors: [Theme.panelRaised, Theme.background], startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(victory ? Theme.gold.opacity(0.75) : Theme.panelHighlight, lineWidth: victory ? 2 : 1)
            )
            .shadow(color: victory ? Theme.gold.opacity(0.35) : .black.opacity(0.5), radius: 24)
    }

    // MARK: Ablauf

    private func runSequence() {
        sequence = Task { @MainActor in
            func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
            await wait(0.05)
            guard !Task.isCancelled else { return }
            stage = 1
            Haptics.shared.play(victory ? .chestBurst : .heavyCapture)
            if victory { SoundPlayer.shared.play(.rewardBig, volume: 0.8) }
            await wait(0.42)
            guard !Task.isCancelled else { return }
            stage = 2
            if victory {
                Haptics.shared.play(.chestReveal)
                foreverAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { crownBob = true }
            }
            await wait(0.5)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { stage = 3 }
            for i in 0..<loot.count {
                await wait(0.24)
                guard !Task.isCancelled else { return }
                tilesShown = i + 1
                Haptics.shared.play(.tick)
                SoundPlayer.shared.play(.reward, volume: 0.6)
                if loot[i].id == "trophy" {
                    withAnimation(.easeOut(duration: 0.7)) { shownDelta = info.trophyDelta }
                }
            }
            if victory {
                await wait(0.15)
                secondBurst = true
            }
            await wait(loot.isEmpty ? 0.1 : 0.45)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { stage = 4 }
            scheduleChestOpening()
        }
    }

    /// Truhen aus dieser Partie: kurz hereinfallen lassen, dann direkt öffnen.
    private func scheduleChestOpening() {
        guard !autoOpened, onOpenChest != nil else { return }
        let waiting = info.chests.filter { c in store.pendingChests.contains { $0.id == c.id } }
        guard !waiting.isEmpty else { return }
        autoOpened = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            onOpenChest?()
        }
    }

    /// Tipp während des Aufbaus: alles sofort zeigen.
    private func finishNow() {
        sequence?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            stage = 4
            tilesShown = loot.count
            shownDelta = info.trophyDelta
        }
        if victory { foreverAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { crownBob = true } }
        scheduleChestOpening()
    }
}

/// Band mit eingekerbten Enden.
struct VictoryRibbonShape: Shape {
    func path(in r: CGRect) -> Path {
        let notch = r.height * 0.32
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

/// Langsam drehende Lichtstrahlen hinter einem Sieg. Ein einziges gezeichnetes Bild, das nur gedreht wird –
/// das kostet fast nichts.
struct VictoryRays: View {
    var color: Color
    var count = 16
    @State private var spin = false

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let r = max(size.width, size.height)
            for i in 0..<count {
                let a0 = Double(i) / Double(count) * 2 * .pi
                let a1 = a0 + .pi / Double(count)
                var p = Path()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + r * cos(a0), y: c.y + r * sin(a0)))
                p.addLine(to: CGPoint(x: c.x + r * cos(a1), y: c.y + r * sin(a1)))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
            }
        }
        .mask(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 20, endRadius: 340))
        .drawingGroup()
        .rotationEffect(.degrees(spin ? 360 : 0))
        .onAppear {
            foreverAnimation(.linear(duration: 24).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

/// Natürliche Höhe des Ergebnisfensters (zum Einpassen ohne Scrollen)
private struct CardHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

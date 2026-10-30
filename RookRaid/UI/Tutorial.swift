import SwiftUI

/// Eine Aufgabe der geführten ersten Partie. Es gibt keine Erklärfenster mehr:
/// Jede Aufgabe ist eine echte Aktion, nach dem Erfüllen geht es direkt weiter.
struct TutorialStep {
    enum Expect: Equatable {
        case move(from: String, to: String)
        case card(CardType, target: String?)
        case ultimate(target: String?)
    }

    let expect: Expect
    let icon: String
    let title: String
    let text: String
    /// Kurzer Jubel nach dem Erfüllen.
    let praise: String
    /// Antwort von Schwarz (UCI) nach der Spieleraktion.
    var reply: String? = nil
    /// Hebt die Mana-Leiste hervor (Name aus der Zeit, als hier der Gebietsbalken saß).
    var highlightTerritory = false
    /// Vor dieser Aufgabe wird die Mana-Leiste gefüllt.
    var fillMana = false
    /// Feste Belohnung zusätzlich zu Gebiet und Mana (z. B. „Bauer vernichtet“).
    var reward: QuestReward? = nil
}

/// Das Drehbuch der ersten Schlacht. Jeder Zug wurde mit der Engine geprüft und endet mit Schachmatt.
/// Mila spielt dabei vernünftig: Eröffnungszüge aus dem Lehrbuch (Zweispringerspiel) und danach jeweils
/// den besten Zug, den eine Engine ohne Wissen über deine Karten findet. Sie verliert, weil sie Schild,
/// Meteor und Frost nicht kommen sieht – nicht, weil sie Unsinn zieht.
enum TutorialScript {
    static let playerHand: [CardType] = [.lightning, .shield, .sprint, .freeze]

    static var steps: [TutorialStep] { [
        TutorialStep(expect: .move(from: "e2", to: "e4"), icon: "hand.point.up.left.fill",
                     title: L("Willkommen in der Arena!"),
                     text: L("Schach mit Karten und Superkräften. Zieh deinen Bauern von e2 nach e4."),
                     praise: L("Starker Auftakt!"), reply: "e7e5"),
        TutorialStep(expect: .move(from: "g1", to: "f3"), icon: "drop.fill",
                     title: L("Jeder Zug lädt Mana"),
                     text: L("+1 Mana pro Zug, gute Züge +1 extra – unten siehst du deine Leiste. Springer nach f3: g1 → f3."),
                     praise: L("Mana geladen!"), reply: "b8c6", highlightTerritory: true),
        TutorialStep(expect: .move(from: "f1", to: "c4"), icon: "scope",
                     title: L("Ziel: f7"),
                     text: L("f7 ist Milas schwächster Punkt – nur der König deckt ihn. Läufer nach c4, er zielt genau dorthin."),
                     praise: L("Im Visier!"), reply: "g8f6"),
        TutorialStep(expect: .move(from: "f3", to: "g5"), icon: "arrow.up.right",
                     title: L("Doppelter Druck"),
                     text: L("Springer nach g5: Jetzt greifen Läufer und Springer f7 gemeinsam an."),
                     praise: L("Mila muss reagieren!"), reply: "d7d5"),
        TutorialStep(expect: .move(from: "e4", to: "d5"), icon: "burst.fill",
                     title: L("Schlag zu!"),
                     text: L("Mila sperrt deinen Läufer mit d5. Schlag den Bauern – Schlagen lädt extra Mana."),
                     praise: L("Treffer!"), reply: "f6d5"),
        // Verteidigung: Milas Dame sieht jetzt über e7 und f6 bis g5 – Schild rettet den Springer, ohne den Zug zu kosten.
        TutorialStep(expect: .card(.shield, target: "g5"), icon: "shield.fill",
                     title: L("Achtung – Angriff!"),
                     text: L("Milas Dame bedroht deinen Springer g5. Tippe auf Schild, dann auf g5."),
                     praise: L("Abgewehrt!"),
                     reward: QuestReward(icon: "shield.fill", text: L("Springer geschützt"), tint: .territory)),
        TutorialStep(expect: .move(from: "d1", to: "f3"), icon: "figure.walk",
                     title: L("Bonuszug!"),
                     text: L("Schild kostet keinen Zug – zieh gleich noch: Dame nach f3. Sie droht, auf f7 Matt zu setzen."),
                     praise: L("Verteidigt und angegriffen!"), reply: "c8e6"),
        // Ultimate: Meteor auf den Turm h8. Der Bauer h7 daneben ist danach ungeschützt und friert zwei Züge lang ein.
        TutorialStep(expect: .ultimate(target: "h8"), icon: "flame.fill",
                     title: L("Ultimate geladen!"),
                     text: L("Volle Leiste! Meteor vernichtet jede Figur außer König und Dame. Tippe auf Meteor, dann auf den Turm h8."),
                     praise: L("METEOR!"), reply: "c6d4", fillMana: true,
                     reward: QuestReward(icon: "flame.fill", text: L("Turm zerstört"), tint: .gold)),
        // Finale: Der Läufer e6 ist Milas einziger Verteidiger von f7. Frost ist eine Bonusaktion – danach folgt sofort das Matt.
        TutorialStep(expect: .card(.freeze, target: "e6"), icon: "snowflake",
                     title: L("Frost auf den Verteidiger"),
                     text: L("Nur Milas Läufer e6 deckt f7. Tippe auf Frost, dann auf e6 – eingefroren kann er nicht schlagen."),
                     praise: L("Eingefroren!"), fillMana: true,
                     reward: QuestReward(icon: "snowflake", text: L("Läufer eingefroren"), tint: .territory)),
        TutorialStep(expect: .move(from: "f3", to: "f7"), icon: "crown.fill",
                     title: L("Das Finale"),
                     text: L("Frost kostet keinen Zug. Dame schlägt f7, der Springer deckt sie – Schachmatt!"),
                     praise: L("SCHACHMATT!"))
    ] }
}

/// Belohnungs-Chip nach einer erfüllten Aufgabe.
struct QuestReward: Equatable, Hashable {
    enum Tint: Equatable, Hashable { case territory, mana, gold }
    let icon: String
    let text: String
    let tint: Tint

    var color: Color {
        switch tint {
        case .territory: return Theme.blueLight
        case .mana: return Theme.manaLight
        case .gold: return Theme.gold
        }
    }
}

/// Anzeige der aktuellen Aufgabe in der Aufgabenleiste.
struct CoachState: Equatable {
    let step: Int
    let total: Int
    let icon: String
    let title: String
    let text: String
    /// Aufgabe erfüllt – Jubel und Belohnungen, bis Mila geantwortet hat.
    var done = false
    var praise = ""
    var rewards: [QuestReward] = []
}

/// Aufgabenleiste der ersten Schlacht. Sie sitzt oben über dem Brett –
/// dort, wo sonst die Leiste des Gegners steht – und verdeckt nichts.
struct QuestBar: View {
    let coach: CoachState?
    let opponent: String
    let opponentThinking: Bool
    let nudge: Int
    let nudgeText: String?
    let onSkip: () -> Void

    @State var appear = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Theme.panelRaised, Theme.panel], startPoint: .topLeading, endPoint: .bottomTrailing))
            if let coach {
                QuestShimmer()
                    .id(coach.step)
                    .allowsHitTesting(false)
                content(coach)
                    .id(coach.step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderStyle, lineWidth: coach?.done == true ? 2.5 : 1.5)
        )
        .shadow(color: (coach?.done == true ? Theme.gold : Theme.blue).opacity(0.35), radius: coach?.done == true ? 14 : 8)
        .frame(height: 84)
        .modifier(ShakeEffect(amount: 9, animatableData: CGFloat(nudge)))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: coach)
        .animation(.linear(duration: 0.4), value: nudge)
        .offset(y: appear ? 0 : -24)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.15)) { appear = true }
        }
        .accessibilityElement(children: .combine)
    }

    private var borderStyle: AnyShapeStyle {
        if coach?.done == true { return AnyShapeStyle(Theme.gold) }
        return AnyShapeStyle(LinearGradient(colors: [Theme.blue, Theme.gold.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
    }

    private func content(_ c: CoachState) -> some View {
        HStack(spacing: 12) {
            QuestBadge(icon: c.icon, done: c.done,
                       progress: Double(c.step + (c.done ? 1 : 0)) / Double(max(1, c.total)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(c.done ? L("AUFGABE ERFÜLLT") : L("AUFGABE {0} VON {1}", c.step + 1, c.total))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.3)
                        .foregroundColor(Theme.gold)
                    Spacer(minLength: 4)
                    if c.step == 0 && !c.done {
                        Button(L("Überspringen"), action: onSkip)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                    } else {
                        OpponentPill(name: opponent, thinking: opponentThinking)
                    }
                }
                Text(c.done ? c.praise : c.title)
                    .font(.system(size: c.done ? 19 : 16, weight: .heavy, design: .rounded))
                    .foregroundColor(c.done ? Theme.gold : Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if c.done {
                    HStack(spacing: 6) {
                        ForEach(Array(c.rewards.enumerated()), id: \.element) { i, r in
                            RewardChip(reward: r, delay: 0.1 + Double(i) * 0.14)
                        }
                    }
                } else {
                    Text(nudgeText ?? c.text)
                        .font(.system(size: 13, weight: nudgeText == nil ? .medium : .bold))
                        .foregroundColor(nudgeText == nil ? Theme.textSecondary : Theme.gold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
    }
}

/// Runder Aufgaben-Orden: Fortschrittsring außen, Symbol innen. Beim Erfüllen ploppt ein Haken mit Funken.
struct QuestBadge: View {
    let icon: String
    let done: Bool
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Theme.panelHighlight, lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            Circle()
                .fill(done
                      ? LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom)
                      : LinearGradient(colors: [Theme.blueLight, Theme.blue], startPoint: .top, endPoint: .bottom))
                .padding(7)
            Image(systemName: done ? "checkmark" : icon)
                .font(.system(size: done ? 22 : 19, weight: .black))
                .foregroundColor(done ? Theme.navy : .white)
                .modifier(RoadBob(active: !done, amplitude: 2, speed: 4))
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .id(done)
            if done {
                SparkBurst()
            }
        }
        .frame(width: 58, height: 58)
        .scaleEffect(done ? 1.08 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: done)
    }
}

/// Kleine goldene Funken, die beim Erfüllen einer Aufgabe aus dem Orden sprühen.
struct SparkBurst: View {
    @State private var go = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                let angle = Double(i) / 10 * 2 * .pi
                Image(systemName: i % 2 == 0 ? "sparkle" : "circle.fill")
                    .font(.system(size: i % 2 == 0 ? 10 : 5, weight: .black))
                    .foregroundColor(i % 3 == 0 ? Theme.cream : Theme.gold)
                    .offset(x: cos(angle) * (go ? 40 : 10), y: sin(angle) * (go ? 40 : 10))
                    .opacity(go ? 0 : 1)
                    .scaleEffect(go ? 0.6 : 1.2)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.75)) { go = true }
        }
    }
}

/// Belohnung als kleine Pille, die nacheinander hereinspringt.
struct RewardChip: View {
    let reward: QuestReward
    let delay: Double
    @State private var shown = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: reward.icon)
                .font(.system(size: 10, weight: .black))
            Text(reward.text)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .lineLimit(1)
        }
        .foregroundColor(reward.color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(reward.color.opacity(0.16)))
        .overlay(Capsule().strokeBorder(reward.color.opacity(0.7), lineWidth: 1))
        .scaleEffect(shown ? 1 : 0.3)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55).delay(delay)) { shown = true }
        }
    }
}

/// Gegnerin im Tutorial – kompakt, mit Denkpunkten, wenn sie gleich antwortet.
struct OpponentPill: View {
    let name: String
    let thinking: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(Theme.red).frame(width: 7, height: 7)
            Text(name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            if thinking {
                ThinkingDots()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(Capsule().fill(Theme.panelHighlight))
        .animation(.easeOut(duration: 0.2), value: thinking)
    }
}

/// Ein Lichtstreifen, der bei jeder neuen Aufgabe einmal über die Leiste wischt.
struct QuestShimmer: View {
    @State private var x: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, Color.white.opacity(0.16), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.35)
                .rotationEffect(.degrees(18))
                .offset(x: x * geo.size.width * 1.4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).delay(0.2)) { x = 1 }
        }
    }
}

/// Abschluss der ersten Schlacht.
struct TutorialCompleteOverlay: View {
    let xp: Int
    let streakLit: Int?
    let onDone: () -> Void
    var onOpenChest: (() -> Void)? = nil
    @State var appear = false
    @State var shownXP = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ConfettiView(seed: 42).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 14) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .rotationEffect(.degrees(appear ? 0 : -20))
                    .scaleEffect(appear ? 1 : 0.3)
                Text(L("Erste Schlacht gewonnen!"))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(L("Du kennst jetzt Mana, Angriff, Verteidigung und Ultimates."))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.gold)
                    Text(L("Profi-Tipp: Blitz kostet 2 Mana und vernichtet einen gegnerischen Bauern, der in deine Hälfte vorgerückt ist – auch einen gedeckten. Ideal gegen Vormarsch und Sturmlauf."))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
                Text(L("+{0} XP", shownXP))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(Theme.manaLight)
                    .contentTransition(.numericText())
                if let streakLit {
                    FlameLitRow(streak: streakLit)
                }
                if let onOpenChest {
                    Button(action: onOpenChest) {
                        HStack(spacing: 8) {
                            ChestView(rarity: .silver, size: 34)
                            Text(L("Erste Truhe öffnen!"))
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 58, textColor: Theme.navy))
                    .padding(.top, 4)
                    Button(L("Ab in die Arena"), action: onDone)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                } else {
                    Button(L("Ab in die Arena!"), action: onDone)
                        .buttonStyle(ChunkyButtonStyle())
                        .padding(.top, 4)
                }
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.gold.opacity(0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 20)
            .scaleEffect(appear ? 1 : 0.85)
            .padding(24)
        }
        .onAppear {
            Feedback.play(.victory, .victory)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.4)) { shownXP = xp }
        }
    }
}

/// Animierter Startbildschirm nach dem System-Launchscreen.
struct SplashView: View {
    @State var phase = 0
    @State var progress: Double = 0

    /// Künstlicher Ladeverlauf in ungleichen Schritten – wirkt wie echtes Laden (Vorbereitung auf die Online-Version).
    static let duration: Double = 3.3
    private static let steps: [(Double, Double)] = [(0.25, 0.08), (0.7, 0.27), (1.15, 0.38), (1.6, 0.61), (2.2, 0.74), (2.6, 0.9), (3.05, 1.0)]

    private var status: String {
        switch progress {
        case ..<0.3: return L("Verbinde mit der Arena …")
        case ..<0.62: return L("Lade Karten und Decks …")
        case ..<0.95: return L("Poliere die Truhen …")
        default: return L("Bereit!")
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            // Glut hinter dem Logo – Orange und Rot wie im Logo (v0.9.27)
            RadialGradient(colors: [Color(hex: 0xE8641E).opacity(0.32), .clear], center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
            // Zwei Karten fächern hinter dem Logo auf – Gold und Rot wie die Karten im Logo
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0xF6C453), Color(hex: 0xD98A1F)], startPoint: .top, endPoint: .bottom))
                .frame(width: 110, height: 150)
                .rotationEffect(.degrees(phase >= 1 ? -18 : 0))
                .offset(x: phase >= 1 ? -46 : 0, y: phase >= 1 ? 6 : 0)
                .opacity(phase >= 1 ? 1 : 0)
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0xE5532D), Color(hex: 0xA3261B)], startPoint: .top, endPoint: .bottom))
                .frame(width: 110, height: 150)
                .rotationEffect(.degrees(phase >= 1 ? 18 : 0))
                .offset(x: phase >= 1 ? 46 : 0, y: phase >= 1 ? 6 : 0)
                .opacity(phase >= 1 ? 1 : 0)
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 31, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                .scaleEffect(phase >= 1 ? 1.06 : 1)
            Text(L("ROOK RAID"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(phase >= 2 ? 6 : 1)
                .foregroundColor(Theme.textPrimary)
                .opacity(phase >= 2 ? 1 : 0)
                .offset(y: 130)

            VStack(spacing: 10) {
                Spacer()
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: 0xE5532D), Theme.gold], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(10, geo.size.width * progress))
                            .shadow(color: Color(hex: 0xF08A2A).opacity(0.7), radius: 6)
                        Capsule()
                            .fill(LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 40)
                            .offset(x: max(0, geo.size.width * progress - 40))
                            .opacity(progress < 1 ? 1 : 0)
                    }
                }
                .frame(width: 220, height: 10)
                HStack(spacing: 6) {
                    Text(status)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                    Text("\(Int(progress * 100)) %")
                        .font(.system(size: 13, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundColor(Theme.gold)
                }
                .animation(nil, value: progress)
            }
            .padding(.bottom, 70)
            .opacity(phase >= 2 ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { phase = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.45)) { phase = 2 }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                Haptics.shared.play(.heavyCapture)
            }
            for (t, value) in SplashView.steps {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(t * 1_000_000_000))
                    withAnimation(.easeOut(duration: 0.35)) { progress = value }
                    if value >= 1 { Haptics.shared.play(.select) }
                }
            }
        }
        .accessibilityLabel(L("Rook Raid"))
    }
}

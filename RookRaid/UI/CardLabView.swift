import SwiftUI

// MARK: - Kartenschule (v0.9.26)

/// Pfeil auf dem Übungsbrett: verhinderter Schlagversuch (rot, durchgestrichen) oder Zugvorschlag (gold, gestrichelt).
struct LabArrow: Identifiable, Equatable {
    enum Kind { case blocked, hint }
    let id = UUID()
    let from: Square
    let to: Square
    let kind: Kind
}

/// Ablauf einer Übung: Karte antippen → Ziel wählen → Wirkung sehen → (Bonuszug) → Antwort von Schwarz → (Abschlusszug) → geschafft.
/// Alles läuft über die echte Spiel-Engine – was hier klappt, klappt genauso in der Partie.
@MainActor
final class CardLabModel: ObservableObject {
    enum Phase { case ready, targeting, bonusMove, opponent, finale, done }

    @Published private(set) var item: LabItem
    @Published private(set) var scenario: LabScenario
    @Published private(set) var state: GameState
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var message: String
    @Published private(set) var targets: Set<Square> = []
    @Published private(set) var suggested: Square?
    @Published private(set) var selected: Square?
    @Published private(set) var moveTargets: [Move] = []
    @Published private(set) var arrows: [LabArrow] = []
    @Published private(set) var effects: [BoardEffect] = []
    @Published private(set) var confetti: UInt64?
    @Published private(set) var mated = false
    @Published private(set) var shake = 0

    let items = LabItem.all
    /// Jeder Neustart erhöht den Zähler – noch laufende Schritte der alten Übung brechen dann ab.
    private var token = 0

    init(start: LabItem) {
        let sc = LabScenario.scenario(for: start)
        item = start
        scenario = sc
        state = sc.makeState() ?? GameState.initial(ultimates: [:])
        message = sc.mission
    }

    var index: Int { items.firstIndex(of: item) ?? 0 }
    var isLast: Bool { index == items.count - 1 }
    var mana: Int { state.mana[.white, default: 0] }
    var opponentMana: Int { state.mana[.black, default: 0] }
    var showsOpponentMana: Bool { scenario.opponentMana > 0 }
    var ultimateCost: Int {
        if case .ultimate(let u) = item { return u.cost }
        return GameState.ultimateCost
    }

    func load(_ next: LabItem) {
        item = next
        scenario = LabScenario.scenario(for: next)
        reset()
    }

    func next() {
        guard !isLast else { return }
        load(items[index + 1])
    }

    func reset() {
        token += 1
        state = scenario.makeState() ?? GameState.initial(ultimates: [:])
        phase = .ready
        message = scenario.mission
        targets = []
        suggested = nil
        selected = nil
        moveTargets = []
        arrows = []
        effects = []
        confetti = nil
        mated = false
    }

    // MARK: Karte

    private var needsTarget: Bool {
        switch item {
        case .card(let c): return c.targeting == .single
        case .ultimate(let u): return u.needsTarget
        }
    }

    func tapCard() {
        guard phase == .ready || phase == .targeting else { return }
        if phase == .targeting {
            // Noch einmal tippen: Auswahl aufheben
            phase = .ready
            targets = []
            suggested = nil
            message = scenario.mission
            Haptics.shared.play(.select)
            return
        }
        Haptics.shared.play(.select)
        guard needsTarget else { apply(nil); return }
        let list: [Square]
        switch item {
        case .card(let c): list = state.targets(for: c, player: .white)
        case .ultimate: list = state.ultimateTargets(.white)
        }
        targets = Set(list)
        suggested = scenario.target.flatMap { Square(name: $0) }.flatMap { targets.contains($0) ? $0 : nil }
        phase = .targeting
        switch item {
        case .card(let c): message = c.targetPrompt
        case .ultimate(let u): message = u.targetPrompt
        }
        if let s = suggested { message += " " + L("Tipp: {0}", s.name) }
    }

    private func apply(_ target: Square?) {
        let before = state
        withAnimation(.easeOut(duration: 0.25)) {
            switch item {
            case .card(let c): state.playCard(c, handIndex: 0, target: target)
            case .ultimate: state.useUltimate(target: target)
            }
        }
        targets = []
        suggested = nil
        showEffects(before: before, target: target)
        message = scenario.afterCard ?? message
        if item.keepsTurn && state.current == .white {
            phase = .bonusMove
            if let h = scenario.bonusHint, let m = state.move(fromUCI: h) {
                arrows = [LabArrow(from: m.from, to: m.to, kind: .hint)]
            }
        } else {
            runOpponent(delay: 1.4)
        }
    }

    /// Wirkung wie in der Partie: Blitz, Frost, Schild, Meteor, Funkeln …
    private func showEffects(before: GameState, target: Square?) {
        // Neue eigene Figuren (Verstärkung, Wiederkehr, Wiedergeburt, Krönung)
        let appeared = GameState.allSquares.filter { sq in
            guard let p = state[sq], p.color == .white else { return false }
            return before[sq] == nil || before[sq]?.type != p.type
        }
        switch item {
        case .card(let c):
            switch c {
            case .shield:
                if let target { add(.shield, target) }
                Feedback.play(.shield, .shield)
            case .bulwark:
                for (sq, p) in state.pieces(of: .white) where p.type == .pawn { add(.shield, sq) }
                Feedback.play(.shield, .shield)
            case .freeze:
                if let target { add(.frost, target, 1.1) }
                Feedback.play(.frost, .frost)
            case .lightning:
                if let target { add(.lightning, target, 0.8) }
                Feedback.play(.lightning, .lightning)
                shake += 1
            case .knighting, .bishopize:
                if let target { add(.promotion, target, 1.1) }
                Feedback.play(.summon, .summon)
            case .sprint:
                if let target { add(.smoke, target); add(.sparkle, target.offset(-2, 0)) }
                Feedback.play(.move, .move)
            case .retreat:
                if let target { add(.smoke, target); add(.sparkle, target) }
                Feedback.play(.move, .move)
            case .advance:
                for sq in appeared { add(.sparkle, sq) }
                Feedback.play(.move, .move)
            case .reinforce, .revive:
                for sq in appeared { add(.revive, sq, 1.0) }
                Feedback.play(.summon, .summon)
            case .swap:
                if let target { add(.smoke, target) }
                if let k = before.kingSquare(.white) { add(.smoke, k) }
                Feedback.play(.castle, .move)
            case .sacrifice:
                if let target { add(.smoke, target) }
                Feedback.play(.notify, .mana)
            case .focus, .drain:
                if let k = state.kingSquare(.white) { add(.sparkle, k) }
                if c == .drain, let k = state.kingSquare(.black) { add(.smoke, k) }
                Feedback.play(.notify, .mana)
            }
        case .ultimate(let u):
            switch u {
            case .meteor:
                if let target { add(.meteor, target, 1.2) }
                shake += 1
                Feedback.play(.lightning, .heavyCapture)
            case .iceAge:
                if let k = state.kingSquare(.black) { add(.iceWave, k, 1.2) }
                for (sq, p) in state.pieces(of: .black) where p.type != .king { add(.frost, sq, 1.1) }
                Feedback.play(.frost, .frost)
            case .fortress:
                for (sq, _) in state.pieces(of: .white) { add(.shield, sq) }
                Feedback.play(.shield, .shield)
            case .coronation:
                if let target { add(.promotion, target, 1.2) }
                Feedback.play(.summon, .summon)
            case .rebirth:
                for sq in appeared { add(.revive, sq, 1.1) }
                Feedback.play(.summon, .summon)
            }
        }
    }

    private func add(_ kind: EffectKind, _ sq: Square, _ duration: Double = 0.9) {
        let e = BoardEffect(kind: kind, square: sq, duration: duration)
        effects.append(e)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.3) * 1_000_000_000))
            self?.effects.removeAll { $0.id == e.id }
        }
    }

    // MARK: Züge

    func tap(_ sq: Square) {
        switch phase {
        case .targeting:
            if targets.contains(sq) {
                apply(sq)
            } else {
                Haptics.shared.play(.invalid)
            }
        case .bonusMove, .finale:
            if let from = selected, let m = moveTargets.first(where: { $0.to == sq }) {
                _ = from
                perform(m)
                return
            }
            if let p = state[sq], p.color == .white, !state.isBonusLocked(sq) {
                let moves = state.legalMoves(from: sq)
                if moves.isEmpty {
                    Haptics.shared.play(.invalid)
                    if state.isBonusLocked(sq) { message = L("Diese Figur bleibt in diesem Zug stehen.") }
                } else {
                    selected = sq
                    moveTargets = moves
                    Haptics.shared.play(.select)
                }
            } else {
                if state.isBonusLocked(sq) { message = L("Diese Figur bleibt in diesem Zug stehen.") }
                selected = nil
                moveTargets = []
            }
        case .ready:
            // Brett angetippt, bevor die Karte gespielt wurde: Karte zeigen
            Haptics.shared.play(.invalid)
            message = scenario.mission + " " + L("Tippe zuerst unten auf die Karte.")
        default:
            break
        }
    }

    private func perform(_ m: Move) {
        let capture = state[m.to] != nil
        withAnimation(.easeOut(duration: 0.22)) { state.makeMove(m) }
        selected = nil
        moveTargets = []
        arrows = []
        if capture { add(.capture, m.to) }
        Feedback.play(capture ? .capture : .move, capture ? .capture : .move)
        if phase == .finale {
            if case .checkmate = state.status() {
                mated = true
                if let k = state.kingSquare(.black) { add(.bigCapture, k, 1.0) }
                message = L("Schachmatt!")
                Feedback.play(.victory, .victory)
            }
            finish(after: mated ? 1.4 : 0.8)
        } else {
            runOpponent(delay: 0.6)
        }
    }

    /// Schwarz ist dran: zeigen, was die Karte verhindert, dann die Antwort ziehen.
    private func runOpponent(delay: Double) {
        phase = .opponent
        let my = token
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard self.token == my else { return }
            if !self.scenario.blocked.isEmpty, self.state.current == .black {
                // Nur Schlagversuche zeigen, deren Ziel noch dasteht (der Bonuszug kann die Figur weggezogen haben)
                self.arrows = self.scenario.blocked.compactMap { pair in
                    guard let f = Square(name: pair.0), let t = Square(name: pair.1),
                          self.state[f]?.color == .black, self.state[t]?.color == .white else { return nil }
                    return LabArrow(from: f, to: t, kind: .blocked)
                }
                if !self.arrows.isEmpty {
                    for a in self.arrows { self.add(.shield, a.to) }
                    if let text = self.scenario.blockedText { self.message = text }
                    Haptics.shared.play(.shield)
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard self.token == my else { return }
                    self.arrows = []
                }
            }
            if self.state.current == .black, let r = self.scenario.reply, let m = self.state.move(fromUCI: r),
               self.state.allLegalMoves(for: .black).contains(where: { $0.from == m.from && $0.to == m.to }) {
                withAnimation(.easeOut(duration: 0.25)) { self.state.makeMove(m) }
                Feedback.play(.move, .move)
                if let t = self.scenario.replyText { self.message = t }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                guard self.token == my else { return }
            }
            if self.state.current == .white, let f = self.scenario.finale, let m = self.state.move(fromUCI: f) {
                self.phase = .finale
                self.message = self.scenario.finaleText ?? L("Jetzt du!")
                self.arrows = [LabArrow(from: m.from, to: m.to, kind: .hint)]
            } else {
                self.finish(after: 0.4)
            }
        }
    }

    private func finish(after: Double) {
        let my = token
        phase = .opponent
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
            guard let self, self.token == my else { return }
            self.arrows = []
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { self.phase = .done }
            self.confetti = UInt64.random(in: 1...UInt64.max)
            let store = ProfileStore.shared
            if !store.profile.labDone.contains(self.item.key) {
                store.profile.labDone.append(self.item.key)
                Feedback.play(.rewardBig, .chestReveal)
            } else {
                Feedback.play(.reward, .select)
            }
        }
    }
}

// MARK: - Ansicht

struct CardLabView: View {
    @StateObject private var lab: CardLabModel
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    init(start: LabItem) {
        _lab = StateObject(wrappedValue: CardLabModel(start: start))
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 10) {
                topBar
                chipRow
                rockyBubble
                LabBoard(lab: lab)
                    .padding(.horizontal, 12)
                    .modifier(ShakeEffect(animatableData: CGFloat(lab.shake)))
                    .animation(.linear(duration: 0.35), value: lab.shake)
                bottomBar
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            if lab.phase == .done { donePanel }
            if let c = lab.confetti {
                ConfettiView(seed: c)
                    .id(c)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [accent.opacity(0.35), .clear], center: .top, startRadius: 10, endRadius: 460)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: lab.item)
    }

    private var accent: Color {
        switch lab.item {
        case .card(let c): return Color(hex: c.role.colorHex)
        case .ultimate: return CardStyle.ultimate
        }
    }

    // MARK: Kopf

    private var topBar: some View {
        let done = lab.items.filter { store.profile.labDone.contains($0.key) }.count
        return HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.panelRaised))
            }
            .accessibilityLabel(L("Schließen"))
            VStack(alignment: .leading, spacing: 0) {
                Text(L("KARTENSCHULE"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(Theme.gold)
                Text(lab.item.name)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill").foregroundColor(Theme.gold)
                Text("\(done)/\(lab.items.count)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(Theme.panelRaised))
        }
        .padding(.horizontal, 16)
    }

    /// Alle Karten und Ultimates zum Springen – erledigte mit Haken.
    private var chipRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lab.items) { it in
                        let current = it == lab.item
                        let done = store.profile.labDone.contains(it.key)
                        Button {
                            guard !current else { return }
                            Haptics.shared.play(.select)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { lab.load(it) }
                        } label: {
                            CardArtThumb(art: it.art, width: current ? 38 : 30,
                                         border: current ? Theme.gold : (done ? Theme.green : CardStyle.border))
                                .saturation(done || current ? 1 : 0.55)
                                .overlay(alignment: .bottomTrailing) {
                                    if done {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Theme.green)
                                            .background(Circle().fill(Theme.background))
                                            .offset(x: 4, y: 4)
                                    }
                                }
                                .shadow(color: current ? Theme.gold.opacity(0.7) : .clear, radius: 6)
                        }
                        .buttonStyle(PressScaleStyle())
                        .id(it.id)
                        .accessibilityLabel(it.name + (done ? L(", geschafft") : ""))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .onAppear { proxy.scrollTo(lab.item.id, anchor: .center) }
            .onChange(of: lab.item) { it in
                withAnimation { proxy.scrollTo(it.id, anchor: .center) }
            }
        }
        .frame(height: 64)
    }

    /// Rocky erklärt, was gerade zu tun ist.
    private var rockyBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 2))
                .modifier(Jiggle(active: lab.phase == .ready || lab.phase == .finale, amplitude: 5, period: 1.6))
            Text(lab.message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(accent.opacity(0.45), lineWidth: 1))
                .id(lab.message)
                .transition(.asymmetric(insertion: .scale(scale: 0.92, anchor: .leading).combined(with: .opacity), removal: .opacity))
        }
        .frame(minHeight: 64, alignment: .top)
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: lab.message)
    }

    // MARK: Karte und Mana

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { lab.tapCard() } label: {
                Group {
                    switch lab.item {
                    case .card(let c):
                        CardView(card: c, isPlayable: lab.phase == .ready || lab.phase == .targeting,
                                 isSelected: lab.phase == .targeting)
                    case .ultimate(let u):
                        UltimateCard(ultimate: u, mana: max(lab.mana, lab.phase == .ready || lab.phase == .targeting ? u.cost : 0),
                                     usable: lab.phase == .ready || lab.phase == .targeting, isSelected: lab.phase == .targeting)
                    }
                }
                .frame(width: 84)
                .opacity(lab.phase == .ready || lab.phase == .targeting ? 1 : 0.45)
                .modifier(TutorialSpotlight(active: lab.phase == .ready))
            }
            .buttonStyle(.plain)
            .disabled(!(lab.phase == .ready || lab.phase == .targeting))
            .accessibilityLabel(L("{0} spielen", lab.item.name))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    tag(lab.item.keepsTurn ? L("Bonusaktion") : L("Ersetzt deinen Zug"),
                        icon: lab.item.keepsTurn ? "plus.circle.fill" : "arrow.triangle.swap",
                        color: lab.item.keepsTurn ? Theme.green : Theme.blueLight)
                    tag(L("{0} Mana", lab.item.cost), icon: "drop.fill", color: Theme.manaLight)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Dein Mana"))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textMuted)
                    ManaBar(mana: lab.mana, income: 0, floats: [], ultimateCost: lab.ultimateCost)
                        .animation(.easeOut(duration: 0.4), value: lab.mana)
                }
                if lab.showsOpponentMana {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill").font(.system(size: 10, weight: .bold))
                        Text(L("Schwarz: {0} Mana", lab.opponentMana))
                            .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
                    }
                    .foregroundColor(Theme.redLight)
                    .animation(.easeOut(duration: 0.4), value: lab.opponentMana)
                }
                Button {
                    Haptics.shared.play(.select)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { lab.reset() }
                } label: {
                    Label(L("Nochmal"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func tag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().strokeBorder(color.opacity(0.4), lineWidth: 1))
    }

    // MARK: Geschafft

    private var donePanel: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    CardArtThumb(art: lab.item.art, width: 44, border: Theme.gold)
                        .modifier(RoadBob(active: true, amplitude: 2, speed: 3))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lab.mated ? L("Matt! {0} gemeistert", lab.item.name) : L("{0} gemeistert!", lab.item.name))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Image(systemName: "star.fill").font(.system(size: 12, weight: .bold)).foregroundColor(Theme.gold)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(lab.scenario.lessons.enumerated()), id: \.offset) { i, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: ["bolt.fill", "arrow.triangle.branch", "lightbulb.fill"][min(i, 2)])
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(accent)
                                .frame(width: 18)
                            Text(line)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button(L("Nochmal")) {
                        Haptics.shared.play(.select)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { lab.reset() }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 48))
                    if lab.isLast {
                        Button(L("Fertig")) { dismiss() }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 48, textColor: Theme.navy))
                    } else {
                        Button(L("Nächste Karte")) {
                            Haptics.shared.play(.cardWhoosh)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { lab.next() }
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 48, textColor: Theme.navy))
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 20, y: -4)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Übungsbrett

struct LabBoard: View {
    @ObservedObject var lab: CardLabModel
    @ObservedObject private var store = ProfileStore.shared

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let s = side / 8
            let colors = BoardColors.forTheme(store.profile.settings.boardTheme)
            ZStack(alignment: .topLeading) {
                ForEach(GameState.allSquares, id: \.self) { sq in
                    ZStack {
                        Rectangle().fill(sq.isLight ? colors.light : colors.dark)
                        if lab.selected == sq || lab.state.lastMove.map({ $0.from == sq || $0.to == sq }) == true {
                            Rectangle().fill(Color(hex: 0xF6D65A).opacity(0.45))
                        }
                    }
                    .frame(width: s, height: s)
                    .position(point(sq, s))
                }
                // Gültige Ziele der Karte, das empfohlene golden und pulsierend
                ForEach(Array(lab.targets), id: \.self) { sq in
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(sq == lab.suggested ? Theme.gold : Color.white.opacity(0.9), lineWidth: max(2, s * (sq == lab.suggested ? 0.09 : 0.06)))
                        .frame(width: s, height: s)
                        .modifier(PulseGlow(color: Theme.gold, active: sq == lab.suggested))
                        .position(point(sq, s))
                }
                pieces(s)
                ForEach(Array(lab.moveTargets.enumerated()), id: \.offset) { _, m in
                    Group {
                        if lab.state[m.to] != nil {
                            Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: s * 0.09)
                        } else {
                            Circle().fill(Color.black.opacity(0.25)).frame(width: s * 0.3, height: s * 0.3)
                        }
                    }
                    .frame(width: s, height: s)
                    .position(point(m.to, s))
                }
                ForEach(lab.arrows) { a in
                    ArrowShape(from: point(a.from, s), to: point(a.to, s), head: s * 0.32)
                        .stroke(a.kind == .blocked ? Theme.red : Theme.gold,
                                style: StrokeStyle(lineWidth: s * 0.11, lineCap: .round, lineJoin: .round,
                                                   dash: a.kind == .hint ? [s * 0.18, s * 0.14] : []))
                        .opacity(0.9)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                    if a.kind == .blocked {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: s * 0.5, weight: .black))
                            .foregroundStyle(.white, Theme.red)
                            .position(x: (point(a.from, s).x + point(a.to, s).x) / 2, y: (point(a.from, s).y + point(a.to, s).y) / 2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                ForEach(lab.effects) { e in
                    EffectView(effect: e, squareSize: s, distanceFromTop: point(e.square, s).y)
                        .position(point(e.square, s))
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.navy, lineWidth: 3))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { v in
                        if let sq = square(at: v.location, s) { lab.tap(sq) }
                    }
            )
            .animation(.easeOut(duration: 0.25), value: lab.arrows)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 380)
    }

    private func pieces(_ s: CGFloat) -> some View {
        let items: [PieceItem] = GameState.allSquares.compactMap { sq in
            guard let p = lab.state[sq] else { return nil }
            return PieceItem(id: p.id, square: sq, piece: p)
        }
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                PieceSprite(piece: item.piece, ply: lab.state.ply, size: s,
                            locked: lab.state.isBonusLocked(item.square),
                            skin: item.piece.color == .white ? store.activeSkin : nil)
                    .frame(width: s, height: s)
                    .position(point(item.square, s))
                    .animation(.easeOut(duration: 0.25), value: item.square)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }

    private func point(_ sq: Square, _ s: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(sq.col) + 0.5) * s, y: (CGFloat(sq.row) + 0.5) * s)
    }

    private func square(at p: CGPoint, _ s: CGFloat) -> Square? {
        guard p.x >= 0, p.y >= 0 else { return nil }
        let c = Int(p.x / s), r = Int(p.y / s)
        guard (0..<8).contains(c), (0..<8).contains(r) else { return nil }
        return Square(row: r, col: c)
    }
}

/// Gerader Pfeil mit Spitze.
struct ArrowShape: Shape {
    let from: CGPoint
    let to: CGPoint
    let head: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let angle = atan2(to.y - from.y, to.x - from.x)
        // Etwas vor der Feldmitte enden, damit die Spitze die Figur nicht verdeckt
        let end = CGPoint(x: to.x - cos(angle) * head * 0.6, y: to.y - sin(angle) * head * 0.6)
        p.move(to: from)
        p.addLine(to: end)
        p.move(to: CGPoint(x: end.x - cos(angle - .pi / 6) * head, y: end.y - sin(angle - .pi / 6) * head))
        p.addLine(to: end)
        p.addLine(to: CGPoint(x: end.x - cos(angle + .pi / 6) * head, y: end.y - sin(angle + .pi / 6) * head))
        return p
    }
}

import SwiftUI

/// Interaktive Einführung vor der ersten Schlacht (wie `Intro.tsx` im Web). Fünf kurze Bildschirme:
/// 1 Rocky: Schach mit Superkräften · 2 Mana (spielt sich selbst vor) · 3 Karten (Blitz auf einen Bauern) ·
/// 4 Ultimate (Meteor) · 5 die erste Schlacht gegen Mila. Danach startet die geführte Tutorial-Partie.
struct IntroView: View {
    /// Wird beim Überspringen und nach dem letzten Bildschirm aufgerufen – startet die erste Schlacht.
    let onFinish: () -> Void

    @State private var step = 0
    @State private var done = false
    /// Zählt Tipps irgendwo auf dem Bildschirm (Rocky reagiert darauf).
    @State private var signal = 0
    /// Erster Start: erst die Begrüßung (wer bist du?), dann die fünf Bildschirme. „Tutorial wiederholen“ überspringt sie.
    @State private var welcome = !ProfileStore.shared.profile.tutorialSeen
    @State private var hello: WelcomeHello?

    private struct Step {
        let kicker, title, text: String
        var task: String? = nil
        /// Keine Aufgabe, aber „Weiter“ erst, wenn die Szene fertig ist (Rocky hat ausgeredet).
        var waits = false
        var praise: String? = nil
    }

    private static let steps: [Step] = [
        Step(kicker: "Willkommen", title: "Schach mit Superkräften",
             text: "Alles zieht wie im Schach, und wer den König mattsetzt, gewinnt. Dazu kommen Mana, Karten und eine Ultimate.",
             waits: true),
        Step(kicker: "Mana", title: "Jeder Zug lädt Mana",
             text: "Jeder eigene Zug bringt +1 Mana. Schlagen oder Schach geben +1 extra. Höchstens 10."),
        Step(kicker: "Karten", title: "Karten: deine Tricks",
             text: "Du hast 4 Karten auf der Hand. Karte antippen, dann das Ziel – das kostet Mana. Danach lädt die Karte ein paar Züge nach.",
             task: "Tippe auf Blitz, dann auf den schwarzen Bauern!", praise: "Zack! Bauer weg."),
        Step(kicker: "Ultimate", title: "Deine stärkste Waffe",
             text: "Mana lädt auch deine Ultimate auf. Ist sie voll, kannst du sie zünden: Der Meteor zerstört eine Figur – nur König und Dame nicht.",
             task: "Tippe auf den Meteor, dann auf eine schwarze Figur!", praise: "Volltreffer!"),
        Step(kicker: "Erste Schlacht", title: "Bereit für Mila?",
             text: "Setz Mila matt – dafür gibt es deine erste Truhe!"),
    ]

    private var isLast: Bool { step == Self.steps.count - 1 }

    var body: some View {
        if welcome {
            WelcomeView { h in
                withAnimation(.easeInOut(duration: 0.35)) {
                    hello = h
                    welcome = false
                }
            }
            .transition(.opacity)
        } else {
            stepsView
                .transition(.opacity)
        }
    }

    private var stepsView: some View {
        let s = Self.steps[step]
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x141C33), Theme.backgroundDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.blue.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 6)
                scene
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer(minLength: 6)
                card(s)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        // Tipp irgendwo: Rockys nächste Zeile oder – wenn der Schritt fertig ist – der nächste Schritt.
        // Knöpfe, Karten und Figuren behandeln ihre Tipps selbst; die Schlacht startet nur über den Knopf.
        .contentShape(Rectangle())
        .onTapGesture {
            if !done {
                if Self.steps[step].waits { signal += 1 }
            } else if !isLast {
                next()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.steps.count, id: \.self) { k in
                Capsule()
                    .fill(k < step ? Theme.gold : k == step ? Theme.gold.opacity(0.55) : Color.white.opacity(0.12))
                    .frame(height: 5)
            }
            Button(L("Überspringen")) { onFinish() }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(Theme.panelRaised))
                .padding(.leading, 6)
        }
        .padding(.top, 10)
    }

    @ViewBuilder private var scene: some View {
        let onDone = { complete() }
        switch step {
        case 0: IntroRockyScene(onDone: onDone, signal: signal, hello: hello)
        case 1: IntroManaScene()
        case 2: IntroCardsScene(done: done, onDone: onDone)
        case 3: IntroMeteorScene(done: done, onDone: onDone)
        default: IntroBattleScene()
        }
    }

    private func card(_ s: Step) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(L(s.kicker).uppercased()) · \(step + 1)/\(Self.steps.count)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(Theme.gold)
            Text(L(s.title))
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L(s.text))
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if done {
                if let praise = s.praise {
                    Label(L(praise), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: 0x6FCF7A))
                        .transition(.scale.combined(with: .opacity))
                }
                Button(action: next) {
                    HStack(spacing: 8) {
                        if isLast { Image(systemName: "bolt.fill") }
                        Text(L(isLast ? "Erste Schlacht starten" : "Weiter"))
                        if !isLast { Image(systemName: "chevron.right").font(.system(size: 15, weight: .black)) }
                    }
                }
                .buttonStyle(isLast ? ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, textColor: Theme.navy)
                                    : ChunkyButtonStyle())
                .modifier(PulseGlow(color: Theme.gold, active: isLast))
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let task = s.task {
                Label(L(task), systemImage: "hand.tap.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.gold)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.1)))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.gold.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
        }
        .padding(18)
        .frame(maxWidth: 560, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: done)
    }

    private func complete() {
        guard !done else { return }
        Feedback.play(.reward, .victory)
        done = true
    }

    private func next() {
        Feedback.play(.select, .select)
        if isLast { onFinish(); return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            step += 1
            done = Self.steps[step].task == nil && !Self.steps[step].waits
        }
    }
}

// MARK: - Bausteine

private let introSize = 5

private struct IntroSquare: Hashable {
    let r: Int
    let c: Int
}

/// 5×5-Brett in den Farben des gewählten Bretts, leicht gekippt. `content` bekommt die Kantenlänge eines Feldes.
private struct IntroBoard<Content: View>: View {
    var maxSide: CGFloat = 320
    @ViewBuilder let content: (CGFloat) -> Content

    var body: some View {
        let colors = BoardColors.forTheme(ProfileStore.shared.profile.settings.boardTheme)
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(introSize)
            ZStack(alignment: .topLeading) {
                ForEach(0..<(introSize * introSize), id: \.self) { k in
                    let r = k / introSize, c = k % introSize
                    Rectangle()
                        .fill((r + c) % 2 == 1 ? colors.dark : colors.light)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
                }
                content(cell)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.black.opacity(0.35), lineWidth: 3))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .rotationEffect(.degrees(-3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: maxSide)
    }
}

/// Figur auf dem Mini-Brett; Züge gleiten mit einer Feder-Animation.
private struct IntroPiece: View {
    let type: PieceType
    let color: PlayerColor
    let at: IntroSquare
    let cell: CGFloat
    /// Roter Zielring
    var target = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        PieceImage(type: type, color: color)
            .frame(width: cell * 0.82, height: cell * 0.82)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            .frame(width: cell, height: cell)
            .modifier(TargetRing(active: target))
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .allowsHitTesting(onTap != nil)
            .position(x: (CGFloat(at.c) + 0.5) * cell, y: (CGFloat(at.r) + 0.5) * cell)
    }
}

/// Pulsierender roter Ring: „dieses Ziel antippen“.
private struct TargetRing: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.overlay {
            if active {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                    let p = (sin(tl.date.timeIntervalSinceReferenceDate * 5) + 1) / 2
                    Circle()
                        .strokeBorder(Theme.redLight, lineWidth: 3)
                        .scaleEffect(0.86 + 0.1 * p)
                        .opacity(0.6 + 0.4 * p)
                        .shadow(color: Theme.red, radius: 6)
                }
                .allowsHitTesting(false)
            }
        }
    }
}

/// Mana-Leiste (10 Felder).
private struct IntroManaMeter: View {
    let mana: Int
    /// Schwebende Gutschrift („+2“, „−8“); die id startet die Animation neu.
    var pop: (id: Int, text: String)? = nil

    var body: some View {
        let maxMana = GameState.maxMana
        HStack(spacing: 8) {
            ManaDrop(text: "\(mana)", size: 28)
            HStack(spacing: 4) {
                ForEach(0..<maxMana, id: \.self) { k in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(k < mana ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x8FB6FF), Theme.blue], startPoint: .top, endPoint: .bottom))
                                       : AnyShapeStyle(Color.white.opacity(0.07)))
                        .shadow(color: k < mana ? Theme.blue.opacity(0.7) : .clear, radius: 5)
                        .frame(height: 26)
                }
            }
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x0B1020)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            .overlay(alignment: .topLeading) {
                if let pop {
                    GeometryReader { g in
                        Text(pop.text)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: 0x8FB6FF))
                            .shadow(color: .black, radius: 0, y: 2)
                            .fixedSize()
                            .modifier(FloatUp())
                            .position(x: max(16, g.size.width * CGFloat(mana) / CGFloat(maxMana)), y: -6)
                    }
                    .id(pop.id)
                    .allowsHitTesting(false)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: mana)
        }
        .frame(maxWidth: 340)
    }
}

/// Text steigt auf und verblasst.
private struct FloatUp: ViewModifier {
    @State private var go = false
    func body(content: Content) -> some View {
        content
            .offset(y: go ? -22 : 6)
            .opacity(go ? 0 : 1)
            .scaleEffect(go ? 1 : 0.7)
            .onAppear { withAnimation(.easeOut(duration: 1.0)) { go = true } }
    }
}

/// Rocky mit Sprechblase – groß (Begrüßung, Blase darunter) oder klein (Blase daneben).
private struct RockyTalk: View {
    let text: String
    var big = false
    var bounce = 0
    /// Schreibmaschine: nur die ersten Zeichen zeigen (der volle Text hält die Größe der Blase fest).
    var typed: Int? = nil
    /// Punkte unter dem Text: Zeile `line + 1` von `lines`.
    var lines = 0
    var line = 0
    /// Hüpfender Pfeil: „tippen für mehr“
    var more = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        let font = Font.system(size: big ? 16 : 15, weight: .heavy, design: .rounded)
        let align: TextAlignment = big ? .center : .leading
        let bubble = VStack(spacing: 8) {
            ZStack(alignment: big ? .top : .topLeading) {
                Text(text).font(font).multilineTextAlignment(align).opacity(0)
                Text(typed.map { String(text.prefix($0)) } ?? text).font(font).multilineTextAlignment(align)
            }
            .foregroundColor(Color(hex: 0x1A2238))
            .fixedSize(horizontal: false, vertical: true)
            if lines > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<lines, id: \.self) { k in
                        Circle().fill(Color(hex: 0x1A2238).opacity(k <= line ? 0.65 : 0.2)).frame(width: 6, height: 6)
                    }
                    if more {
                        MoreArrow().padding(.leading, 4)
                    }
                }
            }
        }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: big ? 360 : .infinity, alignment: big ? .center : .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cream))
            .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
            .id(text)
            .transition(.scale(scale: 0.85, anchor: big ? .top : .bottomLeading).combined(with: .opacity))
        let face = RockyAvatar(size: big ? 140 : 84, bounce: bounce, excited: big)
            .accessibilityHidden(true)
        Group {
            if big {
                VStack(spacing: 14) { face; bubble }
            } else {
                HStack(alignment: .bottom, spacing: 10) { face; bubble }
                    .frame(maxWidth: 440)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        // Ohne eigenen Tipp geht er an den Bildschirm dahinter (Tipp irgendwo = weiter).
        .allowsHitTesting(onTap != nil)
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }
}

/// Kleiner hüpfender Pfeil in Rockys Blase: Ein Tipp zeigt die nächste Zeile.
private struct MoreArrow: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let p = (sin(tl.date.timeIntervalSinceReferenceDate * 6) + 1) / 2
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.blue)
                .offset(x: 3 * p)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - 1 · Rocky

/// Rocky stellt sich vor: Zeile für Zeile wie getippt. Ein Tipp schreibt die Zeile fertig oder zeigt die nächste;
/// „Weiter“ erscheint erst nach der letzten Zeile.
private struct IntroRockyScene: View {
    let onDone: () -> Void
    /// Tipps irgendwo auf dem Bildschirm
    let signal: Int
    /// Antworten aus der Begrüßung: Rocky spricht den Spieler mit Namen an und geht auf die Schach-Frage ein.
    let hello: WelcomeHello?
    @State private var line = 0
    @State private var chars = 0
    @State private var lines: [String]

    init(onDone: @escaping () -> Void, signal: Int, hello: WelcomeHello? = nil) {
        self.onDone = onDone
        self.signal = signal
        self.hello = hello
        _lines = State(initialValue: Self.makeLines(hello))
    }
    private static let baseLines = [
        "Hi, ich bin Rocky! Ein Turm. Ich kann nur geradeaus – um die Ecke denken überlasse ich den Springern.",
        "Normales Schach? Das ist mir zu langweilig. Hier gibt's Superkräfte! Der König hat sich beschwert – aber auf den hört eh keiner.",
        "Du sammelst Mana, spielst Karten und lässt Meteore regnen. Die Bauern hassen diesen Trick!",
    ]

    /// Wie `rockyLines` in Intro.tsx
    private static let levelLines: [ChessLevel: String] = [
        .new: "Neu im Schach? Kein Problem – in der ersten Schlacht zeige ich dir jeden Zug.",
        .rules: "Du kennst die Regeln? Super – dann zeige ich dir nur die Superkräfte.",
        .pro: "Ein Profi! Dann pass gut auf – hier wird dich einiges überraschen.",
    ]

    private static func makeLines(_ hello: WelcomeHello?) -> [String] {
        var lines = baseLines.map { L($0) }
        let name = ProfileStore.shared.profile.name
        if hello?.named == true, !WelcomeView.isDefaultName(name) {
            lines[0] = L("Hi {0}, ich bin Rocky! Ein Turm. Ich kann nur geradeaus – um die Ecke denken überlasse ich den Springern.", name)
        }
        if let level = hello?.level, let extra = levelLines[level] { lines.insert(L(extra), at: 1) }
        return lines
    }

    private var text: String { line < lines.count ? lines[line] : "" }
    private var isLast: Bool { line == lines.count - 1 }

    var body: some View {
        VStack(spacing: 18) {
            RockyTalk(text: text, big: true, bounce: line, typed: chars, lines: lines.count, line: line, more: chars >= text.count && !isLast)
            HStack(spacing: 8) {
                if line >= lines.count - 2 {
                    power(PieceImage(type: .king, color: .white).frame(width: 26, height: 26), L("Schach"))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                if isLast {
                    Text("+").font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(Theme.gold)
                    power(Image(systemName: "drop.fill").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.manaLight), L("Mana"))
                    power(Image(systemName: "square.stack.fill").font(.system(size: 22, weight: .bold)).foregroundColor(Color(hex: 0xC084FC)), L("Karten"))
                    power(Image(systemName: "flame.fill").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.gold), L("Ultimate"))
                }
            }
            .frame(minHeight: 72)
        }
        .onChange(of: signal) { _ in tap() }
        .task(id: line) {
            // Zeile tippen; weiter geht es erst mit einem Tipp. Nach der letzten Zeile ist „Weiter“ frei.
            let total = text.count
            while chars < total {
                try? await Task.sleep(nanoseconds: 28_000_000)
                if Task.isCancelled { return }
                chars = min(total, chars + 2)
            }
            if isLast { onDone() }
        }
    }

    private func tap() {
        Haptics.shared.play(.select)
        if chars < text.count { chars = text.count } else if !isLast { advance() }
    }

    private func advance() {
        SoundPlayer.shared.play(.select)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            chars = 0
            line += 1
        }
    }

    private func power<Icon: View>(_ icon: Icon, _ label: String) -> some View {
        VStack(spacing: 5) {
            icon.frame(height: 26)
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 68)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

// MARK: - 2 · Mana (spielt sich selbst vor)

private struct IntroManaScene: View {
    private struct Frame {
        let mana: Int
        let label: String
        let text: String
        let knight: IntroSquare
        let rook: IntroSquare
        let pawn: Bool
    }

    private static let frames: [Frame] = [
        Frame(mana: 0, label: "", text: "", knight: .init(r: 4, c: 1), rook: .init(r: 4, c: 4), pawn: true),
        Frame(mana: 1, label: "+1", text: "Zug: +1 Mana", knight: .init(r: 2, c: 2), rook: .init(r: 4, c: 4), pawn: true),
        Frame(mana: 3, label: "+2", text: "Schlagen: +1 extra", knight: .init(r: 1, c: 0), rook: .init(r: 4, c: 4), pawn: false),
        Frame(mana: 5, label: "+2", text: "Schach: +1 extra", knight: .init(r: 1, c: 0), rook: .init(r: 0, c: 4), pawn: false),
    ]

    @State private var k = 0

    var body: some View {
        let f = Self.frames[k]
        VStack(spacing: 14) {
            IntroBoard { cell in
                IntroPiece(type: .king, color: .black, at: .init(r: 0, c: 1), cell: cell)
                    .shadow(color: k == 3 ? Theme.red : .clear, radius: 10)
                    .modifier(ShakeEffect(amount: 4, shakes: 3, animatableData: k == 3 ? 1 : 0))
                if f.pawn { IntroPiece(type: .pawn, color: .black, at: .init(r: 1, c: 0), cell: cell).transition(.scale(scale: 0.2).combined(with: .opacity)) }
                IntroPiece(type: .knight, color: .white, at: f.knight, cell: cell)
                IntroPiece(type: .rook, color: .white, at: f.rook, cell: cell)
                IntroPiece(type: .king, color: .white, at: .init(r: 4, c: 2), cell: cell)
            }
            IntroManaMeter(mana: f.mana, pop: f.label.isEmpty ? nil : (k, f.label))
            Text(f.text.isEmpty ? " " : L(f.text))
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: 0x8FB6FF))
                .id(k)
                .transition(.scale.combined(with: .opacity))
        }
        .task {
            while !Task.isCancelled {
                let wait: Double = k == Self.frames.count - 1 ? 2.6 : k == 0 ? 0.9 : 1.6
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                if Task.isCancelled { return }
                let n = (k + 1) % Self.frames.count
                withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) { k = n }
                if n > 0 { Feedback.play(n == 2 ? .capture : n == 3 ? .check : .move, .select) }
            }
        }
    }
}

// MARK: - 3 · Karten (Blitz ausspielen)

private struct IntroCardsScene: View {
    let done: Bool
    let onDone: () -> Void
    private let hand: [CardType] = [.lightning, .shield, .sprint, .freeze]
    @State private var mana = 5
    @State private var armed = false
    @State private var peek: CardType?
    @State private var hit = false

    private var shown: CardType? { peek ?? (armed ? .lightning : nil) }
    private let pawnSquare = IntroSquare(r: 3, c: 2)

    var body: some View {
        VStack(spacing: 10) {
            IntroBoard(maxSide: 210) { cell in
                IntroPiece(type: .king, color: .black, at: .init(r: 0, c: 2), cell: cell)
                IntroPiece(type: .knight, color: .black, at: .init(r: 1, c: 3), cell: cell)
                if !hit {
                    IntroPiece(type: .pawn, color: .black, at: pawnSquare, cell: cell, target: armed, onTap: strike)
                        .transition(.scale(scale: 0.1).combined(with: .opacity))
                } else {
                    LightningStrike(seed: 11, height: cell * 3.5, squareSize: cell)
                        .frame(width: cell * 1.2, height: cell * 3.5)
                        .position(x: (CGFloat(pawnSquare.c) + 0.5) * cell, y: (CGFloat(pawnSquare.r) + 0.5) * cell - cell * 1.25)
                    Shockwave(color: Color(hex: 0xFFEB3B), maxScale: 2.2, lineWidth: 5, duration: 0.6)
                        .frame(width: cell, height: cell)
                        .position(x: (CGFloat(pawnSquare.c) + 0.5) * cell, y: (CGFloat(pawnSquare.r) + 0.5) * cell)
                }
                IntroPiece(type: .king, color: .white, at: .init(r: 4, c: 3), cell: cell)
                IntroPiece(type: .pawn, color: .white, at: .init(r: 4, c: 1), cell: cell)
            }
            IntroManaMeter(mana: mana, pop: hit ? (1, "−\(CardType.lightning.cost)") : nil)
            HStack(spacing: 8) {
                ForEach(hand, id: \.self) { c in
                    CardView(card: c, isSelected: shown == c)
                        .modifier(TutorialSpotlight(active: !armed && !hit && c == .lightning))
                        .onTapGesture { tap(c) }
                }
            }
            .frame(maxWidth: 330)
            .padding(.top, 34)
            Group {
                if let c = shown {
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Text(c.name).foregroundColor(Theme.textPrimary)
                            Text("· \(c.cost) \(L("Mana"))").foregroundColor(Color(hex: 0x8FB6FF))
                        }
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Text(c.shortText).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.textSecondary)
                    }
                } else {
                    Text(L("Tippe eine Karte an, um zu sehen, was sie kann."))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
            }
            .id(shown)
            .transition(.opacity)
            .frame(maxWidth: 360, minHeight: 40)
        }
    }

    private func tap(_ c: CardType) {
        guard !done, !hit else { return }
        Feedback.play(.cardFlip, .select)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            if c == .lightning { armed = true; peek = nil } else { peek = c; armed = false }
        }
    }

    private func strike() {
        guard armed, !hit else { return }
        Feedback.play(.lightning, .lightning)
        withAnimation(.easeOut(duration: 0.4)) {
            hit = true
            mana -= CardType.lightning.cost
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            onDone()
        }
    }
}

// MARK: - 4 · Ultimate (Meteor)

private struct IntroMeteorScene: View {
    let done: Bool
    let onDone: () -> Void
    @State private var armed = false
    @State private var hit: IntroSquare?
    @State private var nope = 0

    private let enemies: [(PieceType, IntroSquare)] = [
        (.king, .init(r: 0, c: 2)), (.queen, .init(r: 0, c: 3)), (.rook, .init(r: 1, c: 1)),
        (.knight, .init(r: 1, c: 3)), (.bishop, .init(r: 0, c: 1)),
    ]

    var body: some View {
        let ult = Ultimate.meteor.cost
        VStack(spacing: 10) {
            IntroBoard(maxSide: 250) { cell in
                IntroPiece(type: .king, color: .white, at: .init(r: 4, c: 2), cell: cell)
                IntroPiece(type: .rook, color: .white, at: .init(r: 4, c: 0), cell: cell)
                ForEach(enemies, id: \.0) { type, sq in
                    if hit != sq {
                        IntroPiece(type: type, color: .black, at: sq, cell: cell,
                                   target: armed && hit == nil && type != .king && type != .queen,
                                   onTap: { target(type, sq) })
                            .transition(.scale(scale: 0.1).combined(with: .opacity))
                    }
                }
                if let h = hit {
                    ZStack {
                        MeteorFall(height: cell * 4, size: cell)
                        Shockwave(color: Color(hex: 0xFF8A3D), maxScale: 2.6, lineWidth: 6, duration: 0.8)
                            .frame(width: cell, height: cell)
                        Circle()
                            .fill(RadialGradient(colors: [.white, Color(hex: 0xFFCA28), Color(hex: 0xFF6F00).opacity(0)],
                                                 center: .center, startRadius: 1, endRadius: cell * 0.7))
                            .frame(width: cell * 1.4, height: cell * 1.4)
                            .modifier(PopFade(duration: 0.7))
                    }
                    .frame(width: cell, height: cell * 4)
                    .position(x: (CGFloat(h.c) + 0.5) * cell, y: (CGFloat(h.r) + 0.5) * cell)
                    .allowsHitTesting(false)
                }
            }
            .modifier(ShakeEffect(amount: 6, shakes: 3, animatableData: hit == nil ? 0 : 1))
            IntroManaMeter(mana: hit == nil ? ult : 0, pop: hit == nil ? nil : (2, "−\(ult)"))
            Text(L("König und Dame sind geschützt!"))
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(Theme.redLight)
                .opacity(nope > 0 && hit == nil ? 1 : 0)
                .modifier(ShakeEffect(amount: 5, shakes: 2, animatableData: CGFloat(nope)))
            UltimateCard(ultimate: .meteor, mana: ult, usable: !armed, isSelected: armed)
                .frame(width: 64)
                .modifier(TutorialSpotlight(active: !armed, cornerRadius: 10))
                .padding(.top, armed ? 0 : 30)
                .onTapGesture {
                    guard !done, !armed else { return }
                    Feedback.play(.summon, .summon)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { armed = true }
                }
        }
    }

    private func target(_ type: PieceType, _ sq: IntroSquare) {
        guard !done, armed, hit == nil else { return }
        if type == .king || type == .queen {
            Feedback.play(.notify, .invalid)
            withAnimation(.linear(duration: 0.4)) { nope += 1 }
            return
        }
        Feedback.play(.lightning, .heavyCapture)
        withAnimation(.easeOut(duration: 0.5)) { hit = sq }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            onDone()
        }
    }
}

// MARK: - 5 · Erste Schlacht

private struct IntroBattleScene: View {
    @ObservedObject private var store = ProfileStore.shared
    @State private var shown = false

    var body: some View {
        VStack(spacing: 26) {
            HStack(spacing: 18) {
                VStack(spacing: 6) {
                    PlayerAvatar(size: 84)
                    Text(store.profile.name)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text(" ").font(.system(size: 12))
                }
                .offset(x: shown ? 0 : -120)
                Text("VS")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .italic()
                    .foregroundColor(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.6), radius: 12)
                    .shadow(color: .black, radius: 0, x: 3, y: 3)
                    .scaleEffect(shown ? 1 : 2.4)
                    .opacity(shown ? 1 : 0)
                VStack(spacing: 6) {
                    ZStack {
                        LightRays(color: Theme.mana, count: 12)
                            .frame(width: 170, height: 170)
                            .opacity(0.6)
                        BotAvatar(level: .medium, size: 84)
                    }
                    .frame(width: 84, height: 84)
                    Text(L("Mila"))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(L("die Magierin"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                }
                .offset(x: shown ? 0 : 120)
            }
            .opacity(shown ? 1 : 0)
            RockyTalk(text: L("Keine Sorge: Ich bin die ganze Zeit dabei und zeige dir jeden Zug."))
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) { shown = true }
        }
    }
}

import SwiftUI

// MARK: - Truhe (gezeichnet)

/// Kleiner SVG-Pfad-Leser für die Truhen-Grafik (M, L, H, V, Q, C, Z – absolute Koordinaten).
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var cur = ""
        func flush() {
            if !cur.isEmpty { tokens.append(cur); cur = "" }
        }
        for ch in d {
            if ch.isLetter {
                flush()
                tokens.append(String(ch))
            } else if ch == "," || ch == " " || ch == "\n" {
                flush()
            } else if ch == "-" && !cur.isEmpty {
                flush()
                cur = "-"
            } else {
                cur.append(ch)
            }
        }
        flush()

        var path = Path()
        var i = 0
        var cmd: Character = "M"
        var last = CGPoint.zero
        func num() -> CGFloat {
            guard i < tokens.count, let v = Double(tokens[i]) else { i += 1; return 0 }
            i += 1
            return CGFloat(v)
        }
        func point() -> CGPoint {
            let x = num()
            let y = num()
            return CGPoint(x: x, y: y)
        }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter {
                cmd = c
                i += 1
                if cmd == "Z" || cmd == "z" {
                    path.closeSubpath()
                    continue
                }
            }
            switch cmd {
            case "M":
                last = point()
                path.move(to: last)
                cmd = "L"
            case "L":
                last = point()
                path.addLine(to: last)
            case "H":
                last = CGPoint(x: num(), y: last.y)
                path.addLine(to: last)
            case "V":
                last = CGPoint(x: last.x, y: num())
                path.addLine(to: last)
            case "Q":
                let c1 = point()
                last = point()
                path.addQuadCurve(to: last, control: c1)
            case "C":
                let c1 = point()
                let c2 = point()
                last = point()
                path.addCurve(to: last, control1: c1, control2: c2)
            default:
                i += 1
            }
        }
        return path
    }
}

/// Eine Truhe in der Optik ihrer Seltenheit: Holz mit Eisen, Stahl, Gold, violett mit Runen, Obsidian mit Gold.
/// `glow` (0…1) lässt Fuge, Schloss und Runen leuchten, `lid` (0…1) sprengt den Deckel auf und zeigt das Innere.
struct ChestView: View, Animatable {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    let rarity: ChestRarity
    var size: CGFloat = 160
    var lid: Double = 0
    var glow: Double = 0

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(lid, glow) }
        set {
            lid = newValue.first
            glow = newValue.second
        }
    }

    /// Magische und Legendäre Truhen schimmern (Runen, Edelstein) – nur in größeren Ansichten.
    private var animated: Bool { rarity >= .magic && size >= 70 }

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        // Kleine, ruhende Truhen (Listen, Pfad, Belohnungen) werden einmal als Bild gezeichnet und danach
        // nur noch angezeigt – sieht gleich aus, kostet aber statt vieler Ebenen mit Weichzeichnern nur ein Bild.
        if size < 70 && lid == 0,
           let image = RenderCache.shared.image(key: "chest-\(rarity.rawValue)-\(Int(size))-\(Int(glow * 20))-\(Int(displayScale))",
                                                 size: CGSize(width: size * 1.2, height: size * 1.08), scale: displayScale,
                                                 content: { liveBody }) {
            Image(uiImage: image)
                .resizable()
                .frame(width: size * 1.2, height: size * 1.08)
                .accessibilityLabel(rarity.name)
        } else {
            liveBody
        }
    }

    private var liveBody: some View {
        ZStack {
            Ellipse()
                .fill(rarity.glowColor)
                .frame(width: size * 1.1, height: size * 0.9)
                .blur(radius: size * 0.15)
                .opacity(0.08 + 0.6 * glow)
            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { tl in
                    canvas(time: clock.time(tl.date))
                }
            } else {
                canvas(time: 0)
            }
        }
        .frame(width: size * 1.2, height: size * 1.08)
        .accessibilityLabel(rarity.name)
    }

    private func canvas(time: Double) -> some View {
        let rarity = rarity, size = size, lid = lid, glow = glow
        return Canvas { ctx, area in
            ChestRenderer.draw(in: &ctx, area: area, chestSize: size, rarity: rarity, lid: lid, glow: glow, time: time)
        }
    }
}

/// Zeichnet die Ebenen aus `ChestArt` in fünf Durchgängen: offener Deckel (hinten), Korpus, Lichtfuge,
/// geschlossener Deckel mit Schloss, Leuchten des Schlosses.
enum ChestRenderer {
    private static let passes: [[ChestArt.Part]] = [[.openLid], [.shadow, .body, .runes, .mouth, .mouthGlow], [.seam], [.lid, .gem, .lock], [.lockGlow]]

    private static func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    static func draw(in ctx: inout GraphicsContext, area: CGSize, chestSize: CGFloat, rarity: ChestRarity,
                     lid: Double, glow: Double, time: Double) {
        let k = chestSize / 78
        let base = CGAffineTransform(translationX: area.width / 2 - 50 * k, y: area.height / 2 - 55 * k).scaledBy(x: k, y: k)
        // Geschlossener Deckel fliegt nach oben weg und kippt leicht
        let fly = CGAffineTransform(translationX: 0, y: -28 * lid)
            .translatedBy(x: 50, y: 54).rotated(by: -0.32 * lid).translatedBy(x: -50, y: -54)
        let lidT = fly.concatenating(base)
        let closed = 1 - smooth(0.08, 0.55, lid)
        let open = smooth(0.25, 0.8, lid)
        let shimmer = 0.55 + 0.25 * sin(time * 2.4)
        let palette = ChestArt.palettes[rarity] ?? [:]
        func color(_ key: ChestArt.Key) -> Color { palette[key] ?? .white }

        for (pi, parts) in passes.enumerated() {
            let t = pi >= 3 ? lidT : base
            for layer in ChestArt.layers where parts.contains(layer.part) {
                if let only = layer.only, !only.contains(rarity) { continue }
                var a = layer.alpha
                if layer.emissive { a *= (layer.part == .runes || layer.part == .gem) ? max(shimmer, glow) : glow }
                switch layer.part {
                case .seam: a *= closed
                case .mouth, .mouthGlow, .openLid: a *= open
                case .lid, .gem, .lock, .lockGlow: a *= closed
                default: break
                }
                if a < 0.003 { continue }

                var c = ctx
                c.opacity = a
                if let clip = layer.clip { c.clip(to: clip.applying(t)) }
                if layer.blur > 0 { c.addFilter(.blur(radius: layer.blur * k)) }
                if rarity == .legendary && layer.part == .gem { c.addFilter(.hueRotation(.degrees(time * 80))) }
                let p = layer.path.applying(t)
                if let fill = layer.fill {
                    switch fill {
                    case .solid(let key, let alpha):
                        c.fill(p, with: .color(color(key).opacity(alpha)))
                    case .linear(let stops, let from, let to):
                        let g = Gradient(stops: stops.map { Gradient.Stop(color: color($0.key).opacity($0.alpha), location: $0.location) })
                        c.fill(p, with: .linearGradient(g, startPoint: from.applying(t), endPoint: to.applying(t)))
                    }
                }
                if let stroke = layer.stroke {
                    c.stroke(p, with: .color(color(stroke)),
                             style: StrokeStyle(lineWidth: layer.width * k, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: - Partikel

/// Leichtes Partikelsystem: Funken, Konfetti, Sterne und Staub. Gezeichnet mit Canvas, bewegt per TimelineView.
final class ParticleSystem: ObservableObject {
    enum Kind { case spark, confetti, star, dust }

    struct Particle {
        let origin: CGPoint
        let velocity: CGVector
        let gravity: CGFloat
        let color: Color
        let size: CGFloat
        let birth: Date
        let life: Double
        let spin: Double
        let kind: Kind
    }

    @Published private(set) var particles: [Particle] = []

    func burst(at point: CGPoint, colors: [Color], count: Int, speed: ClosedRange<CGFloat>,
               angle: ClosedRange<Double> = 0...(2 * .pi), kind: Kind = .spark,
               life: ClosedRange<Double> = 0.6...1.1, gravity: CGFloat = 260, size: ClosedRange<CGFloat> = 3...7,
               delay: Double = 0) {
        let now = Date().addingTimeInterval(delay)
        let alive = particles.filter { now.timeIntervalSince($0.birth) < $0.life }
        var fresh: [Particle] = []
        for _ in 0..<count {
            let a = Double.random(in: angle)
            let v = CGFloat.random(in: speed)
            fresh.append(Particle(origin: point,
                                  velocity: CGVector(dx: CGFloat(cos(a)) * v, dy: CGFloat(sin(a)) * v),
                                  gravity: gravity,
                                  color: colors.randomElement() ?? .white,
                                  size: CGFloat.random(in: size),
                                  birth: now,
                                  life: Double.random(in: life),
                                  spin: Double.random(in: -12...12),
                                  kind: kind))
        }
        particles = alive + fresh
        // Wenn alle Partikel verglüht sind, Liste leeren – dann pausiert die Zeichen-Schleife.
        let end = particles.map { $0.birth.addingTimeInterval($0.life) }.max() ?? Date()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, end.timeIntervalSinceNow + 0.05) * 1_000_000_000))
            guard let self, !self.particles.isEmpty else { return }
            if self.particles.allSatisfy({ Date() >= $0.birth.addingTimeInterval($0.life) }) { self.particles = [] }
        }
    }
}

struct ParticleCanvas: View {
    @ObservedObject var system: ParticleSystem

    var body: some View {
        // Ohne Partikel steht die Zeitleiste still (spart Bildwiederholungen, solange nichts sprüht)
        TimelineView(.animation(minimumInterval: nil, paused: system.particles.isEmpty)) { timeline in
            Canvas { ctx, _ in
                let now = timeline.date
                for p in system.particles {
                    let t = now.timeIntervalSince(p.birth)
                    guard t >= 0, t < p.life else { continue }
                    let x = p.origin.x + p.velocity.dx * CGFloat(t)
                    let y = p.origin.y + p.velocity.dy * CGFloat(t) + 0.5 * p.gravity * CGFloat(t * t)
                    let fade = 1 - t / p.life
                    var c = ctx
                    c.opacity = fade
                    switch p.kind {
                    case .spark, .dust:
                        let s = p.size * CGFloat(0.4 + 0.6 * fade)
                        c.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)), with: .color(p.color))
                    case .confetti:
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(p.spin * t))
                        c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)), with: .color(p.color))
                    case .star:
                        c.translateBy(x: x, y: y)
                        c.rotate(by: .radians(p.spin * t * 0.3))
                        c.fill(ParticleCanvas.star(radius: p.size), with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    static func star(radius r: CGFloat) -> Path {
        var p = Path()
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let rr = i % 2 == 0 ? r : r * 0.4
            let pt = CGPoint(x: CGFloat(cos(a)) * rr, y: CGFloat(sin(a)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// Rotierende Lichtstrahlen hinter der Truhe – einfarbig oder als Regenbogen (epische Karten, legendäre Truhen).
struct LightRays: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    var colors: [Color]
    var count = 14
    var speed = 0.35
    /// Unsichtbare Strahlen nicht weiterdrehen (spart Bildwiederholungen)
    var paused = false

    init(color: Color, count: Int = 14, speed: Double = 0.35, paused: Bool = false) {
        self.colors = [color]
        self.count = count
        self.speed = speed
        self.paused = paused
    }

    init(colors: [Color], count: Int = 16, speed: Double = 0.35, paused: Bool = false) {
        self.colors = colors.isEmpty ? [.white] : colors
        self.count = count
        self.speed = speed
        self.paused = paused
    }

    var body: some View {
        // Höchstens 60 Bilder pro Sekunde: Die Strahlen drehen langsam, 120 auf ProMotion-Displays sieht man nicht,
        // kostet aber doppelt (sie stehen auf Pfad, Profil, Laden und Startseite).
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: paused || !live)) { timeline in
            Canvas { ctx, size in
                let t = clock.time(timeline.date)
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = max(size.width, size.height)
                let step = 2 * Double.pi / Double(count)
                for i in 0..<count {
                    let a = Double(i) * step + t * speed
                    let width = step * (i % 2 == 0 ? 0.24 : 0.14)
                    var p = Path()
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a - width)) * r, y: c.y + CGFloat(sin(a - width)) * r))
                    p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + width)) * r, y: c.y + CGFloat(sin(a + width)) * r))
                    p.closeSubpath()
                    let color = colors[i % colors.count]
                    ctx.fill(p, with: .radialGradient(Gradient(colors: [color.opacity(0.6), color.opacity(0)]),
                                                      center: c, startRadius: 0, endRadius: r * 0.52))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Öffnen

/// Truhe öffnen wie bei Brawl Stars – ganz ohne Knöpfe:
/// Die Truhe kracht herein, drei Taps laden sie auf (Licht dringt aus der Fuge, mit Chance auf eine bessere Truhe),
/// der vierte lässt sie erst zittern und dann explodieren. Die Belohnungen fliegen nacheinander heraus und schalten
/// von selbst weiter (Tippen beschleunigt). Eine neue Karte wird verdeckt enthüllt und dann umgedreht.
/// Danach kommt automatisch die nächste Truhe – oder das Fenster schließt sich.
struct ChestOpeningView: View {
    let start: Chest
    /// Nur diese Truhen nacheinander öffnen (nil = alle wartenden), z. B. die Truhen einer Partie.
    var only: Set<UUID>? = nil
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @StateObject private var particles = ParticleSystem()

    private enum Phase { case intro, arrive, charge, burst, reveal, summary, leaving }
    private enum CardStage: Int { case none, flying, hover, flipped }

    @State private var chest: Chest
    @State private var plan: ChestPlan?
    @State private var phase: Phase = .arrive
    @State private var rarity: ChestRarity
    @State private var taps = 0
    @State private var busy = true
    @State private var rewards: [ChestReward] = []
    @State private var revealIndex = 0
    @State private var opened: [ChestReward] = []
    /// Jeder geplante Auto-Schritt merkt sich den Stand – ein Tipp dazwischen macht ihn ungültig.
    @State private var token = 0
    @State private var cardStage: CardStage = .none

    // Truhe
    @State private var drop: CGFloat = -760
    @State private var stretch: CGFloat = 1
    @State private var squash = CGSize(width: 1, height: 1)
    @State private var wobble: Double = 0
    @State private var hop: CGFloat = 0
    @State private var breathe = false
    @State private var lid: Double = 0
    @State private var glow: Double = 0
    @State private var chestOpacity: Double = 1
    @State private var chestScale: CGFloat = 1
    /// Während der Belohnungen rutscht die Truhe nach unten, damit oben Platz ist.
    @State private var shift: CGFloat = 0
    @State private var cardRays: Double = 0
    // Szene
    @State private var flash: Double = 0
    @State private var flashColor: Color = .white
    @State private var shake: CGFloat = 0
    @State private var raysOpacity: Double = 0
    @State private var rayColors: [Color] = [.white]
    @State private var pillar: CGFloat = 0
    @State private var ringScale: CGFloat = 0.2
    @State private var ringOpacity: Double = 0
    @State private var ringColor: Color = .white
    @State private var dim: Double = 0
    @State private var shout: String?
    @State private var shoutScale: CGFloat = 0.3
    @State private var hintPulse = false
    @State private var area: CGSize = .zero
    // Vorspann: wofür es die Truhe gibt
    @State private var introPop = false
    @State private var introOut = false
    @State private var introWords = false

    init(start: Chest, only: Set<UUID>? = nil) {
        self.start = start
        self.only = only
        _chest = State(initialValue: start)
        _rarity = State(initialValue: start.rarity)
    }

    /// Truhen, die nach dieser noch drankommen
    private var queue: [Chest] {
        store.pendingChests.filter { c in c.id != chest.id && (only?.contains(c.id) ?? true) }
    }

    private var chestSize: CGFloat { min(250, area.width * 0.62) }
    private var chestCenter: CGPoint { CGPoint(x: area.width / 2, y: area.height * 0.46) }
    /// Mitte der Truhe, wie sie gerade steht (mit Verschiebung und Verkleinerung, Skalierung am Boden)
    private var liveCenter: CGPoint {
        CGPoint(x: chestCenter.x, y: chestCenter.y + shift + chestSize * 0.54 * (1 - chestScale))
    }
    /// Fuge bzw. Öffnung der Truhe
    private var seamPoint: CGPoint { CGPoint(x: liveCenter.x, y: liveCenter.y + chestSize * chestScale * 0.035) }
    private var groundY: CGFloat { chestCenter.y + shift + chestSize * 0.46 }
    /// Wo die Belohnungen schweben
    private var rewardY: CGFloat { area.height * 0.38 }

    private var currentReward: ChestReward? { rewards.indices.contains(revealIndex) ? rewards[revealIndex] : nil }
    private var currentCard: CardType? {
        if case .card(let c)? = currentReward { return c }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background
                LightRays(colors: rayColors, count: 16, speed: phase == .reveal ? 0.22 : 0.45, paused: raysOpacity == 0)
                    .frame(width: geo.size.width * 2.4, height: geo.size.width * 2.4)
                    .position(phase == .reveal ? CGPoint(x: chestCenter.x, y: rewardY) : liveCenter)
                    .opacity(raysOpacity)
                lightPillar
                shockRing
                chestStage
                Color.black.opacity(dim).ignoresSafeArea().allowsHitTesting(false)
                LightRays(colors: rayColors, count: 18, speed: 0.3, paused: cardRays == 0)
                    .frame(width: geo.size.width * 2.4, height: geo.size.width * 2.4)
                    .position(x: chestCenter.x, y: rewardY)
                    .opacity(cardRays)
                rewardStage
                if phase == .intro { introView }
                ParticleCanvas(system: particles)
                hud
                flashColor.opacity(flash).ignoresSafeArea().allowsHitTesting(false).blendMode(.screen)
                shoutView
            }
            .modifier(ShakeEffect(amount: 12, shakes: 4, animatableData: shake))
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }
            .onAppear {
                area = geo.size
                rayColors = [rarity.glowColor]
                intro()
            }
            .onChange(of: geo.size) { area = $0 }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
    }

    // MARK: Ebenen

    private var background: some View {
        ZStack {
            Color(hex: 0x060A14)
            RadialGradient(colors: [rarity.bodyColor.opacity(0.35 + 0.3 * glow), rarity.darkColor.opacity(0.2), .clear],
                           center: UnitPoint(x: 0.5, y: 0.46), startRadius: 10, endRadius: 560)
            // Boden mit weichem Lichtfleck
            Ellipse()
                .fill(RadialGradient(colors: [rarity.glowColor.opacity(0.18 + 0.35 * glow), .clear], center: .center, startRadius: 0, endRadius: 200))
                .frame(width: 420, height: 90)
                .position(x: chestCenter.x, y: groundY + 6)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: rarity)
    }

    /// Lichtsäule aus der offenen Truhe
    private var lightPillar: some View {
        ZStack {
            LinearGradient(colors: [.clear, rarity.glowColor.opacity(0.55), .white.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .frame(width: chestSize * 0.75 * pillar)
                .blur(radius: 18)
            LinearGradient(colors: [.clear, .white.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .frame(width: chestSize * 0.22 * pillar)
                .blur(radius: 6)
        }
        .frame(height: seamPoint.y)
        .position(x: chestCenter.x, y: seamPoint.y / 2)
        .opacity(Double(pillar) * (phase == .summary ? 0.4 : 1))
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    private var shockRing: some View {
        Ellipse()
            .strokeBorder(ringColor, lineWidth: 6)
            .frame(width: chestSize * 1.3, height: chestSize * 0.34)
            .scaleEffect(ringScale)
            .opacity(ringOpacity)
            .position(x: chestCenter.x, y: groundY)
            .blur(radius: 1.5)
            .allowsHitTesting(false)
    }

    private var chestStage: some View {
        ChestView(rarity: rarity, size: chestSize, lid: lid, glow: glow)
            .scaleEffect(x: squash.width, y: squash.height * stretch, anchor: .bottom)
            .scaleEffect(breathe && phase == .charge ? 1.025 : 1, anchor: .bottom)
            .rotationEffect(.degrees(wobble), anchor: .bottom)
            .scaleEffect(chestScale, anchor: .bottom)
            .offset(y: drop + hop + shift)
            .opacity(chestOpacity)
            .position(chestCenter)
            .allowsHitTesting(false)
    }

    @ViewBuilder private var rewardStage: some View {
        switch phase {
        case .reveal:
            if let card = currentCard {
                CardReveal(card: card, stage: cardStage.rawValue, fromY: seamPoint.y - rewardY)
                    .id(revealIndex)
                    .position(x: area.width / 2, y: rewardY)
            } else if let reward = currentReward {
                RewardRevealCard(reward: reward, remaining: rewards.count - revealIndex - 1)
                    .id(revealIndex)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.1, anchor: .center).combined(with: .offset(y: seamPoint.y - rewardY)).combined(with: .opacity),
                        removal: .scale(scale: 1.25).combined(with: .opacity)))
                    .position(x: area.width / 2, y: rewardY)
            }
        case .summary, .leaving:
            summary
                .position(x: area.width / 2, y: area.height * 0.5)
                .opacity(phase == .leaving ? 0 : 1)
        default:
            EmptyView()
        }
    }

    private var hud: some View {
        ZStack {
            VStack(spacing: 6) {
                Text(chest.title.uppercased())
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(Theme.textSecondary)
                let more = queue.count
                if more > 0 && phase != .summary && phase != .intro {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill").font(.system(size: 10, weight: .bold))
                        Text(L("danach noch {0}", more))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                }
                Spacer()
                Group {
                    if phase == .charge {
                        Text(taps < ChestPlan.chargeTaps ? L("Tippe auf die Truhe!") : L("Jetzt aufsprengen!"))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(hintPulse ? 1.08 : 0.95)
                    } else if phase == .reveal {
                        Text(L("Tippen zum Beschleunigen"))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textMuted.opacity(0.7))
                    }
                }
                .padding(.bottom, 48)
            }
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Name der Truhe und Ladebalken direkt unter der Truhe
            if phase == .arrive || phase == .charge {
                VStack(spacing: 10) {
                    Text(rarity.name.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(LinearGradient(colors: [.white, rarity.lightColor], startPoint: .top, endPoint: .bottom))
                        .shadow(color: rarity.darkColor, radius: 0, y: 3)
                        .shadow(color: rarity.glowColor.opacity(0.6), radius: 10)
                        .id(rarity)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                    HStack(spacing: 12) {
                        ForEach(0..<ChestPlan.chargeTaps, id: \.self) { i in
                            Capsule()
                                .fill(i < taps ? rarity.glowColor : Color.white.opacity(0.16))
                                .frame(width: i < taps ? 30 : 22, height: 8)
                                .shadow(color: i < taps ? rarity.glowColor : .clear, radius: 6)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: taps)
                }
                .opacity(phase == .charge ? 1 : 0)
                .position(x: chestCenter.x, y: groundY + 58)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var shoutView: some View {
        if let shout {
            Text(shout)
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, rarity.lightColor, rarity.glowColor], startPoint: .top, endPoint: .bottom))
                .shadow(color: rarity.darkColor, radius: 0, x: 0, y: 5)
                .shadow(color: rarity.glowColor.opacity(0.9), radius: 22)
                .scaleEffect(shoutScale)
                .rotationEffect(.degrees(-6))
                .position(x: chestCenter.x, y: chestCenter.y - chestSize * 0.85)
                .allowsHitTesting(false)
        }
    }

    private var summary: some View {
        VStack(spacing: 14) {
            Text(L("Ausbeute"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: rarity.glowColor.opacity(0.6), radius: 10)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(opened.enumerated()), id: \.offset) { i, r in
                    RewardTile(reward: r)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            if let next = queue.first {
                HStack(spacing: 8) {
                    ChestView(rarity: next.rarity, size: 34)
                    Text(queue.count == 1 ? L("Gleich kommt die nächste Truhe …") : L("Gleich: noch {0} Truhen", queue.count))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.gold)
                }
            }
            Text(L("Tippen zum Fortfahren"))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textMuted)
        }
    }

    // MARK: Ablauf

    private func arrive() {
        plan = store.plan(chest)
        busy = true
        taps = 0
        drop = -760
        stretch = 1.3
        chestOpacity = 1
        chestScale = 1
        shift = 0
        cardRays = 0
        squash = CGSize(width: 1, height: 1)
        Haptics.shared.play(.cardWhoosh)
        withAnimation(.easeIn(duration: 0.34)) { drop = 0 }
        after(0.34) {
            // Aufprall: Stauchen, Staub, Schockwelle, Beben
            stretch = 1
            Haptics.shared.play(.chestLand)
            SoundPlayer.shared.play(.chestLand)
            squashPulse(x: 1.24, y: 0.76, hold: 0.06)
            withAnimation(.linear(duration: 0.32)) { shake += 1 }
            ring(color: Color(hex: 0xE8DCC8), to: 1.7, opacity: 0.55)
            dust()
        }
        after(0.62) {
            phase = .charge
            busy = false
            foreverAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) { hintPulse = true }
            foreverAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private func handleTap() {
        switch phase {
        case .charge:
            guard !busy else { return }
            taps < ChestPlan.chargeTaps ? charge() : burst()
        case .reveal:
            guard !busy else { return }
            advanceReveal()
        case .summary:
            finishSummary()
        case .intro:
            endIntro()
        default:
            break
        }
    }

    private func charge() {
        guard let plan else { return }
        taps += 1
        let step = taps
        let target = plan.steps[step - 1]
        let kind: HapticKind = step == 1 ? .chestCharge1 : (step == 2 ? .chestCharge2 : .chestCharge3)
        Haptics.shared.play(kind)
        SoundPlayer.shared.play(.chestTap, volume: 0.55 + 0.15 * Float(step))
        squashPulse(x: 1.1 + 0.05 * CGFloat(step), y: 0.88 - 0.035 * CGFloat(step))
        withAnimation(.spring(response: 0.16, dampingFraction: 0.3)) { wobble = Double.random(in: 6...11) * (step % 2 == 0 ? 1 : -1) }
        after(0.11) { withAnimation(.spring(response: 0.35, dampingFraction: 0.42)) { wobble = 0 } }
        withAnimation(.easeOut(duration: 0.35)) {
            glow = 0.3 + 0.7 * Double(step) / Double(ChestPlan.chargeTaps)
            raysOpacity = 0.12 * Double(step)
        }
        // Funken spritzen links und rechts aus der Fuge
        let w = chestSize * 0.42
        for side in [-1.0, 1.0] {
            particles.burst(at: CGPoint(x: seamPoint.x + CGFloat(side) * w, y: seamPoint.y),
                            colors: [rarity.glowColor, .white, rarity.lightColor], count: 8 + step * 5,
                            speed: 120...(220 + CGFloat(step) * 70),
                            angle: side < 0 ? (.pi * 0.9)...(.pi * 1.45) : (.pi * 1.55)...(.pi * 2.1),
                            kind: .spark, life: 0.35...0.75, gravity: 320, size: 2...5)
        }
        particles.burst(at: seamPoint, colors: [rarity.glowColor, .white], count: 6 + step * 4, speed: 60...160,
                        angle: (.pi * 1.2)...(.pi * 1.8), kind: .star, life: 0.4...0.8, gravity: 60, size: 3...6)
        if step == ChestPlan.chargeTaps { withAnimation(.linear(duration: 0.35)) { shake += 1 } }
        if target > rarity {
            busy = true
            after(0.18) { upgrade(to: target) }
            after(1.0) { busy = false }
        }
    }

    private func upgrade(to target: ChestRarity) {
        Haptics.shared.play(.chestUpgrade)
        SoundPlayer.shared.play(.chestUpgrade)
        // Die Truhe springt hoch, verwandelt sich im Blitz und landet als bessere Truhe
        withAnimation(.easeOut(duration: 0.18)) { hop = -chestSize * 0.22 }
        after(0.12) {
            flashColor = target.glowColor
            withAnimation(.easeOut(duration: 0.06)) { flash = 0.9 }
            withAnimation(.easeInOut(duration: 0.2)) { rarity = target }
            rayColors = target == .legendary ? ChestOpeningView.rainbow : [target.glowColor]
            after(0.06) { withAnimation(.easeOut(duration: 0.55)) { flash = 0 } }
            particles.burst(at: chestCenter, colors: [target.glowColor, target.lightColor, .white], count: 50,
                            speed: 220...480, kind: .star, life: 0.7...1.3, gravity: 140, size: 5...11)
            shout = target.shout
            shoutScale = 0.3
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { shoutScale = 1.1 }
        }
        after(0.2) { withAnimation(.easeIn(duration: 0.16)) { hop = 0 } }
        after(0.36) {
            Haptics.shared.play(.chestLand)
            squashPulse(x: 1.2, y: 0.8)
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
            ring(color: target.glowColor, to: 2.0, opacity: 0.8)
        }
        after(1.0) { withAnimation(.easeIn(duration: 0.22)) { shoutScale = 0.01 } }
        after(1.25) { if shout == target.shout { shout = nil } }
    }

    private func burst() {
        guard let plan else { return }
        busy = true
        hintPulse = false
        breathe = false
        if rarity != plan.final { rarity = plan.final }
        // Vorfreude: Die Truhe zittert immer heftiger und duckt sich
        Haptics.shared.play(.chestRumble)
        SoundPlayer.shared.play(.chestRumble)
        withAnimation(.easeIn(duration: 0.45)) {
            squash = CGSize(width: 1.1, height: 0.86)
            glow = 1
            raysOpacity = 0.5
        }
        for i in 0..<11 {
            after(Double(i) * 0.042) {
                withAnimation(.linear(duration: 0.04)) { wobble = (i % 2 == 0 ? 1 : -1) * (1.5 + Double(i) * 0.45) }
            }
        }
        after(0.48) {
            wobble = 0
            rewards = store.open(plan)
            opened.append(contentsOf: rewards)
            phase = .burst
            Haptics.shared.play(.chestBurst)
            SoundPlayer.shared.play(.chestOpen)
            flashColor = .white
            withAnimation(.easeOut(duration: 0.05)) { flash = 1 }
            after(0.05) { withAnimation(.easeOut(duration: 0.7)) { flash = 0 } }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { lid = 1 }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.35)) { squash = CGSize(width: 0.9, height: 1.16) }
            after(0.12) { withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { squash = CGSize(width: 1, height: 1) } }
            withAnimation(.easeOut(duration: 0.35)) { pillar = 1; raysOpacity = 0.85 }
            after(0.6) { withAnimation(.easeInOut(duration: 0.8)) { pillar = 0.55 } }
            withAnimation(.linear(duration: 0.55)) { shake += 1 }
            ring(color: rarity.glowColor, to: 2.6, opacity: 0.9)
            let confetti: [Color] = [rarity.glowColor, rarity.lightColor, .white, Theme.gold, Theme.manaLight, ShardStyle.color]
            particles.burst(at: seamPoint, colors: confetti, count: 100, speed: 280...660,
                            angle: (.pi * 1.08)...(.pi * 1.92), kind: .confetti, life: 1.3...2.4, gravity: 540, size: 7...13)
            particles.burst(at: seamPoint, colors: [rarity.glowColor, .white], count: 46, speed: 140...420,
                            kind: .star, life: 0.6...1.3, gravity: 60, size: 4...10)
            particles.burst(at: seamPoint, colors: [ShardStyle.color, .white], count: 24, speed: 200...420,
                            angle: (.pi * 1.25)...(.pi * 1.75), kind: .spark, life: 0.8...1.4, gravity: 420, size: 3...6, delay: 0.1)
        }
        after(1.35) { startReveal(0) }
    }

    // MARK: Belohnungen

    private func startReveal(_ index: Int) {
        guard rewards.indices.contains(index) else { showSummary(); return }
        token += 1
        let my = token
        let reward = rewards[index]
        let isCard: Bool = { if case .card = reward { return true }; return false }()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            phase = .reveal
            revealIndex = index
            cardStage = isCard ? .flying : .none
            dim = isCard ? 0.72 : 0
            cardRays = 0
            chestScale = 0.62
            shift = area.height * 0.2
        }
        busy = true
        after(0.3) { busy = false }
        switch reward {
        case .card(let card):
            Haptics.shared.play(.cardWhoosh)
            SoundPlayer.shared.play(.cardWhoosh)
            rayColors = card.tier == .epic ? ChestOpeningView.rainbow : [Color(hex: card.tier.colorHex)]
            after(0.6) {
                guard token == my else { return }
                withAnimation(.easeInOut(duration: 0.3)) { cardStage = .hover }
                Haptics.shared.play(.cardAnticipate)
            }
            after(1.75) { if token == my, cardStage == .hover { flipCard() } }
        default:
            revealEffects(reward)
            let wait: Double = reward.isBig ? 2.4 : 1.25
            after(wait) { if token == my { advanceReveal() } }
        }
    }

    private func advanceReveal() {
        if case .card? = currentReward, cardStage != .flipped {
            if cardStage == .hover || cardStage == .flying { flipCard() }
            return
        }
        if revealIndex < rewards.count - 1 {
            startReveal(revealIndex + 1)
        } else {
            showSummary()
        }
    }

    private func flipCard() {
        guard case .card(let card)? = currentReward else { return }
        token += 1
        let my = token
        busy = true
        withAnimation(.easeInOut(duration: 0.42)) { cardStage = .flipped }
        after(0.21) {
            Haptics.shared.play(.cardFlip)
            SoundPlayer.shared.play(.cardFlip)
            after(0.15) { SoundPlayer.shared.play(.rewardBig, volume: 0.7) }
            let tier = Color(hex: card.tier.colorHex)
            flashColor = tier
            withAnimation(.easeOut(duration: 0.06)) { flash = 0.8 }
            after(0.06) { withAnimation(.easeOut(duration: 0.6)) { flash = 0 } }
            withAnimation(.easeOut(duration: 0.4)) { cardRays = 1 }
            let center = CGPoint(x: area.width / 2, y: rewardY)
            let colors: [Color] = card.tier == .epic ? ChestOpeningView.rainbow + [.white] : [tier, .white, Theme.gold]
            particles.burst(at: center, colors: colors, count: 80, speed: 220...560, kind: .star, life: 0.8...1.7, gravity: 150, size: 5...12)
            particles.burst(at: center, colors: colors, count: 60, speed: 180...480, kind: .confetti, life: 1.2...2.2, gravity: 420, size: 6...12, delay: 0.15)
            withAnimation(.linear(duration: 0.45)) { shake += 1 }
            ring(color: tier, to: 2.4, opacity: 0.8, at: groundY)
        }
        after(0.6) { busy = false }
        after(3.6) { if token == my { advanceReveal() } }
    }

    private func revealEffects(_ reward: ChestReward) {
        let center = CGPoint(x: area.width / 2, y: rewardY)
        switch reward {
        case .xp(let n):
            Haptics.shared.play(.chestReveal)
            SoundPlayer.shared.play(.reward)
            for i in 0..<min(8, max(3, n / 10)) { after(0.15 + Double(i) * 0.07) { Haptics.shared.play(.chestCount) } }
            particles.burst(at: center, colors: [Theme.manaLight, .white], count: 20, speed: 100...240, kind: .spark,
                            life: 0.5...0.9, gravity: 80, size: 2...5)
        case .shards:
            Haptics.shared.play(.shardShower)
            SoundPlayer.shared.play(.shardShower)
            particles.burst(at: CGPoint(x: center.x, y: center.y - 120), colors: [ShardStyle.color, .white, ShardStyle.deep], count: 34,
                            speed: 40...160, angle: (.pi * 0.2)...(.pi * 0.8), kind: .star, life: 0.9...1.5, gravity: 420, size: 3...7)
        case .jackpot:
            Haptics.shared.play(.chestBigReveal)
            SoundPlayer.shared.play(.shardShower)
            after(0.2) { SoundPlayer.shared.play(.rewardBig) }
            flashColor = ShardStyle.color
            withAnimation(.easeOut(duration: 0.06)) { flash = 0.7 }
            after(0.06) { withAnimation(.easeOut(duration: 0.5)) { flash = 0 } }
            particles.burst(at: CGPoint(x: center.x, y: center.y - 160), colors: [ShardStyle.color, .white, ShardStyle.deep], count: 80,
                            speed: 60...240, angle: (.pi * 0.15)...(.pi * 0.85), kind: .star, life: 1.0...1.8, gravity: 460, size: 4...9)
        case .board, .avatar, .frame, .title:
            Haptics.shared.play(.chestBigReveal)
            SoundPlayer.shared.play(.rewardBig)
            flashColor = Theme.gold
            withAnimation(.easeOut(duration: 0.06)) { flash = 0.55 }
            after(0.06) { withAnimation(.easeOut(duration: 0.5)) { flash = 0 } }
            particles.burst(at: center, colors: [Theme.gold, .white, Theme.blueLight, Color(hex: 0xB06CFF)], count: 70, speed: 180...480,
                            kind: .star, life: 0.8...1.6, gravity: 140, size: 5...11)
            particles.burst(at: center, colors: [Theme.gold, .white], count: 40, speed: 160...420,
                            kind: .confetti, life: 1.0...1.8, gravity: 400, size: 6...11, delay: 0.15)
        case .card:
            break
        }
    }

    private func showSummary() {
        token += 1
        let my = token
        withAnimation(.easeInOut(duration: 0.35)) {
            phase = .summary
            dim = 0.35
            raysOpacity = 0.35
            cardRays = 0
            chestOpacity = 0.3
            cardStage = .none
        }
        rayColors = [rarity.glowColor]
        let hasBig = opened.contains { $0.isBig }
        after(hasBig ? 2.8 : 2.1) { if token == my { finishSummary() } }
    }

    private func finishSummary() {
        guard phase == .summary else { return }
        token += 1
        if let next = queue.first {
            // Weiter zur nächsten Truhe: alles ausblenden, neue Truhe kracht herein
            withAnimation(.easeIn(duration: 0.25)) {
                phase = .leaving
                chestOpacity = 0
                pillar = 0
                raysOpacity = 0
                cardRays = 0
                dim = 0
                glow = 0
            }
            after(0.3) { restart(with: next) }
        } else {
            dismiss()
        }
    }

    private func restart(with next: Chest) {
        chest = next
        rarity = next.rarity
        rayColors = [next.rarity.glowColor]
        lid = 0
        glow = 0
        rewards = []
        revealIndex = 0
        opened = []
        shout = nil
        cardStage = .none
        intro()
    }

    // MARK: Vorspann

    /// Großer Moment vor jeder Truhe: Abzeichen mit dem Grund („Für deinen Sieg!“), Strahlen, Funken.
    private var introView: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(rarity.glowColor.opacity(0.85))
                        .frame(width: 5, height: introPop ? 26 : 4)
                        .offset(y: introPop ? -92 : -60)
                        .rotationEffect(.degrees(Double(i) * 45))
                        .opacity(introPop ? 1 : 0)
                }
                Circle()
                    .fill(RadialGradient(colors: [rarity.lightColor, rarity.bodyColor, rarity.darkColor],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 4, endRadius: 80))
                    .frame(width: 128, height: 128)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 5))
                    .overlay(Circle().strokeBorder(rarity.darkColor.opacity(0.6), lineWidth: 2).padding(7))
                    .shadow(color: rarity.glowColor.opacity(0.9), radius: 28)
                Image(systemName: chest.source.icon)
                    .font(.system(size: 54, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.white, rarity.lightColor], startPoint: .top, endPoint: .bottom))
                    .shadow(color: rarity.darkColor, radius: 0, y: 4)
            }
            .scaleEffect(introPop ? 1 : 0.15)
            .rotationEffect(.degrees(introPop ? 0 : -50))

            Text(chest.reasonHeadline.uppercased())
                .font(.system(size: 30, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .foregroundStyle(LinearGradient(colors: [.white, rarity.lightColor], startPoint: .top, endPoint: .bottom))
                .shadow(color: rarity.darkColor, radius: 0, y: 4)
                .shadow(color: rarity.glowColor.opacity(0.7), radius: 14)
                .rotationEffect(.degrees(-3))
                .padding(.horizontal, 24)
                .scaleEffect(introWords ? 1 : 2.2)
                .opacity(introWords ? 1 : 0)

            HStack(spacing: 8) {
                ChestView(rarity: rarity, size: 40, glow: 0.6)
                Text(L("Deine Belohnung: {0}", rarity.name))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .offset(y: introWords ? 0 : 30)
            .opacity(introWords ? 1 : 0)
        }
        .frame(width: area.width)
        .position(x: area.width / 2, y: area.height * 0.42)
        .scaleEffect(introOut ? 1.35 : 1)
        .opacity(introOut ? 0 : 1)
        .allowsHitTesting(false)
    }

    private func intro() {
        phase = .intro
        busy = true
        token += 1
        let my = token
        introPop = false
        introWords = false
        introOut = false
        chestOpacity = 0
        rayColors = [rarity.glowColor]
        withAnimation(.easeOut(duration: 0.4)) { raysOpacity = 0.4; glow = 0.4 }
        after(0.05) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.5)) { introPop = true }
            Haptics.shared.play(.chestReveal)
            SoundPlayer.shared.play(.reward, volume: 0.8)
            let center = CGPoint(x: area.width / 2, y: area.height * 0.42 - 70)
            particles.burst(at: center, colors: [rarity.glowColor, rarity.lightColor, .white], count: 36,
                            speed: 160...380, kind: .star, life: 0.6...1.2, gravity: 120, size: 4...9)
        }
        after(0.3) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { introWords = true }
            Haptics.shared.play(.chestLand)
            withAnimation(.linear(duration: 0.3)) { shake += 1 }
        }
        after(0.55) {
            let y = area.height * 0.42 + 40
            for side in [-1.0, 1.0] {
                particles.burst(at: CGPoint(x: area.width / 2 + CGFloat(side) * 120, y: y),
                                colors: [rarity.glowColor, .white, Theme.gold], count: 14, speed: 140...300,
                                angle: side < 0 ? (.pi * 1.1)...(.pi * 1.5) : (.pi * 1.5)...(.pi * 1.9),
                                kind: .spark, life: 0.4...0.9, gravity: 260, size: 2...5)
            }
        }
        after(1.75) { if token == my && phase == .intro { endIntro() } }
    }

    private func endIntro() {
        guard phase == .intro else { return }
        token += 1
        withAnimation(.easeIn(duration: 0.2)) { introOut = true; raysOpacity = 0; glow = 0 }
        after(0.2) {
            phase = .arrive
            chestOpacity = 1
            arrive()
        }
    }

    // MARK: Hilfen

    static let rainbow: [Color] = [Color(hex: 0xFF6B6B), Color(hex: 0xFFC36B), Color(hex: 0xFFF06B), Color(hex: 0x6BFF9E),
                                   Color(hex: 0x6BD5FF), Color(hex: 0x9B6BFF), Color(hex: 0xFF6BE1)]

    private func squashPulse(x: CGFloat, y: CGFloat, hold: Double = 0.07) {
        withAnimation(.easeOut(duration: 0.07)) { squash = CGSize(width: x, height: y) }
        after(hold) { withAnimation(.spring(response: 0.32, dampingFraction: 0.38)) { squash = CGSize(width: 1, height: 1) } }
    }

    private func ring(color: Color, to scale: CGFloat, opacity: Double, at y: CGFloat? = nil) {
        ringColor = color
        ringScale = 0.25
        ringOpacity = opacity
        withAnimation(.easeOut(duration: 0.6)) {
            ringScale = scale
            ringOpacity = 0
        }
    }

    private func dust() {
        let y = groundY
        let w = chestSize * 0.45
        particles.burst(at: CGPoint(x: chestCenter.x - w, y: y), colors: [Color(hex: 0xD8C9AE), .white.opacity(0.7)], count: 18,
                        speed: 60...190, angle: (.pi * 0.95)...(.pi * 1.3), kind: .dust, life: 0.4...0.9, gravity: 110, size: 3...9)
        particles.burst(at: CGPoint(x: chestCenter.x + w, y: y), colors: [Color(hex: 0xD8C9AE), .white.opacity(0.7)], count: 18,
                        speed: 60...190, angle: (.pi * 1.7)...(.pi * 2.05), kind: .dust, life: 0.4...0.9, gravity: 110, size: 3...9)
    }

    private func after(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            action()
        }
    }
}

// MARK: - Karten-Enthüllung

/// Neue Karte: fliegt verdeckt aus der Truhe, schwebt mit pulsierender Aura und Herzklopfen – dann dreht sie sich um.
struct CardReveal: View {
    let card: CardType
    /// 1 = fliegt heraus, 2 = schwebt, 3 = umgedreht
    let stage: Int
    let fromY: CGFloat
    @State private var arrived = false
    @State private var hover = false
    @State private var jitter = false
    @State private var textIn = false

    private var tier: Color { Color(hex: card.tier.colorHex) }
    private var flipped: Bool { stage >= 3 }

    var body: some View {
        VStack(spacing: 14) {
            Text(L("NEUE KARTE!"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                .shadow(color: CardStyle.ultimateDeep, radius: 0, y: 4)
                .shadow(color: Theme.gold.opacity(0.8), radius: 14)
                .scaleEffect(textIn ? 1 : 2.4)
                .opacity(textIn ? 1 : 0)
                .rotationEffect(.degrees(textIn ? -4 : -12))

            ZStack {
                // Aura
                RoundedRectangle(cornerRadius: 26)
                    .fill(tier)
                    .frame(width: 210, height: 270)
                    .blur(radius: 30)
                    .opacity(flipped ? 0.75 : (hover ? 0.7 : 0.35))
                    .scaleEffect(hover && !flipped ? 1.12 : 1)
                CardBackView(tint: tier)
                    .frame(width: 176, height: 236)
                    .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .opacity(flipped ? 0 : 1)
                    .animation(.linear(duration: 0.001).delay(flipped ? 0.21 : 0), value: flipped)
                ShowcaseCard(card: card)
                    .frame(width: 176, height: 236)
                    .rotation3DEffect(.degrees(flipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .opacity(flipped ? 1 : 0)
                    .animation(.linear(duration: 0.001).delay(flipped ? 0.21 : 0), value: flipped)
            }
            .rotationEffect(.degrees(jitter && !flipped ? 2.2 : (hover && !flipped ? -2.2 : 0)))
            .offset(y: hover && !flipped ? -8 : 0)
            .scaleEffect(arrived ? (flipped ? 1.04 : 1) : 0.2)
            .rotationEffect(.degrees(arrived ? 0 : -540))
            .offset(y: arrived ? 0 : fromY)

            VStack(spacing: 6) {
                Text(card.tier.name.uppercased())
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundColor(card.tier == .epic ? .white : tier)
                    .padding(.horizontal, 12)
                    .frame(height: 24)
                    .background(Capsule().fill(card.tier == .epic
                                               ? AnyShapeStyle(LinearGradient(colors: ChestOpeningView.rainbow, startPoint: .leading, endPoint: .trailing))
                                               : AnyShapeStyle(tier.opacity(0.2))))
                Text(card.name)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(card.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(textIn ? 1 : 0)
            .offset(y: textIn ? 0 : 20)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { arrived = true }
        }
        .onChange(of: stage) { s in
            if s == 2 {
                foreverAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { hover = true }
                foreverAnimation(.easeInOut(duration: 0.09).repeatForever(autoreverses: true).delay(0.5)) { jitter = true }
            }
            if s >= 3 {
                hover = false
                jitter = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.28)) { textIn = true }
            }
        }
    }
}

/// Rückseite einer Karte: Muster in der Farbe der Seltenheit, goldener Rand, Turm in der Mitte.
struct CardBackView: View {
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(hex: 0x16244A), tint.opacity(0.9), Color(hex: 0x0D1530)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Canvas { ctx, size in
                var p = Path()
                let step: CGFloat = 16
                var x: CGFloat = -size.height
                while x < size.width {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    p.move(to: CGPoint(x: x + size.height, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                ctx.stroke(p, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                .padding(9)
            ZStack {
                Circle().fill(Color.black.opacity(0.3)).frame(width: 92, height: 92)
                Circle().strokeBorder(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                    .frame(width: 92, height: 92)
                PieceImage(type: .rook, color: .white).frame(width: 52, height: 52)
            }
            Text("?")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .offset(y: 82)
        }
        .overlay(RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold, CardStyle.ultimateDeep], startPoint: .top, endPoint: .bottom), lineWidth: 4))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
    }
}

/// Große Schaukarte für die Enthüllung: das gemalte Kartenbild randlos, Rahmen in der Seltenheitsfarbe,
/// Name und Rolle auf einem Band unten, Kosten oben links.
struct ShowcaseCard: View {
    let card: CardType

    var body: some View {
        let tier = Color(hex: card.tier.colorHex)
        let role = Color(hex: card.role.colorHex)
        ZStack(alignment: .bottom) {
            CardArtImage(name: "art-card-\(card.rawValue)")
            // Verlauf, damit der Name auf jedem Bild lesbar bleibt
            LinearGradient(colors: [.clear, Color.black.opacity(0.55), Color.black.opacity(0.85)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 92)
            VStack(spacing: 3) {
                Text(card.name)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.6), radius: 0, y: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Image(systemName: card.role.icon).font(.system(size: 10, weight: .bold))
                    Text(card.role.name).font(.system(size: 11, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(Capsule().fill(role.opacity(0.85)))
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(alignment: .topLeading) {
            ManaDrop(text: "\(card.cost)", size: 40)
                .padding(.leading, 6)
                .padding(.top, 6)
        }
        .overlay(RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(card.tier == .epic
                                  ? AnyShapeStyle(LinearGradient(colors: ChestOpeningView.rainbow, startPoint: .topLeading, endPoint: .bottomTrailing))
                                  : AnyShapeStyle(LinearGradient(colors: [.white, tier, tier.opacity(0.7)], startPoint: .top, endPoint: .bottom)),
                                  lineWidth: 5))
        .shadow(color: tier.opacity(0.9), radius: 18)
    }
}

// MARK: - Belohnungen

/// Große Anzeige für XP, Splitter, Brett oder Splitter-Fund – Zahlen zählen hoch.
struct RewardRevealCard: View {
    let reward: ChestReward
    let remaining: Int
    @State private var shown = 0
    @State private var pulse = false
    @State private var pop = false

    var body: some View {
        VStack(spacing: 14) {
            switch reward {
            case .xp(let n):
                amountCard(icon: AnyView(Image(systemName: "sparkles").font(.system(size: 70, weight: .black))
                                            .foregroundStyle(LinearGradient(colors: [.white, Theme.manaLight], startPoint: .top, endPoint: .bottom))),
                           color: Theme.manaLight, value: n, label: L("XP"))
            case .shards(let n):
                amountCard(icon: AnyView(ShardIcon(size: 72)), color: ShardStyle.color, value: n, label: L("Splitter"))
            case .jackpot(let n):
                VStack(spacing: 6) {
                    Text(L("SAMMLUNG KOMPLETT!"))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, ShardStyle.color], startPoint: .top, endPoint: .bottom))
                    amountCard(icon: AnyView(ShardIcon(size: 90)), color: ShardStyle.color, value: n, label: L("Splitter-Fund"))
                }
            case .board(let theme):
                boardReveal(theme)
            case .card(let card):
                ShowcaseCard(card: card).frame(width: 176, height: 236)
            case .avatar(let a):
                cosmeticReveal(headline: L("NEUER AVATAR!"), name: a.name, rarity: a.rarity) {
                    PlayerAvatar(size: 160, frame: AvatarFrame.none, avatar: a)
                }
            case .frame(let f):
                cosmeticReveal(headline: L("NEUER RAHMEN!"), name: f.name, rarity: f.rarity) {
                    PlayerAvatar(size: 160, frame: f)
                }
            case .title(let t):
                let rarity = ChestTitle.all.first { $0.title == t }?.rarity ?? .common
                cosmeticReveal(headline: L("NEUER TITEL!"), name: L(t), rarity: rarity) {
                    Text(L(t).uppercased())
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(2)
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 22)
                        .frame(height: 64)
                        .background(Capsule().fill(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom)))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 2))
                        .shadow(color: Theme.gold.opacity(0.7), radius: 16)
                        .frame(height: 160)
                }
            }
            if remaining > 0 {
                Text(L("noch {0}", remaining))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textMuted)
                    .padding(.horizontal, 12)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        .scaleEffect(pop ? 1 : 0.85)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { pop = true }
            switch reward {
            case .xp(let n), .shards(let n), .jackpot(let n):
                shown = 0
                withAnimation(.easeOut(duration: 0.7).delay(0.15)) { shown = n }
            default: break
            }
            foreverAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func amountCard(icon: AnyView, color: Color, value: Int, label: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 150, height: 150)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                Circle().strokeBorder(color.opacity(0.35), lineWidth: 2).frame(width: 150, height: 150)
                icon.shadow(color: color.opacity(0.8), radius: 16)
            }
            Text("+\(shown)")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .monospacedDigit()
                .shadow(color: color.opacity(0.6), radius: 8)
            Text(label.uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundColor(color)
        }
    }

    private func cosmeticReveal<C: View>(headline: String, name: String, rarity: CosmeticRarity, @ViewBuilder art: () -> C) -> some View {
        let tint = Color(hex: rarity.colorHex)
        return VStack(spacing: 12) {
            Text(headline)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                .shadow(color: Theme.gold.opacity(0.6), radius: 10)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.5), .clear], center: .center, startRadius: 4, endRadius: 120))
                    .frame(width: 230, height: 230)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                art()
            }
            Text(rarity.name.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundColor(tint)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(Capsule().fill(tint.opacity(0.18)))
            Text(name)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(L("Im Profil: Tipp auf deinen Avatar."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func boardReveal(_ theme: BoardTheme) -> some View {
        let colors = BoardColors.forTheme(theme)
        return VStack(spacing: 12) {
            Text(L("NEUES BRETT!"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { c in
                            Rectangle().fill((r + c) % 2 == 0 ? colors.light : colors.dark)
                        }
                    }
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Theme.gold.opacity(pulse ? 0.8 : 0.3), radius: 18)
            Text(theme.name)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(L("Im Profil unter Garderobe → Bretter auswählbar."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

/// Kleine Kachel in der Übersicht.
struct RewardTile: View {
    let reward: ChestReward

    var body: some View {
        HStack(spacing: 10) {
            icon
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(subtitle).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textSecondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(reward.isBig ? Theme.gold.opacity(0.7) : .clear, lineWidth: 1.5))
    }

    @ViewBuilder private var icon: some View {
        switch reward {
        case .xp: Image(systemName: "sparkles").font(.system(size: 22, weight: .black)).foregroundColor(Theme.manaLight)
        case .shards, .jackpot: ShardIcon(size: 22)
        case .card(let c): CardView(card: c, compact: true)
        case .board: Image(systemName: "checkerboard.rectangle").font(.system(size: 22, weight: .black)).foregroundColor(Theme.gold)
        case .avatar(let a): PlayerAvatar(size: 38, frame: AvatarFrame.none, avatar: a)
        case .frame(let f): PlayerAvatar(size: 38, frame: f)
        case .title: Image(systemName: "textformat").font(.system(size: 22, weight: .black)).foregroundColor(Theme.gold)
        }
    }

    private var title: String {
        switch reward {
        case .xp(let n): return L("+{0} XP", n)
        case .shards(let n), .jackpot(let n): return L("+{0} Splitter", n)
        case .card(let c): return c.name
        case .board(let b): return b.name
        case .avatar(let a): return a.name
        case .frame(let f): return f.name
        case .title(let t): return L(t)
        }
    }

    private var subtitle: String {
        switch reward {
        case .xp: return L("Erfahrung")
        case .shards: return L("für den Laden")
        case .jackpot: return L("Sammlung komplett")
        case .card(let c): return L("Neue Karte · {0}", c.tier.name)
        case .board: return L("Neues Brett")
        case .avatar: return L("Neuer Avatar")
        case .frame: return L("Neuer Rahmen")
        case .title: return L("Neuer Titel")
        }
    }
}

// MARK: - Truhen außerhalb der Öffnung

/// Nach Partie oder Puzzle: verdiente Truhen mit „Öffnen“-Knopf.
struct EarnedChestsRow: View {
    let chests: [Chest]
    var onOpen: (() -> Void)?
    @State var bob = false
    /// Die Truhen fallen nacheinander von oben herein und landen mit einem Rumms.
    @State var dropped = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: -10) {
                ForEach(Array(chests.prefix(4).enumerated()), id: \.offset) { i, chest in
                    ChestView(rarity: chest.rarity, size: 46, glow: 0.4)
                        .offset(y: bob ? -3 : 3)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: bob)
                        .offset(y: dropped ? 0 : -260)
                        .rotationEffect(.degrees(dropped ? 0 : (i % 2 == 0 ? -25 : 25)))
                        .scaleEffect(dropped ? 1 : 1.4)
                        .opacity(dropped ? 1 : 0)
                        .animation(.spring(response: 0.42, dampingFraction: 0.5).delay(0.25 + Double(i) * 0.18), value: dropped)
                }
            }
            Text(chests.count == 1 ? L("{0} erhalten!", chests[0].title) : L("{0} Truhen erhalten!", chests.count))
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            if let onOpen {
                Button(action: onOpen) {
                    Label(L("Öffnen"), systemImage: "hand.tap.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 44, textColor: Theme.navy))
                .frame(maxWidth: 220)
            }
        }
        .onAppear {
            dropped = true
            let n = min(chests.count, 4)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                for i in 0..<n {
                    Haptics.shared.play(.chestLand)
                    if i == 0 { SoundPlayer.shared.play(.chestLand) }
                    try? await Task.sleep(nanoseconds: 180_000_000)
                }
                bob = true
            }
        }
    }
}

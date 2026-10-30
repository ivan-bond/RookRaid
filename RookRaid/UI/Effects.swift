import SwiftUI

/// Kleiner deterministischer Zufallsgenerator – Effekte bleiben bei jedem Neuzeichnen gleich.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }

    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

// MARK: - Bausteine

struct Particle {
    let angle: Double
    let distance: Double
    let size: Double
    let spin: Double
    let colorIndex: Int
    let delay: Double
}

/// Partikel fliegen vom Mittelpunkt nach außen und verblassen.
struct ParticleBurst: View {
    let seed: UInt64
    var count: Int = 14
    var colors: [Color]
    var symbol: String? = nil
    var radius: CGFloat
    var size: CGFloat
    var duration: Double = 0.7
    var gravity: CGFloat = 0
    var upward: Bool = false

    @State private var go = false

    private var particles: [Particle] {
        var rng = SeededRandom(seed: seed)
        return (0..<count).map { _ in
            let angle = upward ? rng.range(-Double.pi * 0.85, -Double.pi * 0.15) : rng.range(0, Double.pi * 2)
            return Particle(angle: angle,
                            distance: rng.range(0.45, 1.0),
                            size: rng.range(0.5, 1.15),
                            spin: rng.range(-220, 220),
                            colorIndex: Int(rng.range(0, Double(max(colors.count, 1)) - 0.001)),
                            delay: rng.range(0, 0.08))
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(particles.enumerated()), id: \.offset) { _, p in
                particleView(p)
                    .frame(width: size * CGFloat(p.size), height: size * CGFloat(p.size))
                    .rotationEffect(.degrees(go ? p.spin : 0))
                    .offset(x: go ? dx(p) : 0, y: go ? dy(p) : 0)
                    .scaleEffect(go ? 0.25 : 1)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: duration).delay(p.delay), value: go)
            }
        }
        .onAppear { go = true }
    }

    private func dx(_ p: Particle) -> CGFloat {
        CGFloat(cos(p.angle) * p.distance) * radius
    }

    private func dy(_ p: Particle) -> CGFloat {
        CGFloat(sin(p.angle) * p.distance) * radius + gravity
    }

    @ViewBuilder
    private func particleView(_ p: Particle) -> some View {
        let color = colors.isEmpty ? Color.white : colors[p.colorIndex % colors.count]
        if let symbol {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .foregroundColor(color)
                .shadow(color: color.opacity(0.8), radius: 3)
        } else {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .shadow(color: color.opacity(0.7), radius: 2)
        }
    }
}

/// Expandierender Ring.
struct Shockwave: View {
    var color: Color
    var maxScale: CGFloat = 2.2
    var lineWidth: CGFloat = 4
    var duration: Double = 0.55
    @State private var go = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: go ? 0.5 : lineWidth)
            .scaleEffect(go ? maxScale : 0.3)
            .opacity(go ? 0 : 0.95)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { go = true }
            }
    }
}

/// Kurzes Aufleuchten eines Feldes.
struct SquareFlash: View {
    var color: Color
    var duration: Double = 0.45
    @State private var go = false

    var body: some View {
        Rectangle()
            .fill(color)
            .opacity(go ? 0 : 0.75)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { go = true }
            }
    }
}

/// Zickzack-Blitz von oben bis zum Ziel.
struct LightningShape: Shape {
    let seed: UInt64

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed: seed)
        var path = Path()
        let segments = 9
        path.move(to: CGPoint(x: rect.midX + CGFloat(rng.range(-12, 12)), y: rect.minY))
        for i in 1...segments {
            let y = rect.minY + rect.height * CGFloat(i) / CGFloat(segments)
            let jitter = i == segments ? 0 : CGFloat(rng.range(-1, 1)) * rect.width * 0.45
            path.addLine(to: CGPoint(x: rect.midX + jitter, y: y))
        }
        return path
    }
}

struct LightningStrike: View {
    let seed: UInt64
    let height: CGFloat
    let squareSize: CGFloat
    @State private var drawn = false
    @State private var fade = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LightningShape(seed: seed)
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(Color(hex: 0xFFF59D), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .shadow(color: Color(hex: 0xFFEB3B), radius: 8)
                .shadow(color: .white, radius: 2)
                .frame(width: squareSize * 1.2, height: height)
            LightningShape(seed: seed &+ 7)
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: squareSize * 1.2, height: height)
        }
        .opacity(fade ? 0 : 1)
        .onAppear {
            withAnimation(.easeIn(duration: 0.12)) { drawn = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.22)) { fade = true }
        }
    }
}

/// Schwebender Text (z. B. Fähigkeitsname).
struct FloatingLabel: View {
    let text: String
    var color: Color = .white
    var icon: String? = nil
    @State private var go = false

    var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.system(size: 13, weight: .heavy, design: .rounded))
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.92)))
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        .fixedSize()
        .offset(y: go ? -38 : -8)
        .opacity(go ? 0 : 1)
        .scaleEffect(go ? 1.05 : 0.7)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { go = true }
        }
    }
}

// MARK: - Effekt-Auswahl

struct EffectView: View {
    let effect: BoardEffect
    let squareSize: CGFloat
    /// Abstand vom oberen Brettrand bis zur Feldmitte (für den Blitz).
    let distanceFromTop: CGFloat

    var body: some View {
        let s = squareSize
        ZStack {
            switch effect.kind {
            case .capture:
                SquareFlash(color: Color(hex: 0xFF7043).opacity(0.7))
                    .frame(width: s, height: s)
                Shockwave(color: .white, maxScale: 1.6, lineWidth: 3)
                    .frame(width: s, height: s)
                ParticleBurst(seed: effect.seed, count: 14,
                              colors: [Color(hex: 0xFFB74D), Color(hex: 0xFF7043), .white, Color(hex: 0x8D6E63)],
                              radius: s * 1.1, size: s * 0.14)

            case .bigCapture:
                SquareFlash(color: Color(hex: 0xFF5252))
                    .frame(width: s, height: s)
                Shockwave(color: Color(hex: 0xFFD54F), maxScale: 2.8, lineWidth: 6, duration: 0.7)
                    .frame(width: s, height: s)
                ParticleBurst(seed: effect.seed, count: 24,
                              colors: [Color(hex: 0xFFD54F), Color(hex: 0xFF7043), .white, Color(hex: 0xE53935)],
                              radius: s * 1.8, size: s * 0.16, duration: 0.9)
                ParticleBurst(seed: effect.seed &+ 3, count: 8, colors: [Color(hex: 0xFFF59D)], symbol: "star.fill",
                              radius: s * 1.3, size: s * 0.22, duration: 0.9)

            case .frost:
                SquareFlash(color: Color(hex: 0x81D4FA), duration: 0.8)
                    .frame(width: s, height: s)
                Shockwave(color: Color(hex: 0xB3E5FC), maxScale: 2.0, lineWidth: 5, duration: 0.7)
                    .frame(width: s, height: s)
                ParticleBurst(seed: effect.seed, count: 12, colors: [.white, Color(hex: 0x81D4FA), Color(hex: 0x4FC3F7)],
                              symbol: "snowflake", radius: s * 1.2, size: s * 0.26, duration: 1.0)

            case .iceWave:
                Shockwave(color: Color(hex: 0xE1F5FE), maxScale: 9, lineWidth: 10, duration: 1.1)
                    .frame(width: s, height: s)
                Shockwave(color: Color(hex: 0x81D4FA), maxScale: 6, lineWidth: 6, duration: 0.9)
                    .frame(width: s, height: s)

            case .shield:
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0x64B5F6).opacity(0.0), Color(hex: 0x2196F3).opacity(0.55)],
                                         center: .center, startRadius: 2, endRadius: s * 0.55))
                    .frame(width: s * 0.95, height: s * 0.95)
                    .modifier(PopFade(duration: 0.8))
                Shockwave(color: Color(hex: 0x90CAF9), maxScale: 1.7, lineWidth: 4)
                    .frame(width: s, height: s)

            case .lightning:
                LightningStrike(seed: effect.seed, height: distanceFromTop + s * 0.5, squareSize: s)
                    .frame(width: s * 1.2, height: distanceFromTop + s * 0.5)
                    .offset(y: -(distanceFromTop + s * 0.5) / 2)
                SquareFlash(color: .white, duration: 0.5)
                    .frame(width: s, height: s)
                ParticleBurst(seed: effect.seed, count: 18, colors: [Color(hex: 0xFFF59D), .white, Color(hex: 0xFFCA28)],
                              radius: s * 1.4, size: s * 0.13, duration: 0.7)

            case .meteor:
                MeteorFall(height: distanceFromTop + s * 0.5, size: s)
                    .frame(width: s, height: distanceFromTop + s * 0.5)
                    .offset(y: -(distanceFromTop + s * 0.5) / 2)
                SquareFlash(color: Color(hex: 0xFF6F00), duration: 0.9)
                    .frame(width: s, height: s)
                Shockwave(color: Color(hex: 0xFFAB40), maxScale: 3.6, lineWidth: 8, duration: 0.9)
                    .frame(width: s, height: s)
                ParticleBurst(seed: effect.seed, count: 26, colors: [Color(hex: 0xFF6F00), Color(hex: 0xFFCA28), Color(hex: 0x5D4037)],
                              symbol: "flame.fill", radius: s * 2.0, size: s * 0.24, duration: 1.1)

            case .sparkle, .promotion:
                ParticleBurst(seed: effect.seed, count: effect.kind == .promotion ? 16 : 10,
                              colors: [Color(hex: 0xFFD54F), .white, Color(hex: 0xFFF59D)], symbol: "sparkle",
                              radius: s * 1.0, size: s * 0.26, duration: 0.9)
                Shockwave(color: Color(hex: 0xFFE082), maxScale: 1.8, lineWidth: 3)
                    .frame(width: s, height: s)
                if effect.kind == .promotion {
                    FloatingLabel(text: L("Dame!"), color: Color(hex: 0xC9A227), icon: "crown.fill")
                }

            case .smoke:
                ParticleBurst(seed: effect.seed, count: 12, colors: [Color(white: 0.85), Color(white: 0.65), Color(white: 0.5)],
                              symbol: "circle.fill", radius: s * 0.75, size: s * 0.3, duration: 0.9)

            case .revive:
                SquareFlash(color: Color(hex: 0xFFF9C4), duration: 0.8)
                    .frame(width: s, height: s)
                ParticleBurst(seed: effect.seed, count: 14, colors: [Color(hex: 0xFFF59D), .white],
                              symbol: "sparkle", radius: s * 1.0, size: s * 0.22, duration: 1.0, upward: true)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Feuerball, der von oben auf das Feld stürzt.
struct MeteorFall: View {
    let height: CGFloat
    let size: CGFloat
    @State private var fall = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: 0xFFCA28), Color(hex: 0xFF6F00), .clear],
                                     center: .center, startRadius: 1, endRadius: size * 0.45))
                .frame(width: size * 0.9, height: size * 0.9)
                .shadow(color: Color(hex: 0xFF6F00), radius: 12)
                .offset(y: fall ? height / 2 - size * 0.5 : -height / 2)
                .opacity(fall ? 0 : 1)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.35)) { fall = true }
        }
    }
}

struct PopFade: ViewModifier {
    var duration: Double
    @State private var go = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(go ? 1.25 : 0.4)
            .opacity(go ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: duration)) { go = true }
            }
    }
}

struct SpinFade: ViewModifier {
    @State private var go = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(go ? 360 : 0))
            .opacity(go ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) { go = true }
            }
    }
}

/// Dürfen Dauer-Animationen laufen? Aus für Tabs, die gerade nicht zu sehen sind, und solange eine Partie oder
/// ein Puzzle im Vollbild offen ist – dann zeichnen die versteckten Seiten keine Bilder mehr (spart Akku und
/// hält die Partie flüssig). Alle zeitgesteuerten Effekte halten an, wenn der Wert `false` ist.
private struct LiveAnimationsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var liveAnimations: Bool {
        get { self[LiveAnimationsKey.self] }
        set { self[LiveAnimationsKey.self] = newValue }
    }
}

/// Bildschirmwackeln bei großen Treffern.
/// Wackeln beim Kartentausch. Der Winkel wird aus der Uhrzeit berechnet statt über eine
/// Endlos-Animation: `active = false` pausiert die Zeitleiste und stellt die Karte sofort gerade.
struct Jiggle: ViewModifier {
    @Environment(\.liveAnimations) private var live
    let active: Bool
    var amplitude: Double = 2.5
    var period: Double = 0.28
    var phase: Double = 0

    func body(content: Content) -> some View {
        // Höchstens 60 (schnelles Zittern) bzw. 30 Bilder pro Sekunde statt bis zu 120 auf ProMotion-Displays (v0.9.25)
        TimelineView(.animation(minimumInterval: period < 0.4 ? 1.0 / 60 : 1.0 / 30, paused: !active || !live)) { ctx in
            content.rotationEffect(.degrees(active && live ? angle(at: ctx.date) : 0))
        }
    }

    private func angle(at date: Date) -> Double {
        sin(date.timeIntervalSinceReferenceDate * 2 * .pi / period + phase) * amplitude
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes * 2), y: 0))
    }
}

/// Konfetti für Siege. Alle Schnipsel werden in einem einzigen Canvas gezeichnet (statt 70 einzelner Ansichten
/// mit je eigener Animation) – sie flattern dabei sogar (Breite schwingt mit der Drehung) und kosten kaum Leistung.
struct ConfettiView: View {
    let seed: UInt64
    @State private var start = Date()
    @State private var finished = false

    private static let total: Double = 3.6

    var body: some View {
        GeometryReader { geo in
            let pieces = makePieces(width: geo.size.width)
            TimelineView(.animation(minimumInterval: nil, paused: finished)) { tl in
                Canvas { ctx, size in
                    let t = tl.date.timeIntervalSince(start)
                    for p in pieces {
                        let local = (t - p.delay) / p.duration
                        guard local > 0, local < 1 else { continue }
                        let eased = local * local          // wie easeIn: erst langsam, dann schneller
                        let y = -20 - p.startOffset + (size.height + 60 + p.startOffset) * eased
                        let x = p.x + p.drift * local
                        let angle = Angle.degrees(p.spin * local)
                        var c = ctx
                        c.translateBy(x: x, y: y)
                        c.rotate(by: angle)
                        c.scaleBy(x: max(0.15, abs(cos(angle.radians * 1.7 + p.phase))), y: 1)
                        c.fill(Path(roundedRect: CGRect(x: -p.w / 2, y: -p.h / 2, width: p.w, height: p.h), cornerRadius: 1.5),
                               with: .color(p.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(ConfettiView.total * 1_000_000_000))
                finished = true
            }
        }
    }

    private struct ConfettiPiece {
        let x: CGFloat, drift: CGFloat, w: CGFloat, h: CGFloat, spin: Double, phase: Double
        let duration: Double, delay: Double, startOffset: CGFloat, color: Color
    }

    private func makePieces(width: CGFloat) -> [ConfettiPiece] {
        var rng = SeededRandom(seed: seed)
        let palette = [Theme.green, Theme.gold, Theme.mana, Color(hex: 0x4FC3F7), Color(hex: 0xFF7043), .white]
        return (0..<90).map { _ in
            ConfettiPiece(x: CGFloat(rng.range(0, Double(width))),
                          drift: CGFloat(rng.range(-60, 60)),
                          w: CGFloat(rng.range(6, 10)),
                          h: CGFloat(rng.range(10, 16)),
                          spin: rng.range(-720, 720),
                          phase: rng.range(0, 3.14),
                          duration: rng.range(1.6, 2.8),
                          delay: rng.range(0, 0.6),
                          startOffset: CGFloat(rng.range(0, 120)),
                          color: palette[Int(rng.range(0, Double(palette.count) - 0.001))])
        }
    }
}


/// Startet eine Endlos-Animation (Pulsieren, Wippen) einen Augenblick nach dem Erscheinen.
/// So landet sie nicht in derselben Transaktion wie das Layout eines gerade geöffneten Fensters –
/// sonst wackelt das ganze Fenster mit.
@MainActor
func foreverAnimation(_ animation: Animation, _ change: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        try? await Task.sleep(nanoseconds: 60_000_000)
        withAnimation(animation) { change() }
    }
}


/// Zwischenspeicher für fertig gezeichnete, unbewegte Grafiken (kleine Truhen, Avatare).
/// Aufwendige Vektorgrafik mit Weichzeichnern wird so nur einmal pro Größe gerendert.
@MainActor
final class RenderCache {
    static let shared = RenderCache()
    private var images: [String: UIImage] = [:]

    func image<Content: View>(key: String, size: CGSize, scale: CGFloat, @ViewBuilder content: () -> Content) -> UIImage? {
        if let cached = images[key] { return cached }
        guard size.width >= 1, size.height >= 1 else { return nil }
        let renderer = ImageRenderer(content: content().frame(width: size.width, height: size.height))
        renderer.scale = max(1, scale)
        renderer.isOpaque = false
        guard let image = renderer.uiImage else { return nil }
        if images.count > 300 { images.removeAll() }
        images[key] = image
        return image
    }
}

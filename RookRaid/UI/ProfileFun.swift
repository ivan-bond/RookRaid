import SwiftUI

// MARK: - Shared decorations (twinkling stars, ribbon)

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

// MARK: - Bot-Bezwinger

// MARK: - Sammlung

// MARK: - Form


import SwiftUI

struct PieceItem: Identifiable {
    let id: UUID
    let square: Square
    let piece: Piece
}

/// Minimalistisches Brett: zwei Feldfarben, Gebiet als sanfter Farbton, neutrale Markierungen.
struct BoardView: View {
    @ObservedObject var vm: GameViewModel
    /// Nur Einstellungen werden gelesen (die ändern sich während der Partie nicht). Nicht beobachtet:
    /// Sonst würde jedes Speichern im Profil (Zähler, Erfolge) das ganze Brett neu aufbauen.
    private var store: ProfileStore { ProfileStore.shared }

    @State var dragFrom: Square?
    @State var dragLocation: CGPoint?
    @State var dragging = false
    @State var finisherZoom = false
    @State var kingToppled = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let s = side / 8
            let colors = BoardColors.forTheme(store.profile.settings.boardTheme)

            ZStack(alignment: .topLeading) {
                squaresLayer(s, colors)
                markersLayer(s)
                piecesLayer(s)
                dotsLayer(s)
                effectsLayer(s)
            }
            .frame(width: side, height: side)
            .scaleEffect(finisherZoom ? 1.7 : 1, anchor: finisherAnchor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(finisherVignette)
            .contentShape(Rectangle())
            .gesture(boardGesture(s))
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: vm.finisher) { f in
            if f != nil {
                withAnimation(.easeInOut(duration: 1.1)) { finisherZoom = true }
                withAnimation(.easeIn(duration: 0.5).delay(1.0)) { kingToppled = true }
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    finisherZoom = false
                    kingToppled = false
                }
            }
        }
    }

    // MARK: Koordinaten

    private func point(_ sq: Square, _ s: CGFloat) -> CGPoint {
        let r = vm.flipped ? 7 - sq.row : sq.row
        let c = vm.flipped ? 7 - sq.col : sq.col
        return CGPoint(x: (CGFloat(c) + 0.5) * s, y: (CGFloat(r) + 0.5) * s)
    }

    private func square(at p: CGPoint, _ s: CGFloat) -> Square? {
        guard p.x >= 0, p.y >= 0 else { return nil }
        let c = Int(p.x / s)
        let r = Int(p.y / s)
        guard (0..<8).contains(c), (0..<8).contains(r) else { return nil }
        return vm.flipped ? Square(row: 7 - r, col: 7 - c) : Square(row: r, col: c)
    }

    // MARK: Ebenen

    /// Felder inklusive Gebiet als Farbton: eigenes Gebiet heller und frischer, gegnerisches gedeckter.
    private func squaresLayer(_ s: CGFloat, _ colors: BoardColors) -> some View {
        let showCoords = store.profile.settings.showCoordinates
        let showTerritory = store.profile.settings.showTerritory
        let me = vm.perspective
        return ZStack(alignment: .topLeading) {
            ForEach(GameState.allSquares, id: \.self) { sq in
                let light = sq.isLight
                let highlighted = vm.isLastMoveSquare(sq) || vm.selected == sq
                let owner: PlayerColor? = showTerritory ? vm.control[sq.index] : nil
                let mine: Bool? = owner.map { $0 == me }
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(colors.color(light: light, mine: mine))
                    if highlighted {
                        Rectangle().fill(Color(hex: 0xF6D65A).opacity(0.45))
                    }
                    if showCoords {
                        coordinateLabels(sq, s, light ? colors.dark : colors.light)
                    }
                }
                .frame(width: s, height: s)
                .position(point(sq, s))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.control)
        // 64 Felder als eine einzige Metal-Ebene zusammensetzen statt 64 einzelner Ebenen
        .drawingGroup()
    }

    @ViewBuilder
    private func coordinateLabels(_ sq: Square, _ s: CGFloat, _ color: Color) -> some View {
        let displayCol = vm.flipped ? 7 - sq.col : sq.col
        let displayRow = vm.flipped ? 7 - sq.row : sq.row
        ZStack {
            if displayCol == 0 {
                Text("\(8 - sq.row)")
                    .font(.system(size: s * 0.18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, s * 0.05)
                    .padding(.top, s * 0.02)
            }
            if displayRow == 7 {
                Text(Square.files[sq.col])
                    .font(.system(size: s * 0.18, weight: .semibold))
                    .foregroundColor(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, s * 0.05)
                    .padding(.bottom, s * 0.01)
            }
        }
        .frame(width: s, height: s)
    }

    private func markersLayer(_ s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if let k = vm.checkedKing {
                RadialGradient(colors: [Color.red.opacity(0.85), Color.red.opacity(0.25), .clear],
                               center: .center, startRadius: 1, endRadius: s * 0.7)
                    .frame(width: s, height: s)
                    .position(point(k, s))
            }
            // Tutorial: goldene, pulsierende Markierung
            ForEach(vm.tutorialSquares, id: \.self) { sq in
                TutorialPulse(size: s)
                    .frame(width: s, height: s)
                    .position(point(sq, s))
            }
            // Mögliche Ziele für Karte oder Ultimate: schlichter weißer Rahmen
            ForEach(Array(vm.cardTargets), id: \.self) { sq in
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.white.opacity(0.95), lineWidth: max(2, s * 0.06))
                    .frame(width: s, height: s)
                    .position(point(sq, s))
            }
        }
        .allowsHitTesting(false)
    }

    private func piecesLayer(_ s: CGFloat) -> some View {
        let items: [PieceItem] = GameState.allSquares.compactMap { sq in
            guard let p = vm.state[sq] else { return nil }
            return PieceItem(id: p.id, square: sq, piece: p)
        }
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                let isDragged = dragging && dragFrom == item.square
                let topples = kingToppled && vm.finisher?.square == item.square
                PieceSprite(piece: item.piece, ply: vm.state.ply, size: s, locked: vm.state.isBonusLocked(item.square),
                            skin: vm.skin(for: item.piece.color))
                    .frame(width: s, height: s)
                    .rotationEffect(.degrees(topples ? 82 : 0), anchor: .bottom)
                    .offset(x: topples ? s * 0.2 : 0)
                    .saturation(topples ? 0.2 : 1)
                    .scaleEffect(isDragged ? 1.2 : 1)
                    .shadow(color: .black.opacity(isDragged ? 0.35 : 0), radius: isDragged ? 6 : 0, y: isDragged ? 6 : 0)
                    .position(isDragged ? (dragLocation ?? point(item.square, s)) : point(item.square, s))
                    .zIndex(isDragged ? 10 : 1)
                    .animation(isDragged ? nil : .easeOut(duration: 0.2), value: item.square)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }

    private func dotsLayer(_ s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(vm.legalMoves.enumerated()), id: \.offset) { _, m in
                Group {
                    if vm.state[m.to] != nil || m.isEnPassant {
                        Circle()
                            .strokeBorder(Color.black.opacity(0.2), lineWidth: s * 0.09)
                    } else {
                        Circle()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: s * 0.3, height: s * 0.3)
                    }
                }
                .frame(width: s, height: s)
                .position(point(m.to, s))
            }
        }
        .allowsHitTesting(false)
    }

    private func effectsLayer(_ s: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(vm.effects) { e in
                let p = point(e.square, s)
                EffectView(effect: e, squareSize: s, distanceFromTop: p.y)
                    .frame(width: s, height: s)
                    .position(p)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Finisher-Kamera

    private var finisherAnchor: UnitPoint {
        guard let f = vm.finisher else { return .center }
        let r = vm.flipped ? 7 - f.square.row : f.square.row
        let c = vm.flipped ? 7 - f.square.col : f.square.col
        return UnitPoint(x: (Double(c) + 0.5) / 8, y: (Double(r) + 0.5) / 8)
    }

    @ViewBuilder
    private var finisherVignette: some View {
        if vm.finisher != nil {
            RadialGradient(colors: [.clear, Color.black.opacity(finisherZoom ? 0.75 : 0)],
                           center: .center, startRadius: 40, endRadius: 260)
                .allowsHitTesting(false)
        }
    }

    // MARK: Gesten (Tippen und Ziehen)

    private func boardGesture(_ s: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                if dragFrom == nil { dragFrom = square(at: v.startLocation, s) }
                guard let from = dragFrom else { return }
                let distance = hypot(v.translation.width, v.translation.height)
                if !dragging && distance > 8 && vm.canDrag(from: from) {
                    dragging = true
                    vm.beginDrag(at: from)
                }
                if dragging { dragLocation = v.location }
            }
            .onEnded { v in
                if dragging, let from = dragFrom {
                    if let to = square(at: v.location, s) {
                        vm.drop(from: from, to: to)
                    }
                } else if let sq = square(at: v.location, s) {
                    vm.tap(sq)
                }
                dragFrom = nil
                dragging = false
                dragLocation = nil
            }
    }
}

// MARK: - Figur mit Status

struct PieceSprite: View {
    let piece: Piece
    let ply: Int
    let size: CGFloat
    /// Mit Schild geschützt und im laufenden Bonuszug gesperrt.
    var locked = false
    /// Figurenset des Bots (nil = Standardfiguren)
    var skin: BotLevel? = nil

    var body: some View {
        ZStack {
            if piece.isShielded(at: ply) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                    .background(Circle().fill(Color.white.opacity(0.18)))
                    .padding(size * 0.04)
            }

            PieceImage(type: piece.type, color: piece.color, skin: skin)
                .padding(size * 0.03)
                .shadow(color: .black.opacity(0.22), radius: 1, y: 1.5)

            if piece.isFrozen(at: ply) {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(Color(hex: 0xB3E5FC).opacity(0.45))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.12).strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                    .padding(size * 0.06)
            }

            if piece.isShielded(at: ply) || piece.isFrozen(at: ply) {
                Image(systemName: piece.isFrozen(at: ply) ? "snowflake" : "shield.fill")
                    .font(.system(size: size * 0.14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(size * 0.02)
            }

            if locked {
                LockBadge(size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(size * 0.02)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: locked)
    }
}

/// Goldenes Schloss: Diese Figur bleibt im Bonuszug stehen.
struct LockBadge: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size * 0.13, weight: .black))
            .foregroundColor(Theme.navy)
            .frame(width: size * 0.27, height: size * 0.27)
            .background(Circle().fill(Theme.gold))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.2))
            .modifier(Jiggle(active: true, amplitude: 8, period: 1.2))
            .accessibilityLabel(L("Bleibt in diesem Zug stehen"))
    }
}

/// Pulsierender Goldrahmen für das Tutorial.
struct TutorialPulse: View {
    let size: CGFloat

    var body: some View {
        // Über die Uhrzeit statt Endlos-Animation: atmet sanft, ohne zu schwingen
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
            let ph = (sin(tl.date.timeIntervalSinceReferenceDate * 4.5) + 1) / 2
            RoundedRectangle(cornerRadius: size * 0.12)
                .strokeBorder(Theme.gold, lineWidth: max(3, size * 0.08))
                .background(RoundedRectangle(cornerRadius: size * 0.12).fill(Theme.gold.opacity(0.08 + 0.2 * ph)))
                .scaleEffect(0.92 + 0.08 * ph)
        }
    }
}

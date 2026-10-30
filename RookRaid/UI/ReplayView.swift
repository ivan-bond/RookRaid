import SwiftUI

/// Baut aus Ausgangsstellung und Zugliste alle Zwischenstände einer Partie.
enum ReplayTimeline {
    static func build(_ replay: GameReplay) -> [GameState] {
        var s = replay.initial
        s.events = []
        var out = [s]
        for entry in replay.entries {
            guard let action = entry.action else { break }
            // Ältere Wiedergaben (andere Kartenregeln): Seite am Zug an den Eintrag angleichen
            if entry.color != s.current {
                s.ply += 1
                s.bonusActionUsed = false
                s.bonusLockedSquare = nil
            }
            switch action {
            case .move(let m):
                s.makeMove(m)
            case .card(let c, let t):
                let idx = s.decks[s.current]?.hand.firstIndex(of: c) ?? 0
                s.playCard(c, handIndex: idx, target: t)
            case .ultimate(let t):
                s.useUltimate(target: t)
            }
            if let m = entry.manaAfter, m.count == 2 {
                s.mana[.white] = m[0]
                s.mana[.black] = m[1]
            }
            s.events = []
            out.append(s)
        }
        return out
    }
}

/// Partie nachspielen: Brett, Steuerung und vollständige Zugliste mit Karten.
struct ReplayView: View {
    let replay: GameReplay
    @Environment(\.dismiss) private var dismiss
    @State private var timeline: [GameState] = []
    @State private var index = 0
    @State private var playing = false
    @State private var playTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 10) {
                header
                if timeline.isEmpty {
                    Spacer()
                    ProgressView().tint(Theme.textSecondary)
                    Spacer()
                } else {
                    ReplayBoard(state: timeline[index], highlight: highlightSquares,
                                flipped: replay.humanColor == .black, perspective: replay.humanColor)
                        .padding(.horizontal, 8)
                    statusRow
                    controls
                    moveList
                }
            }
        }
        .onAppear {
            if timeline.isEmpty { timeline = ReplayTimeline.build(replay) }
        }
        .onDisappear { playTask?.cancel() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L("Schließen"))
            VStack(alignment: .leading, spacing: 1) {
                Text(replay.title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(replay.subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(replay.date, style: .date)
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
                .padding(.trailing, 12)
        }
        .padding(.horizontal, 4)
    }

    private var currentEntry: MoveEntry? {
        index > 0 && index - 1 < replay.entries.count ? replay.entries[index - 1] : nil
    }

    private var highlightSquares: [Square] {
        guard let action = currentEntry?.action else { return [] }
        switch action {
        case .move(let m): return [m.from, m.to]
        case .card(_, let t), .ultimate(let t): return t.map { [$0] } ?? []
        }
    }

    private var statusRow: some View {
        let s = timeline[index]
        return HStack(spacing: 10) {
            if let e = currentEntry {
                Circle()
                    .fill(e.color == .white ? Theme.cream : Color(hex: 0x1B1A18))
                    .overlay(Circle().strokeBorder(Theme.panelHighlight, lineWidth: 1))
                    .frame(width: 14, height: 14)
                if let card = e.card {
                    Image(systemName: card.icon).foregroundColor(Theme.manaLight)
                } else if e.text.hasPrefix("★") {
                    Image(systemName: "sparkles").foregroundColor(Theme.gold)
                }
                Text(e.text)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
            } else {
                Text(L("Ausgangsstellung"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
            manaChip(.white, s.mana[.white, default: 0])
            manaChip(.black, s.mana[.black, default: 0])
        }
        .padding(.horizontal, 14)
        .frame(height: 30)
    }

    private func manaChip(_ color: PlayerColor, _ mana: Int) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color == .white ? Theme.cream : Color(hex: 0x1B1A18))
                .overlay(Circle().strokeBorder(Theme.panelHighlight, lineWidth: 1))
                .frame(width: 9, height: 9)
            Image(systemName: "drop.fill").font(.system(size: 10)).foregroundColor(Theme.mana)
            Text("\(mana)").font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundColor(Theme.textSecondary)
        }
        .accessibilityLabel(L("{0}: {1} Mana", color.displayName, mana))
    }

    private var controls: some View {
        HStack(spacing: 8) {
            controlButton("backward.end.fill", L("Zum Anfang")) { go(0) }
            controlButton("backward.fill", L("Zurück")) { go(index - 1) }
            Button {
                togglePlay()
            } label: {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 48)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.blue))
            }
            .accessibilityLabel(playing ? L("Pause") : L("Abspielen"))
            controlButton("forward.fill", L("Weiter")) { go(index + 1) }
            controlButton("forward.end.fill", L("Zum Ende")) { go(timeline.count - 1) }
        }
    }

    private func controlButton(_ icon: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 52, height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
        }
        .accessibilityLabel(label)
    }

    private var moveList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(replay.entries.enumerated()), id: \.offset) { i, e in
                        Button {
                            go(i + 1)
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(i / 2 + 1).")
                                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                                    .foregroundColor(Theme.textMuted)
                                    .frame(width: 28, alignment: .trailing)
                                Circle()
                                    .fill(e.color == .white ? Theme.cream : Color(hex: 0x1B1A18))
                                    .overlay(Circle().strokeBorder(Theme.panelHighlight, lineWidth: 1))
                                    .frame(width: 10, height: 10)
                                if let card = e.card {
                                    Label(e.text, systemImage: card.icon)
                                        .foregroundColor(Theme.manaLight)
                                } else if e.text.hasPrefix("★") {
                                    Label(String(e.text.dropFirst(2)), systemImage: "sparkles")
                                        .foregroundColor(Theme.gold)
                                } else {
                                    Text(e.text).foregroundColor(Theme.textPrimary)
                                }
                                Spacer()
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 10)
                            .frame(height: 34)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(index == i + 1 ? Theme.blue.opacity(0.35) : Theme.panelRaised))
                        }
                        .buttonStyle(.plain)
                        .id(i + 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
            .onChange(of: index) { newValue in
                withAnimation { proxy.scrollTo(max(1, newValue), anchor: .center) }
            }
        }
    }

    private func go(_ i: Int) {
        guard !timeline.isEmpty else { return }
        let clamped = min(max(0, i), timeline.count - 1)
        if clamped != index {
            withAnimation(.easeOut(duration: 0.2)) { index = clamped }
            Haptics.shared.play(.tick)
        }
    }

    private func togglePlay() {
        if playing {
            playing = false
            playTask?.cancel()
            return
        }
        if index >= timeline.count - 1 { index = 0 }
        playing = true
        playTask = Task { @MainActor in
            while playing && index < timeline.count - 1 {
                try? await Task.sleep(nanoseconds: 900_000_000)
                if Task.isCancelled { return }
                go(index + 1)
            }
            playing = false
        }
    }
}

/// Schlichtes Brett ohne Eingabe – für die Wiedergabe.
struct ReplayBoard: View {
    let state: GameState
    let highlight: [Square]
    let flipped: Bool
    let perspective: PlayerColor
    @ObservedObject private var store = ProfileStore.shared

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 8
            let colors = BoardColors.forTheme(store.profile.settings.boardTheme)
            let control = store.profile.settings.showTerritory ? state.controlMap() : []
            ZStack(alignment: .topLeading) {
                ForEach(GameState.allSquares, id: \.self) { sq in
                    let owner: PlayerColor? = control.isEmpty ? nil : control[sq.index]
                    ZStack {
                        Rectangle().fill(colors.color(light: sq.isLight, mine: owner.map { $0 == perspective }))
                        if highlight.contains(sq) {
                            Rectangle().fill(Color(hex: 0xF6D65A).opacity(0.45))
                        }
                    }
                    .frame(width: s, height: s)
                    .position(point(sq, s))
                }
                ForEach(GameState.allSquares.filter { state[$0] != nil }, id: \.self) { sq in
                    if let p = state[sq] {
                        PieceSprite(piece: p, ply: state.ply, size: s)
                            .frame(width: s, height: s)
                            .position(point(sq, s))
                    }
                }
            }
            .frame(width: s * 8, height: s * 8)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(L("Brett der Wiedergabe"))
    }

    private func point(_ sq: Square, _ s: CGFloat) -> CGPoint {
        let r = flipped ? 7 - sq.row : sq.row
        let c = flipped ? 7 - sq.col : sq.col
        return CGPoint(x: (CGFloat(c) + 0.5) * s, y: (CGFloat(r) + 0.5) * s)
    }
}

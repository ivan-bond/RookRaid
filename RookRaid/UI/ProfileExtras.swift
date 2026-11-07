import SwiftUI
import Charts

// MARK: - Auswertung

/// Erweiterte Statistik, berechnet aus Profil, Verlauf (letzte 50 Partien) und Wiedergaben (letzte 10).
struct ProfileStats {
    struct BotRecord: Identifiable {
        let level: BotLevel
        let wins: Int
        let losses: Int
        let draws: Int
        var id: String { level.id }
        var games: Int { wins + losses + draws }
    }

    let form: [GameResultKind]
    let currentWinStreak: Int
    let bestWinStreak: Int
    let avgMoves: Double
    let fastestWin: Int?
    let totalCards: Int
    let avgCards: Double
    let mateWins: Int
    let bots: [BotRecord]
    let favoriteCard: (card: CardType, count: Int)?
    let ultimatesFired: Int
    let trophySeries: [Int]
    let activeDays: Int
    let rrSolved: Int
    let rrTotal: Int
    let classicSolved: Int
    let classicTotal: Int
    let achievements: [Achievement]

    @MainActor
    init(store: ProfileStore) {
        let p = store.profile
        let rated = p.history.filter { $0.opponent != "Zu zweit" }

        form = rated.prefix(10).reversed().map(\.result)
        // Zähler aus dem Spielstand: Sie gehen mit dem Konto auf jedes Gerät, App und Browser zeigen dieselben Zahlen.
        currentWinStreak = p.winStreak
        bestWinStreak = max(p.bestWinStreak, p.winStreak)

        let games = p.history
        avgMoves = games.isEmpty ? 0 : Double(games.reduce(0) { $0 + $1.moves }) / Double(games.count)
        fastestWin = rated.filter { $0.result == .win && $0.moves > 0 }.map(\.moves).min()
        let historyCards = games.reduce(0) { $0 + $1.cardsPlayed }
        totalCards = max(p.cardsByType.values.reduce(0, +), historyCards)
        avgCards = games.isEmpty ? 0 : Double(historyCards) / Double(games.count)
        mateWins = p.mateWins

        bots = BotLevel.allCases.map { level in
            let rs = rated.filter { $0.opponent == level.botName }
            return BotRecord(level: level,
                             wins: rs.filter { $0.result == .win }.count,
                             losses: rs.filter { $0.result == .loss }.count,
                             draws: rs.filter { $0.result == .draw }.count)
        }

        if let top = p.cardsByType.compactMap({ k, v in CardType(rawValue: k).map { ($0, v) } }).max(by: { $0.1 < $1.1 }) {
            favoriteCard = (top.0, top.1)
        } else {
            favoriteCard = nil
        }
        ultimatesFired = p.ultimatesUsed

        // Trophäenverlauf rückwärts aus dem aktuellen Stand rekonstruieren
        var t = p.trophies
        var points = [t]
        for r in rated.prefix(40) where r.trophyDelta != 0 {
            t = max(0, t - r.trophyDelta)
            points.append(t)
        }
        trophySeries = points.reversed()

        activeDays = p.activeDays.count
        // Nur Puzzles zählen, die es noch gibt (die Gebiets-Puzzles sind seit v0.9.20 entfernt)
        let solved = Set(p.solvedPuzzles)
        rrSolved = PuzzleCatalog.rookRaid.filter { solved.contains($0.id) }.count
        rrTotal = PuzzleCatalog.rookRaid.count
        classicSolved = PuzzleCatalog.classic.filter { solved.contains($0.id) }.count
        classicTotal = PuzzleCatalog.classic.count

        achievements = store.achievements
    }

    /// Rang-Titel nach Level.
    static func rank(for level: Int) -> String { ProfileStore.rank(for: level) }
}

// MARK: - Kopf

/// Profil-Banner: Avatar mit Level-Ring, Rang, Name, XP-Balken und drei Kennzahlen.
struct ProfileHeroCard: View {
    @ObservedObject var store = ProfileStore.shared
    var onAvatar: (() -> Void)?

    init(onAvatar: (() -> Void)? = nil) { self.onAvatar = onAvatar }

    var body: some View {
        let progress = store.levelProgress
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button { onAvatar?() } label: { avatarStage(progress.fraction) }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityLabel(L("Avatar, Rahmen und Titel ändern"))

                VStack(alignment: .leading, spacing: 6) {
                    // Titel auf einem goldenen Band
                    Text((store.activeTitle ?? ProfileStats.rank(for: store.level)).uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Theme.navy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 14)
                        .frame(height: 20)
                        .background(RibbonShape().fill(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom)))
                    Text(store.profile.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.35), radius: 0, y: 2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.35))
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.mana, Theme.manaLight], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(10, geo.size.width * progress.fraction))
                                .overlay(ShineSweep().clipShape(Capsule()))
                            Text(L("{0} XP", progress.remaining))
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 6)
                        }
                    }
                    .frame(height: 14)
                    Text(L("Level {0} · noch {1} XP bis Level {2}", store.level, progress.remaining, store.level + 1))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            HStack(spacing: 8) {
                keyPill(icon: "trophy.fill", tint: Theme.gold, value: "\(store.profile.trophies)",
                        label: L("Rekord {0}", store.profile.bestTrophies)) {
                    NotificationCenter.default.post(name: .showTrophyRoad, object: nil)
                }
                keyPill(icon: "flame.fill", tint: FlameStyle.lit, value: "\(store.currentStreak)",
                        label: L("Rekord {0}", store.profile.bestStreak)) {
                    NotificationCenter.default.post(name: .showPuzzles, object: nil)
                }
                keyPill(icon: store.arena.icon, tint: Theme.blueLight, value: L("Arena {0}", store.arena.number),
                        label: store.arena.name) {
                    NotificationCenter.default.post(name: .showTrophyRoad, object: nil)
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(colors: [Theme.blueDark, Color(hex: 0x1A2342), Color(hex: 0x4A1E2C)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                TwinkleField(count: 18, colors: [.white, Theme.gold, Theme.blueLight])
                    .opacity(0.6)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(LinearGradient(colors: [Theme.blueLight.opacity(0.7), Color.white.opacity(0.08), Theme.redLight.opacity(0.7)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
    }

    /// Avatar auf einer Bühne: Lichtstrahlen in Blau, Rot und Gold, XP-Ring, Levelabzeichen, Pinsel.
    private func avatarStage(_ fraction: Double) -> some View {
        ZStack {
            LightRays(colors: [Theme.blueLight, Theme.redLight, Theme.gold], count: 12, speed: 0.25)
                .frame(width: 128, height: 128)
                .clipShape(Circle())
                .opacity(0.55)
            Circle()
                .stroke(Color.black.opacity(0.35), lineWidth: 6)
                .frame(width: 104, height: 104)
            Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(LinearGradient(colors: [Theme.manaLight, Theme.mana], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 104, height: 104)
            PlayerAvatar(size: 86)
                .modifier(RoadBob(active: true, amplitude: 2, speed: 2))
            Text("\(store.level)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(Theme.manaText)
                .frame(minWidth: 28, minHeight: 28)
                .background(Circle().fill(LinearGradient(colors: [.white, Theme.manaLight], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(Theme.navy, lineWidth: 2.5))
                .offset(y: 52)
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Theme.blue))
                .overlay(Circle().strokeBorder(Theme.navy, lineWidth: 2))
                .offset(x: 40, y: -38)
        }
        .frame(width: 116, height: 124)
    }

    private func keyPill(icon: String, tint: Color, value: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.play(.select)
            action()
        } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: icon).font(.system(size: 13, weight: .black)).foregroundColor(tint)
                        .shadow(color: tint.opacity(0.7), radius: 4)
                    Text(value)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.28)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }
}

// MARK: - Bilanz

/// Siege, Niederlagen und Remis als Ring, dazu die Form der letzten 10 Partien.
struct BalanceCard: View {
    let profile: Profile
    let stats: ProfileStats
    @State var appear = false

    var body: some View {
        let total = max(1, profile.gamesPlayed)
        let w = Double(profile.wins) / Double(total)
        let l = Double(profile.losses) / Double(total)
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(icon: "chart.pie.fill", title: L("Bilanz"))
            HStack(spacing: 18) {
                ZStack {
                    ZStack {
                        Circle().stroke(Theme.panelHighlight, lineWidth: 12)
                        if profile.gamesPlayed > 0 {
                            Circle()
                                .trim(from: 0, to: appear ? w : 0)
                                .stroke(Theme.blue, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                            Circle()
                                .trim(from: w, to: appear ? w + l : w)
                                .stroke(Theme.red, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                        }
                    }
                    // Ring beginnt oben
                    .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(profile.gamesPlayed > 0 ? String(format: "%.0f%%", profile.winRate * 100) : "–")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text(L("Siegquote"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.textMuted)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 8) {
                    legend(Theme.blue, L("Siege"), profile.wins)
                    legend(Theme.red, L("Niederlagen"), profile.losses)
                    legend(Theme.panelHighlight, L("Remis"), profile.draws)
                    Text(L("{0} Partien insgesamt", profile.gamesPlayed))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L("Form (letzte 10)"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text(L("Siegesserie {0} · Rekord {1}", stats.currentWinStreak, stats.bestWinStreak))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
                HStack(spacing: 5) {
                    ForEach(0..<10, id: \.self) { i in
                        let r = stats.form[safe: i]
                        Text(r.map(letter) ?? "")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(r.map(color) ?? Theme.panel))
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) { appear = true }
        }
    }

    private func letter(_ r: GameResultKind) -> String {
        switch r {
        case .win: return "S"
        case .loss: return "N"
        case .draw: return "R"
        }
    }

    private func color(_ r: GameResultKind) -> Color {
        switch r {
        case .win: return Theme.blue
        case .loss: return Theme.red
        case .draw: return Theme.panelHighlight
        }
    }

    private func legend(_ c: Color, _ label: String, _ value: Int) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Spacer(minLength: 8)
            Text("\(value)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
        }
        .frame(maxWidth: 170)
    }
}

// MARK: - Trophäenverlauf

struct TrophyTrendCard: View {
    let series: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardTitle(icon: "chart.line.uptrend.xyaxis", title: L("Trophäen-Verlauf"))
                Spacer()
                if let first = series.first, let last = series.last, series.count > 1 {
                    let d = last - first
                    Text(d >= 0 ? "+\(d)" : "\(d)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(d >= 0 ? Theme.gold : Theme.redLight)
                }
            }
            if series.count > 1 {
                Chart {
                    ForEach(Array(series.enumerated()), id: \.offset) { i, v in
                        AreaMark(x: .value(L("Partie"), i), y: .value(L("Trophäen"), v))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Theme.gold.opacity(0.35), Theme.gold.opacity(0.02)],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value(L("Partie"), i), y: .value(L("Trophäen"), v))
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .foregroundStyle(Theme.gold)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel().foregroundStyle(Theme.textMuted)
                    }
                }
                .frame(height: 120)
            } else {
                Text(L("Spiele gegen einen Bot – hier wächst dann deine Trophäenkurve."))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }
}

// MARK: - Kennzahlen

struct StatGrid: View {
    let stats: ProfileStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(icon: "square.grid.2x2.fill", title: L("Spielstil"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                StatTile(icon: "flame.fill", tint: FlameStyle.lit, value: "\(stats.currentWinStreak)",
                         label: L("Siegesserie"), detail: L("Rekord {0}", stats.bestWinStreak))
                StatTile(icon: "stopwatch.fill", tint: Theme.blueLight, value: stats.fastestWin.map { "\($0)" } ?? "–",
                         label: L("Schnellster Sieg"), detail: L("Aktionen"))
                StatTile(icon: "arrow.left.arrow.right", tint: Theme.textSecondary,
                         value: stats.avgMoves > 0 ? String(format: "%.0f", stats.avgMoves) : "–",
                         label: L("Ø Aktionen"), detail: L("pro Partie"))
                StatTile(icon: "crown.fill", tint: Theme.gold, value: "\(stats.mateWins)",
                         label: L("Siege durch Matt"), detail: L("gegen Bots"))
                StatTile(icon: "rectangle.stack.fill", tint: Theme.manaLight, value: "\(stats.totalCards)",
                         label: L("Karten gespielt"), detail: String(format: L("Ø %.1f pro Partie"), stats.avgCards))
                StatTile(icon: stats.favoriteCard?.card.icon ?? "questionmark", tint: Theme.blueLight,
                         value: stats.favoriteCard?.card.name ?? "–",
                         label: L("Lieblingskarte"), detail: stats.favoriteCard.map { L("{0}× gespielt", $0.count) } ?? L("noch keine"))
                StatTile(icon: "sparkles", tint: CardStyle.ultimate, value: "\(stats.ultimatesFired)",
                         label: L("Ultimates gezündet"), detail: L("insgesamt"))
                StatTile(icon: "calendar", tint: FlameStyle.glow, value: "\(stats.activeDays)",
                         label: L("Aktive Tage"), detail: L("mit Flamme"))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }
}

struct StatTile: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 9).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
    }
}

// MARK: - Bots

struct BotRecordCard: View {
    let bots: [ProfileStats.BotRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(icon: "cpu", title: L("Gegen die Bots"))
            ForEach(bots) { b in
                HStack(spacing: 10) {
                    BotAvatar(level: b.level, size: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(b.level.displayName)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            TierDots(tier: b.level.tier)
                            Spacer()
                            Text(b.games == 0 ? L("noch nicht gespielt") : "\(b.wins) S · \(b.losses) N · \(b.draws) R")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .foregroundColor(Theme.textSecondary)
                        }
                        GeometryReader { geo in
                            let total = CGFloat(max(1, b.games))
                            HStack(spacing: 2) {
                                if b.games == 0 {
                                    Capsule().fill(Theme.panelHighlight)
                                } else {
                                    if b.wins > 0 { Capsule().fill(Theme.blue).frame(width: geo.size.width * CGFloat(b.wins) / total) }
                                    if b.draws > 0 { Capsule().fill(Theme.panelHighlight).frame(width: geo.size.width * CGFloat(b.draws) / total) }
                                    if b.losses > 0 { Capsule().fill(Theme.red).frame(width: geo.size.width * CGFloat(b.losses) / total) }
                                }
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }
}

// MARK: - Puzzles

struct PuzzleProgressCard: View {
    let stats: ProfileStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(icon: "puzzlepiece.fill", title: L("Puzzles"))
            row(L("Rook Raid"), stats.rrSolved, stats.rrTotal, Theme.gold)
            row(L("Klassisch"), stats.classicSolved, stats.classicTotal, Theme.manaLight)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }

    private func row(_ title: String, _ solved: Int, _ total: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(solved)/\(total)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundColor(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.panel)
                    Capsule().fill(tint)
                        .frame(width: max(6, geo.size.width * CGFloat(solved) / CGFloat(max(1, total))))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Erfolge

/// Überschrift einer Profilkarte.
struct CardTitle: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.blueLight)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Theme.textMuted)
        }
    }
}

/// Kleiner Fortschrittsbalken mit Zahl.
struct ProgressPill: View {
    let fraction: Double
    let text: String

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(Theme.gold).frame(width: max(3, geo.size.width * min(1, max(0, fraction))))
                }
            }
            .frame(height: 4)
            Text(text)
                .font(.system(size: 8, weight: .heavy).monospacedDigit())
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 6)
    }
}

/// Avatar des Spielers mit gewähltem Rahmen. Das Bild ist das gemalte Porträt.
struct PlayerAvatar: View {
    @ObservedObject var store = ProfileStore.shared
    var size: CGFloat = 86
    var pieceColor: PlayerColor = .white
    var frame: AvatarFrame? = nil
    var avatar: Avatar? = nil

    var body: some View {
        let f = frame ?? store.activeFrame
        let a = avatar ?? store.activeAvatar
        let colors = f.colors.map { Color(hex: $0) }
        let ring = size * 0.07
        ZStack {
            AvatarPortrait(avatar: a, pieceColor: pieceColor)
                .frame(width: size - ring * 1.4, height: size - ring * 1.4)
                .clipShape(Circle())
            Circle()
                .strokeBorder(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom), lineWidth: ring)
            if let icon = f.icon {
                Image(systemName: icon)
                    .font(.system(size: size * 0.16, weight: .black))
                    .foregroundColor(Theme.navy)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .background(Circle().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)))
                    .offset(y: -size * 0.48)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: colors.last?.opacity(f == .none ? 0.3 : 0.6) ?? .clear, radius: size * 0.14)
        .accessibilityLabel(L("Avatar {0}", a.name))
    }
}

/// Innenbild eines Avatars (ohne Rahmen), füllt seinen Rahmen quadratisch aus.
struct AvatarPortrait: View {
    let avatar: Avatar
    /// Bleibt für Aufrufer erhalten. Die gemalten Porträts haben keine eigene Figurenfarbe.
    var pieceColor: PlayerColor = .white

    var body: some View {
        Image(avatar.imageName)
            .resizable()
            .scaledToFill()
            .accessibilityHidden(true)
    }
}

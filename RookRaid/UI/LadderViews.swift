import SwiftUI

// MARK: - Bausteine

/// Rundes Bild eines Bot-Charakters in seiner Farbe.
struct BotAvatar: View {
    let level: BotLevel
    var size: CGFloat = 56
    var locked = false

    var body: some View {
        let tint = Color(hex: level.colorHex)
        ZStack {
            Circle().fill(Theme.background.opacity(0.7))
            Circle().fill(tint.opacity(locked ? 0.05 : 0.18))
            Circle().strokeBorder(locked ? Theme.panelHighlight : tint, lineWidth: max(2, size * 0.04))
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            } else {
                // Der Bot zeigt sich mit dem König seines eigenen Figurensets
                PieceImage(type: .king, color: .white, skin: level)
                    .frame(width: size * 0.68, height: size * 0.68)
                    .shadow(color: .black.opacity(0.35), radius: 0, y: size * 0.02)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: locked ? .clear : tint.opacity(0.45), radius: size * 0.14)
    }
}

/// Kleine Balken: Stufe des Bots (einer pro Bot).
struct TierDots: View {
    let tier: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...BotLevel.allCases.count, id: \.self) { i in
                Capsule()
                    .fill(i <= tier ? Theme.gold : Theme.panelHighlight)
                    .frame(width: 5, height: 4)
            }
        }
        .accessibilityLabel(L("Stufe {0} von {1}", tier, BotLevel.allCases.count))
    }
}

// MARK: - Karte auf der Startseite

struct LadderCard: View {
    @ObservedObject var store = ProfileStore.shared
    let onOpen: () -> Void

    var body: some View {
        let beaten = store.profile.ladderBeaten
        let next = store.ladderNext
        Button(action: onOpen) {
            HStack(spacing: 12) {
                if let next {
                    BotAvatar(level: next, size: 56)
                        .modifier(RoadBob(active: true, amplitude: 2, speed: 2.5))
                } else {
                    ZStack {
                        Circle().fill(Theme.gold.opacity(0.2))
                        Image(systemName: "crown.fill").font(.system(size: 22, weight: .bold)).foregroundColor(Theme.gold)
                    }
                    .frame(width: 52, height: 52)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(L("BOT-LEITER"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(Theme.gold)
                        Text("\(beaten)/\(BotLevel.allCases.count)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundColor(Theme.textMuted)
                    }
                    if let next {
                        Text("\(next.displayName) \(next.title)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(L("Besiege sie für +{0} XP und eine Truhe", next.xpFirstWin))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.manaLight)
                    } else {
                        Text(L("Alle Bots besiegt!"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text(L("Revanchen bringen weiter XP"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    HStack(spacing: 3) {
                        ForEach(BotLevel.allCases) { level in
                            Capsule()
                                .fill(level.tier <= beaten ? Color(hex: level.colorHex) : Theme.panelHighlight)
                                .frame(height: 4)
                        }
                    }
                    .padding(.top, 2)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [Color(hex: next?.colorHex ?? 0xF2C14E).opacity(0.32), Theme.panelRaised],
                                         startPoint: .leading, endPoint: .trailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: next?.colorHex ?? 0xF2C14E).opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(next.map { L("Bot-Leiter, nächster Gegner {0}", $0.displayName) } ?? L("Bot-Leiter, alle besiegt"))
    }
}

/// Halbe Kachel auf der Startseite: der nächste Gegner der Leiter mit leuchtendem Ring, Belohnung und einer
/// Treppe aus zwölf Stufen, die Bot für Bot in den Farben der besiegten Charaktere hinaufwächst (v0.9.29).
struct LadderTile: View {
    @ObservedObject var store = ProfileStore.shared
    var compact = false
    let onOpen: () -> Void

    var body: some View {
        let beaten = store.profile.ladderBeaten
        let next = store.ladderNext
        let tint = Color(hex: next?.colorHex ?? 0xF2C14E)
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: compact ? 3 : 4) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.stairs")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Theme.gold)
                    Text(L("BOT-LEITER"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Theme.gold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\(beaten)/\(BotLevel.allCases.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .frame(height: 16)
                        .background(Capsule().fill(Color.black.opacity(0.3)))
                }
                HStack(spacing: 8) {
                    ZStack {
                        // Leuchtender Ring in der Farbe des Gegners
                        Circle()
                            .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: compact ? 26 : 30))
                            .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
                            .modifier(RoadBreathe(active: next != nil, speed: 2.2))
                        if let next {
                            BotAvatar(level: next, size: compact ? 32 : 38)
                                .modifier(RoadBob(active: true, amplitude: 2, speed: 2.5))
                                .overlay(alignment: .bottomTrailing) {
                                    Text("VS")
                                        .font(.system(size: 8, weight: .black, design: .rounded).italic())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 3)
                                        .frame(height: 12)
                                        .background(Capsule().fill(Theme.red))
                                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                                        .offset(x: 4, y: 2)
                                }
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                                .modifier(RoadBob(active: true, amplitude: 2, speed: 2.5))
                        }
                    }
                    .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next?.displayName ?? L("Alle besiegt!"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let next {
                            HStack(spacing: 3) {
                                Text(L("+{0} XP", next.xpFirstWin))
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.manaLight)
                                ChestView(rarity: .silver, size: 14)
                            }
                            .padding(.horizontal, 5)
                            .frame(height: 16)
                            .background(Capsule().fill(Color.black.opacity(0.3)))
                        } else {
                            Text(L("Revanchen bringen weiter XP"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                Spacer(minLength: 0)
                staircase(beaten: beaten)
            }
            .padding(compact ? 9 : 10)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: compact ? 92 : 108)
            .background(
                ZStack {
                    LinearGradient(colors: [tint.opacity(0.42), Theme.panelRaised, Color(hex: 0x1C1530)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    // Schräge Streifen wie auf einem Turnierbanner (einmal gezeichnet)
                    Canvas { ctx, size in
                        var x: CGFloat = -size.height
                        while x < size.width {
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: size.height))
                            path.addLine(to: CGPoint(x: x + size.height, y: 0))
                            path.addLine(to: CGPoint(x: x + size.height + 7, y: 0))
                            path.addLine(to: CGPoint(x: x + 7, y: size.height))
                            path.closeSubpath()
                            ctx.fill(path, with: .color(.white.opacity(0.035)))
                            x += 18
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            )
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(LinearGradient(colors: [tint.opacity(0.85), tint.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(next.map { L("Bot-Leiter, nächster Gegner {0}", $0.displayName) } ?? L("Bot-Leiter, alle besiegt"))
    }

    /// Zwölf Stufen, von links nach rechts höher – besiegte in Bot-Farbe, die nächste golden umrandet, oben die Krone.
    private func staircase(beaten: Int) -> some View {
        let all = BotLevel.allCases
        let maxH: CGFloat = compact ? 10 : 14
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(all.enumerated()), id: \.offset) { i, level in
                let h = maxH * (0.3 + 0.7 * CGFloat(i + 1) / CGFloat(all.count))
                let isNext = level.tier == beaten + 1
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(level.tier <= beaten
                          ? AnyShapeStyle(LinearGradient(colors: [Color(hex: level.colorHex), Color(hex: level.colorHex).opacity(0.6)], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(isNext ? 0.25 : 0.1)))
                    .frame(height: h)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .strokeBorder(Theme.gold, lineWidth: isNext ? 1.2 : 0)
                    )
                    .modifier(PulseGlow(color: Theme.gold, active: isNext, strength: 0.5))
            }
            Image(systemName: "crown.fill")
                .font(.system(size: compact ? 9 : 10, weight: .black))
                .foregroundColor(beaten >= all.count ? Theme.gold : Color.white.opacity(0.25))
                .padding(.leading, 1)
        }
        .frame(height: maxH)
    }
}

// MARK: - Leiter

/// Bot-Leiter (v0.9.29 neu gestaltet): Nachthimmel mit Sternen, oben das Duell „Du gegen den nächsten Bot“ im
/// Scheinwerferlicht, darunter der Turm – zwölf Stockwerke aus Stein, verbunden durch echte Leitern, die golden
/// werden, sobald du hinaufgeklettert bist. Ganz oben thront die Turmkönigin.
struct LadderView: View {
    @ObservedObject var store = ProfileStore.shared
    let onChallenge: (BotLevel) -> Void
    @Environment(\.dismiss) var dismiss
    @State var appear = false

    var body: some View {
        ZStack {
            backdrop
            GeometryReader { geo in
                ScrollViewReader { _ in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            if let next = store.ladderNext {
                                duel(next)
                                    .id("hero")
                            } else {
                                champion
                            }
                            towerTitle
                            tower
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                        // Exakt bildschirmbreit: Leuchten und Pulsieren dürfen überstehen, verschiebbar ist nur noch vertikal.
                        .frame(width: geo.size.width)
                    }
                    .frame(width: geo.size.width)
                    .clipped()
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
        }
    }

    // MARK: Hintergrund

    private var backdrop: some View {
        let tint = Color(hex: store.ladderNext?.colorHex ?? 0xF2C14E)
        return ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1026), Theme.background, Color(hex: 0x1A1230)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [tint.opacity(0.32), .clear], center: .top, startRadius: 10, endRadius: 460)
            TwinkleField(count: 22, colors: [.white, Theme.gold, Theme.blueLight])
                .opacity(0.55)
        }
        .ignoresSafeArea()
    }

    // MARK: Kopf

    private var header: some View {
        let beaten = store.profile.ladderBeaten
        let total = BotLevel.allCases.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                // Fortschrittsring mit Krone
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: appear ? Double(beaten) / Double(total) : 0)
                        .stroke(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -2) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(beaten >= total ? Theme.gold : Theme.textMuted)
                        Text("\(beaten)/\(total)")
                            .font(.system(size: 12, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("BOT-LEITER"))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFE38A)], startPoint: .top, endPoint: .bottom))
                    Text(L("Zwölf Gegner, eine Krone. Keine Trophäen – nur Ehre, XP und Truhen."))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.panelRaised))
                }
                .accessibilityLabel(L("Schließen"))
            }
        }
        .padding(.top, 20)
    }

    // MARK: Duell

    /// Der nächste Gegner: Du links, der Bot rechts im Scheinwerferlicht, dazwischen „VS“; darunter Sprechblase,
    /// Deck, Figurenset und der große Herausfordern-Knopf.
    private func duel(_ level: BotLevel) -> some View {
        let tint = Color(hex: level.colorHex)
        return VStack(spacing: 14) {
            Text(L("NÄCHSTER GEGNER · STUFE {0}", level.tier))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundColor(Theme.navy)
                .padding(.horizontal, 14)
                .frame(height: 22)
                .background(RibbonShape().fill(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom)))
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 4) {
                    PlayerAvatar(size: 64, pieceColor: store.profile.settings.playAsWhite ? .white : .black)
                        .modifier(RoadBob(active: true, amplitude: 2, speed: 2.2))
                    Text(store.profile.name)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
                ZStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                        .opacity(0.35)
                        .rotationEffect(.degrees(14))
                    Text("VS")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Theme.redDark, radius: 0, x: 2, y: 3)
                }
                .frame(width: 56)
                .scaleEffect(appear ? 1 : 0.2)
                VStack(spacing: 4) {
                    ZStack {
                        LightRays(color: tint, count: 10, speed: 0.3)
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .opacity(0.55)
                        Circle()
                            .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: 4, endRadius: 64))
                            .frame(width: 124, height: 124)
                            .modifier(RoadBreathe(active: true, speed: 2.2))
                        BotAvatar(level: level, size: 88)
                            .scaleEffect(appear ? 1 : 0.4)
                            .rotationEffect(.degrees(appear ? 0 : -30))
                            .modifier(RoadBob(active: true, amplitude: 2.5, speed: 2.2, phase: 1.4))
                    }
                    .frame(width: 120, height: 104)
                    Text(level.displayName)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(level.title.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
            // Sprechblase mit dem Motto – zeigt nach oben zum Bot
            Text("„\(level.motto)“")
                .font(.system(size: 13, weight: .semibold))
                .italic()
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
                .overlay(alignment: .topTrailing) {
                    BubbleTail()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 16, height: 9)
                        .offset(x: -64, y: -9)
                }
            deckStrip(level)
            skinStrip(level)
            if store.deckIsFull {
                ChallengeButton(level: level) { onChallenge(level) }
            } else {
                // Ohne volles Deck kein Duell (v0.9.31): direkt zum Deck
                Button {
                    Haptics.shared.play(.select)
                    dismiss()
                    NotificationCenter.default.post(name: .showDeck, object: nil)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.stack.badge.plus")
                        Text(L("Deck fertig bauen ({0}/{1})", store.activeDeck.count, PlayerDeck.size))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.blue, shadow: Theme.blueDark, height: 56, textColor: .white))
            }
        }
        .padding(14)
        .background(
            ZStack {
                LinearGradient(colors: [tint.opacity(0.3), Theme.panelRaised, Color(hex: 0x1C1530)], startPoint: .topLeading, endPoint: .bottomTrailing)
                DiagonalStripes(opacity: 0.035)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
        )
        .overlay(RoundedRectangle(cornerRadius: 22)
            .strokeBorder(LinearGradient(colors: [tint, tint.opacity(0.25)], startPoint: .top, endPoint: .bottom), lineWidth: 2))
        .modifier(PulseGlow(color: tint, active: true, strength: 0.5))
    }

    private var champion: some View {
        VStack(spacing: 10) {
            ZStack {
                LightRays(color: Theme.gold, count: 14, speed: 0.3)
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .opacity(0.6)
                Image(systemName: "crown.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom))
                    .modifier(RoadBob(active: true, amplitude: 3, speed: 2))
                    .modifier(PulseGlow(color: Theme.gold, active: true))
            }
            .frame(height: 140)
            Text(L("Du hast die Leiter bezwungen!"))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            Text(L("Jede Revanche bringt weiter 10 XP."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.gold.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.6), lineWidth: 2))
    }

    private func deckStrip(_ level: BotLevel) -> some View {
        HStack(spacing: 5) {
            CardArtThumb(art: "art-ult-\(level.ultimate.rawValue)", width: 26, border: CardStyle.ultimate)
            ForEach(level.deck) { card in
                CardArtThumb(art: "art-card-\(card.rawValue)", width: 26, border: Color(hex: card.tier.colorHex))
            }
            Text(L("Deck · ") + level.ultimate.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Deck: {0}, ", level.ultimate.name) + level.deck.map(\.name).joined(separator: ", "))
    }

    /// Das Figurenset des Gegners: so sehen seine Figuren auf dem Brett aus.
    private func skinStrip(_ level: BotLevel) -> some View {
        let botColor: PlayerColor = store.profile.settings.playAsWhite ? .black : .white
        return HStack(spacing: 2) {
            ForEach([PieceType.king, .queen, .rook, .bishop, .knight, .pawn], id: \.self) { t in
                PieceImage(type: t, color: botColor, skin: level)
                    .frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(L("FIGURENSET"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.1)
                    .foregroundColor(Color(hex: level.colorHex))
                Text(level.skinName)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, 6)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Figurenset: {0}", level.skinName))
    }

    // MARK: Turm

    private var towerTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundColor(Theme.gold)
            Text(L("Der Turm"))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(L("Ganz oben: die Turmkönigin"))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.top, 4)
    }

    /// Zwölf Stockwerke von oben (Turmkönigin) nach unten (Bruno), dazwischen Leitern.
    private var tower: some View {
        let levels = Array(BotLevel.allCases.reversed())
        return VStack(spacing: 0) {
            // Zinnen oben auf dem Turm
            Battlements(teeth: 9)
                .fill(LinearGradient(colors: [Color(hex: 0x4A4F6A), Color(hex: 0x2C3048)], startPoint: .top, endPoint: .bottom))
                .frame(height: 16)
                .padding(.horizontal, 6)
            ForEach(Array(levels.enumerated()), id: \.element) { i, level in
                floor(level)
                    .id(level)
                if i < levels.count - 1 {
                    // Leiter zum nächsten Stockwerk darunter: golden, wenn du von dort schon hinaufgeklettert bist
                    let below = levels[i + 1]
                    LadderRungs(climbed: store.isLadderBeaten(below))
                        .frame(width: 26, height: 24)
                        .padding(.leading, 27)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(8)
        .background(
            StoneWall()
                .clipShape(RoundedRectangle(cornerRadius: 18))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    /// Ein Stockwerk: besiegt (Fahne in Bot-Farbe, Revanche), aktuell (leuchtet, „DU BIST HIER“) oder gesperrt (Truhe lockt).
    private func floor(_ level: BotLevel) -> some View {
        let beaten = store.isLadderBeaten(level)
        let unlocked = store.isLadderUnlocked(level)
        let current = unlocked && !beaten
        let tint = Color(hex: level.colorHex)
        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if current {
                    Circle()
                        .fill(RadialGradient(colors: [tint.opacity(0.6), .clear], center: .center, startRadius: 2, endRadius: 40))
                        .frame(width: 76, height: 76)
                        .modifier(RoadBreathe(active: true, speed: 2.4))
                }
                BotAvatar(level: level, size: current ? 58 : 48, locked: !unlocked)
                    .modifier(RoadBob(active: current, amplitude: 2, speed: 2.5))
                    .frame(width: 76, height: 64)
                if beaten {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.green))
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                        .offset(x: -8, y: -4)
                }
            }
            .frame(width: 76)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(L("STUFE {0}", level.tier))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundColor(unlocked ? tint : Theme.textMuted)
                    if current {
                        Text(L("DU BIST HIER"))
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(Theme.navy)
                            .padding(.horizontal, 6)
                            .frame(height: 16)
                            .background(Capsule().fill(tint))
                            .modifier(PulseGlow(color: tint, active: true, strength: 0.7))
                    }
                }
                Text(level.displayName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(unlocked ? Theme.textPrimary : Theme.textMuted)
                Text(beaten ? L("Besiegt · Revanche +10 XP") : (current ? L("+{0} XP · {1}", level.xpFirstWin, level.ladderChest.name) : L("Besiege zuerst {0}", BotLevel.allCases[max(0, level.tier - 2)].displayName)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(beaten ? Theme.green : (current ? Theme.manaLight : Theme.textMuted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            if beaten {
                Button { onChallenge(level) } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                        .overlay(Circle().strokeBorder(tint.opacity(0.6), lineWidth: 1.5))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(L("Revanche gegen {0}", level.displayName))
            } else if current && store.deckIsFull {
                Button { onChallenge(level) } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(Theme.navy)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom)))
                        .modifier(Jiggle(active: true, amplitude: 6, period: 1.2))
                        .modifier(PulseGlow(color: Theme.gold, active: true))
                }
                .buttonStyle(PressScaleStyle())
                .accessibilityLabel(L("{0} herausfordern", level.displayName))
            } else {
                ChestView(rarity: level.ladderChest, size: 36)
                    .saturation(0.35)
                    .opacity(0.85)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Theme.panelHighlight))
                            .offset(x: 4, y: -4)
                    }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(current ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.32), Color.black.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.black.opacity(unlocked ? 0.32 : 0.45)))
                // Besiegt: Siegesfahne in der Farbe des Bots am linken Rand
                if beaten {
                    PennantShape()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 10, height: 30)
                        .offset(x: 3)
                }
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(current ? tint : Color.white.opacity(0.06), lineWidth: current ? 2 : 1))
        .opacity(unlocked ? 1 : 0.7)
    }
}

/// Zwei Holme mit Sprossen – golden, wenn du hier schon hinaufgeklettert bist.
struct LadderRungs: View {
    let climbed: Bool

    var body: some View {
        Canvas { ctx, size in
            let color: Color = climbed ? Theme.gold : Color(hex: 0x6B5A44)
            let rail: CGFloat = 3
            ctx.fill(Path(CGRect(x: 0, y: 0, width: rail, height: size.height)), with: .color(color))
            ctx.fill(Path(CGRect(x: size.width - rail, y: 0, width: rail, height: size.height)), with: .color(color))
            var y: CGFloat = 4
            while y < size.height {
                ctx.fill(Path(CGRect(x: rail, y: y, width: size.width - 2 * rail, height: 2.5)), with: .color(color.opacity(0.9)))
                y += 7
            }
        }
        .shadow(color: climbed ? Theme.gold.opacity(0.5) : .clear, radius: 4)
        .accessibilityHidden(true)
    }
}

/// Mauerwerk des Turms (einmal gezeichnet).
struct StoneWall: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A2F45), Color(hex: 0x1D2034)], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                let h: CGFloat = 18, w: CGFloat = 38
                var row = 0
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.35)))
                    var x: CGFloat = row % 2 == 0 ? 0 : -w / 2
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: h)), with: .color(.black.opacity(0.3)))
                        x += w
                    }
                    y += h
                    row += 1
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Schmale Siegesfahne mit Kerbe unten.
struct PennantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.6))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Dreieck (Spitze oben) für Sprechblasen.
struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Schräge Banner-Streifen (einmal gezeichnet).
struct DiagonalStripes: View {
    var opacity: Double = 0.035

    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + 7, y: 0))
                path.addLine(to: CGPoint(x: x + 7, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(.white.opacity(opacity)))
                x += 18
            }
        }
        .accessibilityHidden(true)
    }
}

/// Großer Herausfordern-Knopf der Leiter: oben die Belohnungen als Chips, im Knopf das Gesicht des Gegners.
struct ChallengeButton: View {
    let level: BotLevel
    let action: () -> Void
    @State var glow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles").font(.system(size: 9, weight: .black))
                    Text(L("+{0} XP", level.xpFirstWin)).font(.system(size: 11, weight: .black, design: .rounded))
                }
                .foregroundColor(Theme.manaText)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(Capsule().fill(Theme.manaLight))
                HStack(spacing: 3) {
                    ChestView(rarity: level.ladderChest, size: 20)
                    Text(level.ladderChest.name).font(.system(size: 11, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(.white)
                .padding(.leading, 3)
                .padding(.trailing, 8)
                .frame(height: 22)
                .background(Capsule().fill(level.ladderChest.bodyColor.opacity(0.35)))
                .overlay(Capsule().strokeBorder(level.ladderChest.glowColor.opacity(0.7), lineWidth: 1))
            }
            Button {
                Haptics.shared.play(.chestCharge3)
                action()
            } label: {
                HStack(spacing: 10) {
                    BotAvatar(level: level, size: 34)
                    Text(L("HERAUSFORDERN"))
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .black))
                        .scaleEffect(glow ? 1.15 : 0.95)
                }
                .padding(.leading, 8)
                .padding(.trailing, 16)
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 56, textColor: Theme.navy))
            .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
            .shadow(color: Theme.gold.opacity(glow ? 0.55 : 0.15), radius: glow ? 14 : 6)
            .accessibilityLabel(L("{0} herausfordern. Belohnung {1} XP und {2}", level.displayName, level.xpFirstWin, level.ladderChest.name))
        }
        .onAppear {
            foreverAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

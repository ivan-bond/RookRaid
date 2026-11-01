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

/// Volle Kachel unter dem Kampf: der nächste Gegner der Leiter mit leuchtendem Ring, Belohnung und einer
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: compact ? 26 : 30))
                            .frame(width: compact ? 52 : 58, height: compact ? 52 : 58)
                            .modifier(RoadBreathe(active: next != nil, speed: 2.2))
                        if let next {
                            BotAvatar(level: next, size: compact ? 36 : 42)
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
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                                .modifier(RoadBob(active: true, amplitude: 2, speed: 2.5))
                        }
                    }
                    .frame(width: compact ? 52 : 58, height: compact ? 52 : 58)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.stairs")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(Theme.gold)
                            Text(L("BOT-LEITER"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1.2)
                                .foregroundColor(Theme.gold)
                            Spacer(minLength: 4)
                            Text("\(beaten)/\(BotLevel.allCases.count)")
                                .font(.system(size: 11, weight: .black, design: .rounded).monospacedDigit())
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .frame(height: 18)
                                .background(Capsule().fill(Color.black.opacity(0.3)))
                        }
                        Text(next?.displayName ?? L("Alle besiegt!"))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let next {
                            HStack(spacing: 3) {
                                Text(L("+{0} XP", next.xpFirstWin))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.manaLight)
                                ChestView(rarity: .silver, size: 14)
                            }
                        } else {
                            Text(L("Revanchen bringen weiter XP"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Theme.textMuted)
                }
                staircase(beaten: beaten)
            }
            .padding(compact ? 12 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
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

/// Zwölf Stufen nach oben, im Stil des Trophäenpfads. Bewegt sich nur der nächste Gegner –
/// der Weg darunter ist ein ruhiges Bild.
struct LadderView: View {
    @ObservedObject var store = ProfileStore.shared
    let onChallenge: (BotLevel) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        let tint = Color(hex: store.ladderNext?.colorHex ?? 0xF2C14E)
        ZStack {
            LinearGradient(colors: [tint.opacity(0.42), Theme.background, Theme.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    trail
                    if let next = store.ladderNext {
                        hero(next)
                    } else {
                        champion
                    }
                    ForEach(Array(BotLevel.allCases.reversed())) { level in
                        step(level)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        let beaten = store.profile.ladderBeaten
        let total = BotLevel.allCases.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "figure.stairs")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                    .rotationEffect(.degrees(-12))
                Text(L("BOT-LEITER"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text("\(beaten)/\(total)")
                    .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Capsule().fill(Theme.panelRaised))
                    .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1.5))
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.panelRaised))
                }
                .accessibilityLabel(L("Schließen"))
            }
            Text(L("Zwölf Gegner, eine Krone. Keine Trophäen – nur Ehre, XP und Truhen."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    /// Zwölf Punkte wie die Weltkarte auf dem Pfad: besiegt in Bot-Farbe, die nächste Stufe größer.
    private var trail: some View {
        let next = store.ladderNext
        return HStack(spacing: 0) {
            ForEach(BotLevel.allCases) { level in
                let beaten = store.isLadderBeaten(level)
                let here = level == next
                if level.tier > 1 {
                    Capsule()
                        .fill(beaten ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Color(hex: 0xFFB648)], startPoint: .leading, endPoint: .trailing))
                                     : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(height: 4)
                }
                Circle()
                    .fill(beaten || here ? Color(hex: level.colorHex) : Color.white.opacity(0.14))
                    .frame(width: here ? 18 : 12, height: here ? 18 : 12)
                    .overlay(Circle().strokeBorder(Color.white.opacity(here ? 0.9 : 0), lineWidth: 2))
                    .accessibilityLabel(level.displayName)
            }
        }
        .frame(height: 28)
    }

    private func hero(_ level: BotLevel) -> some View {
        let tint = Color(hex: level.colorHex)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                BotAvatar(level: level, size: 76)
                    .modifier(RoadBob(active: true, amplitude: 2.5, speed: 2.2))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("NÄCHSTER GEGNER · STUFE {0}", level.tier))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundColor(tint)
                    Text(level.displayName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(level.title)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                    Text("„\(level.motto)“")
                        .font(.system(size: 13, weight: .semibold))
                        .italic()
                        .foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                rewardChip(icon: "sparkles", text: L("+{0} XP", level.xpFirstWin), tint: Theme.manaLight)
                HStack(spacing: 4) {
                    ChestView(rarity: level.ladderChest, size: 18)
                    Text(level.ladderChest.name)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(Capsule().fill(Color.black.opacity(0.28)))
            }
            pieces(level)
            if store.deckIsFull {
                Button {
                    Haptics.shared.play(.select)
                    onChallenge(level)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text(L("HERAUSFORDERN"))
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 54, textColor: Theme.navy))
                .accessibilityLabel(L("{0} herausfordern", level.displayName))
            } else {
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
                .buttonStyle(ChunkyButtonStyle(color: Theme.blue, shadow: Theme.blueDark, height: 54, textColor: .white))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [tint.opacity(0.38), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(tint.opacity(0.7), lineWidth: 1.5))
    }

    private func pieces(_ level: BotLevel) -> some View {
        HStack(spacing: 2) {
            ForEach([PieceType.king, .queen, .rook, .bishop, .knight, .pawn], id: \.self) { t in
                PieceImage(type: t, color: .white, skin: level)
                    .frame(width: 26, height: 26)
            }
            Text(level.skinName)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.leading, 6)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Figurenset: {0}", level.skinName))
    }

    private func rewardChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .black))
            Text(text).font(.system(size: 12, weight: .black, design: .rounded))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(Capsule().fill(tint.opacity(0.16)))
    }

    private var champion: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE38A), Theme.gold], startPoint: .top, endPoint: .bottom))
                .modifier(RoadBob(active: true, amplitude: 2.5, speed: 2.2))
            Text(L("Du hast die Leiter bezwungen!"))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(L("Jede Revanche bringt weiter 10 XP."))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.gold.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1.5))
    }

    private func step(_ level: BotLevel) -> some View {
        let beaten = store.isLadderBeaten(level)
        let unlocked = store.isLadderUnlocked(level)
        let current = unlocked && !beaten
        let tint = Color(hex: level.colorHex)
        return Button {
            guard unlocked, store.deckIsFull else { return }
            Haptics.shared.play(.select)
            onChallenge(level)
        } label: {
            HStack(spacing: 12) {
                Capsule()
                    .fill(beaten ? tint : (current ? Theme.gold : Color.white.opacity(0.12)))
                    .frame(width: 5, height: 36)
                BotAvatar(level: level, size: 44, locked: !unlocked)
                VStack(alignment: .leading, spacing: 2) {
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
                                .background(Capsule().fill(Theme.gold))
                        }
                    }
                    Text(level.displayName)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(unlocked ? .white : Theme.textMuted)
                    Text(status(level, beaten: beaten, current: current))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(beaten ? Theme.green : (current ? Theme.manaLight : Theme.textMuted))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 4)
                if beaten {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.green))
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(current ? tint.opacity(0.22) : Theme.panelRaised.opacity(unlocked ? 1 : 0.55))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(current ? Theme.gold.opacity(0.8) : Color.white.opacity(0.06), lineWidth: current ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(beaten ? L("Revanche gegen {0}", level.displayName) : level.displayName)
    }

    private func status(_ level: BotLevel, beaten: Bool, current: Bool) -> String {
        if beaten { return L("Besiegt · Revanche +10 XP") }
        if current { return L("+{0} XP · {1}", level.xpFirstWin, level.ladderChest.name) }
        let previous = BotLevel.allCases[max(0, level.tier - 2)]
        return L("Besiege zuerst {0}", previous.displayName)
    }
}

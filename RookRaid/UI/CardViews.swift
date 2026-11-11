import SwiftUI

struct ManaDrop: View {
    let text: String
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            Image(systemName: "drop.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(LinearGradient(colors: [Theme.manaLight, Theme.mana, Theme.manaDark],
                                                startPoint: .top, endPoint: .bottom))
            Text(text)
                .font(.system(size: size * 0.48, weight: .black, design: .rounded))
                .foregroundColor(Theme.manaText)
                .offset(y: size * 0.12)
                .minimumScaleFactor(0.5)
        }
        .frame(width: size * 0.8, height: size)
    }
}

/// Neutrale Karte – alle Karten sehen gleich aus, nur Symbol, Name und Kosten unterscheiden sich.
struct CardView: View {
    let card: CardType
    var isPlayable: Bool = true
    var isSelected: Bool = false
    var compact: Bool = false
    /// Verbleibende Abklingzeit in eigenen Zügen (0 = bereit).
    var cooldown: Int = 0

    var body: some View {
        let radius: CGFloat = compact ? 6 : 9
        VStack(spacing: compact ? 2 : 3) {
            ZStack(alignment: .topLeading) {
                // Kartenbild (gemalt, Fallback Vektor; Kartenformat 0,8) statt eines Symbols
                CardArtImage(name: "art-card-\(card.rawValue)")
                    .clipShape(RoundedRectangle(cornerRadius: radius))
                    .accessibilityHidden(true)
                // Rahmen in der Seltenheitsfarbe, innen ein feiner heller Rand
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(isSelected ? Color.white : Color(hex: card.tier.colorHex), lineWidth: isSelected ? 2.5 : (compact ? 1.2 : 1.8))
                RoundedRectangle(cornerRadius: max(1, radius - 2))
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                    .padding(compact ? 1.5 : 2.5)
                ManaDrop(text: "\(card.cost)", size: compact ? 16 : 22)
                    .offset(x: compact ? -3 : -5, y: compact ? -4 : -6)
                if card.keepsTurn && !compact {
                    BonusMoveBadge()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(3)
                }
                if cooldown > 0 {
                    CooldownBadge(turns: cooldown, compact: compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .aspectRatio(0.8, contentMode: .fit)

            Text(card.name)
                .font(.system(size: compact ? 8 : 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .opacity(isPlayable || cooldown > 0 ? 1 : 0.4)
        // Hervorhebung ohne Anheben: wächst nach oben nur minimal (Anker unten) und leuchtet –
        // so bleibt die Gebietsleiste darüber frei.
        .scaleEffect(isSelected ? 1.05 : 1, anchor: .bottom)
        .shadow(color: isSelected ? Color.white.opacity(0.55) : .clear, radius: isSelected ? 8 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
    }
}

/// Abklingzeit: dunkle Scheibe mit Sanduhr und der Zahl der Züge, bis die Karte wieder bereit ist.
struct CooldownBadge: View {
    let turns: Int
    var compact = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 6 : 9)
                .fill(Color.black.opacity(0.55))
            VStack(spacing: 0) {
                Image(systemName: "hourglass")
                    .font(.system(size: compact ? 9 : 13, weight: .bold))
                Text("\(turns)")
                    .font(.system(size: compact ? 13 : 20, weight: .black, design: .rounded))
            }
            .foregroundColor(.white)
        }
        .accessibilityLabel(L("Lädt noch {0} {1}", turns, turns == 1 ? L("Zug") : L("Züge")))
    }
}

/// Kennzeichnet Bonusaktionen (Schild, Frost): Nach der Karte bleibt noch ein Figurzug.
struct BonusMoveBadge: View {
    var body: some View {
        HStack(spacing: 1) {
            Image(systemName: "plus")
                .font(.system(size: 7, weight: .black))
            Image(systemName: "figure.walk")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 4)
        .frame(height: 14)
        .background(Capsule().fill(Theme.blue))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 0.8))
        .accessibilityLabel(L("Danach noch ein Figurzug"))
    }
}

/// Hinweis über der Hand, solange nach Schild oder Frost noch der Figurzug aussteht.
struct BonusMoveBanner: View {
    let card: CardType?
    /// Nach der Festung: Bonuszug ohne Schlagen und ohne Schach.
    var peaceful = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: peaceful ? Ultimate.fortress.icon : (card?.icon ?? "sparkles"))
                .font(.system(size: 14, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text(L("{0} aktiv", peaceful ? Ultimate.fortress.name : (card?.name ?? L("Bonus"))))
                    .font(.system(size: 13, weight: .heavy))
                Text(peaceful ? L("Noch ein Zug – ohne Schlagen und ohne Schach")
                     : (card?.locksTarget == true ? L("Noch ein Zug – mit einer anderen Figur") : L("Jetzt noch ein Figurzug")))
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.9)
            }
            Image(systemName: "figure.walk")
                .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Theme.blue))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5))
        .modifier(PulseGlow(color: Theme.blue, active: true))
        .accessibilityElement(children: .combine)
    }
}

/// Die Ultimate – golden hervorgehoben, mit Ladering für den Mana-Balken.
struct UltimateCard: View {
    let ultimate: Ultimate
    let mana: Int
    var usable: Bool = false
    var isSelected: Bool = false
    var compact: Bool = false

    var body: some View {
        let cost = ultimate.cost
        let progress = Double(min(mana, cost)) / Double(cost)
        let full = mana >= cost
        VStack(spacing: compact ? 2 : 3) {
            ZStack {
                // Ladend: Das Bild ist grau und füllt sich mit dem Mana von unten mit Farbe.
                CardArtImage(name: "art-ult-\(ultimate.rawValue)")
                    .saturation(0)
                    .brightness(-0.28)
                CardArtImage(name: "art-ult-\(ultimate.rawValue)")
                    .mask(
                        GeometryReader { g in
                            Rectangle()
                                .frame(height: g.size.height * progress)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    )
                if !full && progress > 0 && progress < 1 {
                    // Füllstand-Kante
                    GeometryReader { g in
                        Rectangle()
                            .fill(Color.white.opacity(0.85))
                            .frame(height: 1.5)
                            .offset(y: g.size.height * (1 - progress))
                    }
                }
                if full {
                    ShineSweep().allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 10))
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 6 : 10)
                    .strokeBorder(isSelected ? Color.white : CardStyle.ultimate, lineWidth: isSelected ? 3 : 2)
            )
            .aspectRatio(0.8, contentMode: .fit)
            .modifier(PulseGlow(color: CardStyle.ultimate, active: usable))
            .accessibilityLabel(ultimate.name)

            Text(full ? ultimate.name : "\(min(mana, cost))/\(cost)")
                .font(.system(size: compact ? 8 : 10, weight: .heavy))
                .foregroundColor(CardStyle.ultimate)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        // Hervorhebung ohne Anheben: wächst nach oben nur minimal (Anker unten) und leuchtet –
        // so bleibt die Gebietsleiste darüber frei.
        .scaleEffect(isSelected ? 1.05 : 1, anchor: .bottom)
        .shadow(color: isSelected ? Color.white.opacity(0.55) : .clear, radius: isSelected ? 8 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .animation(.easeOut(duration: 0.4), value: mana)
    }
}

/// Kartenbild: Gibt es im Asset-Katalog ein gemaltes Bild „painted-<name>“ (Ordner `CardArtPainted`), wird es genommen,
/// sonst das gezeichnete Vektorbild. Füllt den Rahmen (Format 4:5), überstehende Ränder werden beschnitten.
struct CardArtImage: View {
    let name: String
    /// Kleine Darstellung (Leisten, Fächer): verkleinerte Fassung statt des vollen 600 × 750-Bilds (v0.9.25).
    var thumb = false

    var body: some View {
        Color.clear
            .overlay(
                (thumb ? CardArtImage.thumbnail(name) : CardArtImage.image(name))
                    .resizable()
                    .scaledToFill()
            )
            .clipped()
            .accessibilityHidden(true)
    }

    /// Gemalte Bilder werden einmal geladen, dekodiert und gemerkt (nur auf dem Hauptthread gelesen und geschrieben).
    private static var cache: [String: UIImage] = [:]
    private static var thumbs: [String: UIImage] = [:]
    private static var missing: Set<String> = []

    private static func painted(_ name: String) -> UIImage? {
        if let ui = cache[name] { return ui }
        guard !missing.contains(name) else { return nil }
        if let ui = UIImage(named: "painted-" + name) {
            let ready = ui.preparingForDisplay() ?? ui
            cache[name] = ready
            return ready
        }
        missing.insert(name)
        return nil
    }

    static func image(_ name: String) -> Image {
        if let ui = painted(name) { return Image(uiImage: ui) }
        return Image(name)
    }

    /// 180 × 225 Pixel reichen für Bilder bis etwa 60 Punkte Breite.
    static func thumbnail(_ name: String) -> Image {
        if let ui = thumbs[name] { return Image(uiImage: ui) }
        guard let full = painted(name) else { return Image(name) }
        let small = full.preparingThumbnail(of: CGSize(width: 180, height: 225)) ?? full
        thumbs[name] = small
        return Image(uiImage: small)
    }

    /// Alle gemalten Bilder im Hintergrund dekodieren, damit der erste Blick auf Deck, Truhe oder Hand nicht ruckelt.
    @MainActor
    static func preload() async {
        let names = CardType.allCases.map { "art-card-\($0.rawValue)" } + Ultimate.allCases.map { "art-ult-\($0.rawValue)" }
        let todo = names.filter { cache[$0] == nil && !missing.contains($0) }
        guard !todo.isEmpty else { return }
        let decoded: [(String, UIImage?, UIImage?)] = await Task.detached(priority: .utility) {
            todo.map { name -> (String, UIImage?, UIImage?) in
                guard let ui = UIImage(named: "painted-" + name) else { return (name, nil, nil) }
                let full = ui.preparingForDisplay() ?? ui
                return (name, full, full.preparingThumbnail(of: CGSize(width: 180, height: 225)))
            }
        }.value
        for (name, full, small) in decoded {
            guard let full else { missing.insert(name); continue }
            if cache[name] == nil { cache[name] = full }
            if thumbs[name] == nil, let small { thumbs[name] = small }
        }
    }
}

/// Kleines Kartenbild für Leisten (Deck-Vorschau, Leiter).
struct CardArtThumb: View {
    let art: String
    var width: CGFloat = 22
    var border: Color = CardStyle.border

    var body: some View {
        CardArtImage(name: art, thumb: width <= 60)
            .frame(width: width, height: width / 0.8)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.2))
            .overlay(RoundedRectangle(cornerRadius: width * 0.2).strokeBorder(border, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Hervorhebung einer Karte in der ersten Schlacht: Ein Lichtband läuft um den Rand, die Karte hebt sich
/// leicht an und leuchtet, darüber zeigt eine hüpfende Hand mit „Tippen“ – statt des früheren gelben Rechtecks.
struct TutorialSpotlight: ViewModifier {
    let active: Bool
    var cornerRadius: CGFloat = 9

    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let lift = CGFloat((sin(t * 4) + 1) / 2)
                content
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius + 2)
                            .strokeBorder(AngularGradient(gradient: Gradient(colors: [Theme.gold, .white, Theme.blueLight, Theme.gold]),
                                                          center: .center, angle: .degrees(t * 220)),
                                          lineWidth: 3)
                            .padding(-3)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: Theme.gold.opacity(0.45 + 0.4 * Double(lift)), radius: 6 + 8 * lift)
                    .offset(y: -5 * lift)
                    .overlay(alignment: .top) {
                        VStack(spacing: 1) {
                            Text(L("TIPPEN"))
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .tracking(0.8)
                                .foregroundColor(Theme.navy)
                                .padding(.horizontal, 6)
                                .frame(height: 15)
                                .background(Capsule().fill(Theme.gold))
                                .fixedSize()
                            Image(systemName: "hand.point.down.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                        }
                        .offset(y: -42 - 7 * lift)
                        .allowsHitTesting(false)
                    }
            }
        } else {
            content
        }
    }
}

/// Pulsierendes Leuchten (zeitgesteuert – keine Endlos-Animation, die andere Ansichten mitreißt).
struct PulseGlow: ViewModifier {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    let color: Color
    let active: Bool
    var strength: Double = 1

    func body(content: Content) -> some View {
        // Langsames Pulsieren (Periode ≈ 1,8 s): 20 Bilder pro Sekunde reichen – jeder Schattenwechsel kostet einen Weichzeichner-Durchgang.
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !active || !live)) { ctx in
            let phase = active ? (sin(clock.time(ctx.date) * 3.5) + 1) / 2 : 0
            content.shadow(color: color.opacity(active ? (0.35 + 0.6 * phase) * strength : 0), radius: active ? (5 + 9 * phase) * strength : 0)
        }
    }
}

/// Mana-Leiste mit 10 Segmenten und schwebenden Gutschriften (+1 pro Zug, +1 für gute Züge).
struct ManaBar: View {
    let mana: Int
    let income: Int
    let floats: [ManaFloat]
    /// Ab hier ist die eigene Ultimate bereit (die gefüllten Felder leuchten golden).
    var ultimateCost = GameState.ultimateCost
    /// Im Tutorial: die Leiste golden umranden, wenn sie erklärt wird.
    var highlight = false

    var body: some View {
        manaRow
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Theme.gold, lineWidth: 2.5)
                    .padding(-4)
                    .opacity(highlight ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .modifier(PulseGlow(color: Theme.gold, active: highlight))
    }

    private var manaRow: some View {
        HStack(spacing: 8) {
            ManaDrop(text: "\(mana)", size: 28)
            HStack(spacing: 3) {
                // Sobald genug Mana für die Ultimate da ist, leuchten die gefüllten Felder golden
                // (v0.9.34 ohne goldene Umrandung des Ultimate-Felds).
                let ready = mana >= ultimateCost
                ForEach(0..<GameState.maxMana, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(i < mana
                              ? AnyShapeStyle(ready ? AnyShapeStyle(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.mana))
                              : AnyShapeStyle(Theme.panelHighlight))
                        .frame(height: 11)
                }
            }
            // Gutschriften schweben als Überlagerung – sie dürfen die Höhe der Leiste nie verändern,
            // sonst schrumpft das Brett kurz und es wirkt, als würde gezoomt.
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 1) {
                    ForEach(floats) { f in
                        Text("+\(f.amount) \(f.label)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Theme.manaLight)
                            .shadow(color: .black, radius: 1)
                            .fixedSize()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .alignmentGuide(.bottom) { d in d[.bottom] + 15 }
                .allowsHitTesting(false)
            }
            Text(L("+{0}/Zug", income))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .fixedSize()
        }
        .animation(.easeOut(duration: 0.25), value: mana)
    }
}

/// Eigene Hand: Ultimate (hervorgehoben) + 4 Karten + Vorschau.
struct HandView: View {
    @ObservedObject var vm: GameViewModel
    @State var detail: DetailItem?

    var body: some View {
        let owner = vm.handOwner
        let mana = vm.state.mana[owner, default: 0]
        VStack(alignment: .leading, spacing: 11) {
            ManaBar(mana: mana, income: vm.income(for: owner),
                    floats: vm.manaFloats.filter { $0.color == owner },
                    ultimateCost: vm.state.ultimates[owner]?.cost ?? GameState.ultimateCost,
                    highlight: vm.tutorialHighlightTerritory)

            HStack(alignment: .bottom, spacing: 6) {
                if let u = vm.state.ultimates[owner] {
                    UltimateCard(ultimate: u, mana: mana,
                                 usable: vm.canUseUltimate(owner),
                                 isSelected: vm.pendingIsUltimate && vm.state.current == owner)
                        .frame(width: 66)
                        .modifier(TutorialSpotlight(active: vm.tutorialUltimate && !vm.pendingIsUltimate, cornerRadius: 10))
                        .opacity(dimmedInTutorial(isTarget: vm.tutorialUltimate) ? 0.45 : 1)
                        .onTapGesture { vm.tapUltimate() }
                        .onLongPressGesture(minimumDuration: 0.35) { detail = .ultimate(u) }
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1, height: 60)
                        .padding(.bottom, 16)
                }
                if let deck = vm.state.decks[owner] {
                    ForEach(Array(deck.hand.enumerated()), id: \.offset) { idx, card in
                        CardView(card: card,
                                 isPlayable: vm.isCardPlayable(idx, for: owner),
                                 isSelected: vm.pending?.handIndex == idx && vm.state.current == owner,
                                 cooldown: vm.state.cooldownRemaining(card, player: owner))
                            .modifier(TutorialSpotlight(active: vm.tutorialCard == card && vm.pending == nil))
                            .opacity(dimmedInTutorial(isTarget: vm.tutorialCard == card) ? 0.45 : 1)
                            .onTapGesture { vm.tapCard(idx) }
                            .onLongPressGesture(minimumDuration: 0.35) { detail = .card(card) }
                    }
                    // Freie Deckplätze (v0.9.31): Platzhalter halten die Karten gleich groß
                    ForEach(0..<max(0, PlayerDeck.size - deck.hand.count), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .aspectRatio(0.8, contentMode: .fit)
                            .accessibilityHidden(true)
                    }
                }
            }
            .opacity(bonusActive ? 0.45 : 1)
            .overlay {
                if bonusActive {
                    BonusMoveBanner(card: bonusCard, peaceful: vm.state.peacefulBonus)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: bonusActive)

        }
        .sheet(item: $detail) { item in
            DetailSheet(item: item, allowLab: false)
        }
    }

    /// Erste Schlacht: Ist eine Karte oder die Ultimate dran, treten die anderen zurück.
    private func dimmedInTutorial(isTarget: Bool) -> Bool {
        let anyTarget = vm.tutorialCard != nil || vm.tutorialUltimate
        return anyTarget && !isTarget && vm.pending == nil && !vm.pendingIsUltimate
    }

    private var bonusActive: Bool {
        vm.state.bonusActionUsed && vm.state.current == vm.handOwner && !vm.status.isOver
    }

    /// Die zuletzt gespielte Bonuskarte (für das Banner).
    private var bonusCard: CardType? {
        vm.moves.last(where: { $0.color == vm.state.current })?.card
    }

}

/// Fester Platz direkt unter den Karten für die Hinweis-Blase. Er ist immer gleich hoch – ob leer oder gefüllt –
/// damit nichts verrutscht und die Blase nie Karten oder Brett verdeckt.
struct HintSlot: View {
    @ObservedObject var vm: GameViewModel
    static let height: CGFloat = 62

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if vm.mode != .tutorial, let bubble = hintBubble {
                HintBubble(icon: bubble.icon, text: bubble.text, tint: bubble.tint)
                    .id(bubble.text)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85, anchor: .top).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .frame(height: HintSlot.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: hintBubble?.text)
    }

    /// Nur gewählte Karte/Ultimate (Erklärung + Ziel) oder ein echter Hinweis – sonst bleibt es ruhig.
    private var hintBubble: (icon: String, text: String, tint: Color)? {
        if vm.pendingIsUltimate, let u = vm.state.ultimates[vm.state.current] {
            return (u.icon, u.targetPrompt.isEmpty ? "\(u.name): \(u.description)" : u.targetPrompt, CardStyle.ultimate)
        } else if let card = vm.pendingCard {
            return (card.icon, "\(card.name): " + (card.targetPrompt.isEmpty ? card.description : card.targetPrompt), Theme.blueLight)
        } else if let hint = vm.hint {
            return ("lightbulb.fill", hint, Theme.gold)
        }
        return nil
    }
}

/// Sprechblase unter der Hand: zeigt nach oben auf die Karten.
struct HintBubble: View {
    let icon: String
    let text: String
    var tint: Color = Theme.gold

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.panelRaised)
                .overlay(alignment: .topLeading) {
                    Triangle()
                        .fill(Theme.panelRaised)
                        .frame(width: 14, height: 8)
                        .offset(x: 24, y: -7)
                }
        )
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Offenes Deck des Gegners in seiner Spielerleiste: echte kleine Karten mit Bild, Kosten und Abklingzeit,
/// davor die Ultimate, die sich mit seinem Mana von unten mit Farbe füllt. Antippen zeigt die Karte groß.
struct OpponentHandStrip: View {
    let hand: [CardType]
    let ultimate: Ultimate?
    let mana: Int
    /// Abklingzeit je Karte (gleiche Reihenfolge wie `hand`).
    var cooldowns: [Int] = []
    var cardWidth: CGFloat = 28
    @State var detail: DetailItem?

    var body: some View {
        HStack(spacing: 6) {
            if let ultimate {
                VStack(spacing: 1) {
                    UltimateCard(ultimate: ultimate, mana: mana, usable: mana >= ultimate.cost, compact: true)
                        .frame(width: cardWidth)
                        .allowsHitTesting(false)
                }
                .onTapGesture { detail = .ultimate(ultimate) }
                .accessibilityLabel(L("Ultimate {0}, {1} von {2} Mana", ultimate.name, min(mana, ultimate.cost), ultimate.cost))
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: cardWidth)
            }
            ForEach(Array(hand.enumerated()), id: \.offset) { idx, card in
                let cd = cooldowns.indices.contains(idx) ? cooldowns[idx] : 0
                let ready = cd == 0 && card.cost <= mana
                CardArtThumb(art: "art-card-\(card.rawValue)", width: cardWidth, border: Color(hex: card.tier.colorHex))
                    .saturation(ready ? 1 : 0.35)
                    .opacity(ready ? 1 : 0.7)
                    .overlay(alignment: .topLeading) {
                        ManaDrop(text: "\(card.cost)", size: 15)
                            .offset(x: -4, y: -5)
                    }
                    .overlay {
                        if cd > 0 {
                            ZStack {
                                RoundedRectangle(cornerRadius: cardWidth * 0.2).fill(Color.black.opacity(0.55))
                                VStack(spacing: 0) {
                                    Image(systemName: "hourglass").font(.system(size: 8, weight: .bold))
                                    Text("\(cd)").font(.system(size: 11, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.white)
                            }
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if card.keepsTurn && cd == 0 {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 7, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 13, height: 13)
                                .background(Circle().fill(Theme.blue))
                                .offset(x: 4, y: 3)
                        }
                    }
                    .onTapGesture { detail = .card(card) }
                    .accessibilityLabel(L("{0}, {1} Mana, {2}", card.name, card.cost, card.tier.name) + (cd > 0 ? L(", lädt noch {0}", cd) : ""))
            }
        }
        .padding(.top, 4)
        .sheet(item: $detail) { item in
            DetailSheet(item: item, allowLab: false)
        }
    }
}

/// Großes Symbol, das beim Ausspielen kurz über dem Brett erscheint.
struct CastBannerView: View {
    let banner: CastBanner
    let casterName: String
    @State var appear = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(banner.isUltimate
                          ? AnyShapeStyle(LinearGradient(colors: [CardStyle.ultimateTop, CardStyle.ultimate, CardStyle.ultimateDeep],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(LinearGradient(colors: [CardStyle.faceTop, CardStyle.face], startPoint: .top, endPoint: .bottom)))
                if let art = banner.art {
                    CardArtImage(name: art)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: banner.icon)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(banner.isUltimate ? Color(hex: 0x3B2A00) : .white)
                }
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(banner.isUltimate ? Color.white : CardStyle.border, lineWidth: 2.5)
            }
            .frame(width: 96, height: 120)
            .rotation3DEffect(.degrees(appear ? 0 : 70), axis: (x: 0, y: 1, z: 0))
            .shadow(color: banner.isUltimate ? CardStyle.ultimate : .black.opacity(0.5), radius: appear ? 24 : 0)
            Text("\(casterName): \(banner.title)")
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.black.opacity(0.7)))
        }
        .scaleEffect(appear ? 1 : 0.4)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { appear = true }
        }
        .allowsHitTesting(false)
    }
}

enum DetailItem: Identifiable {
    case card(CardType)
    case ultimate(Ultimate)

    var id: String {
        switch self {
        case .card(let c): return "c-" + c.rawValue
        case .ultimate(let u): return "u-" + u.rawValue
        }
    }
}

struct DetailSheet: View {
    let item: DetailItem
    /// In der laufenden Partie gibt es keinen Ausflug in die Kartenschule.
    var allowLab = true
    @Environment(\.dismiss) var dismiss
    /// Kartenschule für diese Karte öffnen (v0.9.26)
    @State private var lab: LabItem?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    LightRays(color: rayColor, count: 12, speed: 0.25)
                        .frame(width: 300, height: 300)
                        .opacity(0.6)
                    Group {
                        switch item {
                        case .card(let c): CardView(card: c).frame(width: 124)
                        case .ultimate(let u): UltimateCard(ultimate: u, mana: GameState.maxMana).frame(width: 124)
                        }
                    }
                    .shadow(color: rayColor.opacity(0.6), radius: 18)
                }
                .frame(height: 190)
                .clipped()
                .padding(.top, 16)
                Text(title)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textMuted)
                Text(text)
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
                HStack(spacing: 10) {
                    Button(L("Schließen")) { dismiss() }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 50))
                    if allowLab {
                        Button {
                            Haptics.shared.play(.cardWhoosh)
                            lab = labItem
                        } label: {
                            Label(L("Ausprobieren"), systemImage: "play.circle.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 50, textColor: Theme.navy))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
        .presentationDetents([.medium])
        .fullScreenCover(item: $lab) { it in CardLabView(start: it) }
    }

    private var labItem: LabItem {
        switch item {
        case .card(let c): return .card(c)
        case .ultimate(let u): return .ultimate(u)
        }
    }

    private var rayColor: Color {
        switch item {
        case .card(let c): return Color(hex: c.role.colorHex)
        case .ultimate: return CardStyle.ultimate
        }
    }

    private var title: String {
        switch item {
        case .card(let c): return c.name
        case .ultimate(let u): return u.name
        }
    }

    private var subtitle: String {
        switch item {
        case .card(let c): return (c.keepsTurn ? L("Bonusaktion · {0} Mana · danach noch ein Figurzug", c.cost) : L("Zauber · {0} Mana · ersetzt deinen Zug", c.cost)) + " · \(c.role.name)"
        case .ultimate(let u): return L("Ultimate · {0} · {1} Mana", u.style, u.cost)
        }
    }

    private var text: String {
        switch item {
        case .card(let c): return c.description
        case .ultimate(let u): return u.description
        }
    }
}

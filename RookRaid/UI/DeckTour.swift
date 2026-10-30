import SwiftUI

// MARK: - Rockys Deck-Werkstatt (v0.9.32)
//
// Nach der ersten Partie zeigt Rocky Schritt für Schritt, wie man ein Deck baut – zum Mitmachen statt zum Lesen:
// 1. Hallo: Spotlight auf die vier Deckplätze
// 2. Karten antippen, bis das Deck voll ist. Rocky kommentiert jede Karte, ein Rollen-Zähler zeigt den Mix.
// 3. Deck-Check: bis zu drei Sterne für Mana, Rollen-Mix und schnellen Start
// 4. Profi-Trick: eine Karte herausnehmen, eine andere hineinlegen – danach eine neue Wertung
// 5. Spotlight auf die Ultimate
// 6. Feier mit Konfetti (beim ersten Mal mit 20 Splittern)
// Über den Rocky-Knopf im Deck-Tab lässt sich die Tour jederzeit wiederholen.

enum DeckTourStep: Equatable {
    case hello, pick, fill, check, swapOut, swapIn, recheck, ultimate, ultimates, done

    /// Fortschrittspunkte in Rockys Blase
    var progress: Int {
        switch self {
        case .hello: return 0
        case .pick, .fill: return 1
        case .check: return 2
        case .swapOut, .swapIn, .recheck: return 3
        case .ultimate, .ultimates: return 4
        case .done: return 5
        }
    }

    static let progressCount = 5

    /// Schritte, in denen der Spieler selbst Karten antippt (kein Abdunkeln, nichts gesperrt).
    var isHandsOn: Bool {
        switch self {
        case .pick, .fill, .swapOut, .swapIn: return true
        default: return false
        }
    }
}

/// Bereiche des Deck-Tabs, die Rocky ins Scheinwerferlicht rückt.
enum DeckTourTarget: Hashable { case slots, ultimate }

struct DeckTourAnchorKey: PreferenceKey {
    static var defaultValue: [DeckTourTarget: Anchor<CGRect>] = [:]
    static func reduce(value: inout [DeckTourTarget: Anchor<CGRect>], nextValue: () -> [DeckTourTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: Deck-Check

/// Rockys Bewertung eines Decks: drei einfache Regeln, je ein Stern.
struct DeckCheck: Equatable {
    let deck: [CardType]

    /// Die drei Grundrollen, die jedes Deck abdecken sollte
    static let coreRoles: [CardRole] = [.attack, .control, .defense]

    var average: Double { Double(deck.map(\.cost).reduce(0, +)) / Double(max(1, deck.count)) }
    var averageText: String { String(format: "%.1f", average) }
    var missingRoles: [CardRole] { Self.coreRoles.filter { r in !deck.contains { $0.role == r } } }
    var cheapest: CardType? { deck.min(by: Self.cheaper) }
    var priciest: CardType? { deck.max(by: Self.cheaper) }
    var bonusCount: Int { deck.filter(\.keepsTurn).count }

    var manaOK: Bool { average <= 3.0 }
    var mixOK: Bool { missingRoles.isEmpty }
    var startOK: Bool { deck.contains { $0.cost <= 2 } }
    var stars: Int { max(1, [manaOK, mixOK, startOK].filter { $0 }.count) }

    static func cheaper(_ a: CardType, _ b: CardType) -> Bool {
        (a.cost, a.rawValue) < (b.cost, b.rawValue)
    }

    var verdict: String {
        switch stars {
        case 3: return L("Wow – ein Profi-Deck! Da zittern sogar die Bots.")
        case 2: return L("Starkes Deck! Mit einem kleinen Tausch wird's perfekt.")
        default: return L("Mutig … sehr mutig! Sollen wir's noch etwas verbessern?")
        }
    }

    var manaText: String {
        manaOK ? L("Ø {0} Mana – schnell spielbar.", averageText)
               : L("Ø {0} Mana – ganz schön teuer. Du wartest oft aufs Mana.", averageText)
    }

    var mixText: String {
        mixOK ? L("Angriff, Kontrolle und Verteidigung – alles dabei!")
              : L("Es fehlt: {0}.", missingRoles.map(\.name).joined(separator: ", "))
    }

    var startText: String {
        if startOK, let c = cheapest { return L("{0} kostet nur {1} Mana – damit legst du früh los.", c.name, c.cost) }
        return L("Keine Karte für 2 Mana oder weniger – am Anfang ist Mana knapp.")
    }

    var bonusText: String {
        switch bonusCount {
        case 0: return L("Keine Bonusaktion – jede Karte kostet dich deinen Zug.")
        case 1: return L("1 Bonusaktion: Danach ziehst du noch eine Figur.")
        default: return L("{0} Bonusaktionen: Danach ziehst du noch eine Figur.", bonusCount)
        }
    }

    /// Rockys Tauschvorschlag für ein volles Deck: welche Karte raus, welche rein, und was er dazu sagt.
    func suggestion(available: [CardType]) -> (out: CardType?, into: CardType?, text: String)? {
        let pool = available.filter { !deck.contains($0) }
        if let role = missingRoles.first {
            // Raus: eine Karte, deren Rolle doppelt vorkommt (die teuerste davon), sonst die teuerste
            let doubled = deck.filter { c in deck.filter { $0.role == c.role }.count > 1 }
            let out = doubled.max(by: Self.cheaper) ?? priciest
            if let into = pool.filter({ $0.role == role }).min(by: Self.cheaper), let out {
                return (out, into, L("Dir fehlt noch {0}. Nimm {1} raus und hol dir {2}!", role.name, out.name, into.name))
            }
            return (nil, nil, L("Dir fehlt noch {0} – solche Karten findest du bald in Truhen.", role.name))
        }
        if !manaOK, let out = priciest {
            if let into = pool.filter({ $0.cost < out.cost && $0.role == out.role }).min(by: Self.cheaper)
                ?? pool.filter({ $0.cost < out.cost }).min(by: Self.cheaper) {
                return (out, into, L("{0} ist ganz schön teuer. Tausch sie doch gegen {1}!", out.name, into.name))
            }
            return (out, nil, L("{0} ist ganz schön teuer – tausch sie gegen etwas Günstigeres.", out.name))
        }
        if !startOK, let out = priciest, let into = pool.filter({ $0.cost <= 2 }).min(by: Self.cheaper) {
            return (out, into, L("Für den Anfang fehlt dir eine günstige Karte. Wie wär's mit {0} statt {1}?", into.name, out.name))
        }
        return nil
    }

    /// Beste Ergänzung für ein Deck mit freiem Platz (fehlende Rolle zuerst, dann eine günstige Karte).
    func bestAddition(from candidates: [CardType], avoiding: CardType?) -> CardType? {
        let pool = candidates.filter { !deck.contains($0) && $0 != avoiding }
        if let role = missingRoles.first, let c = pool.filter({ $0.role == role }).min(by: Self.cheaper) { return c }
        if !startOK, let c = pool.filter({ $0.cost <= 2 }).min(by: Self.cheaper) { return c }
        return nil
    }
}

// MARK: Ablauf

@MainActor
final class DeckTour: ObservableObject {
    /// Splitter zum Abschluss der ersten Tour
    static let reward = 20

    @Published private(set) var step: DeckTourStep?
    /// Rockys Kommentar zur zuletzt gelegten Karte
    @Published private(set) var reaction: String?
    /// Zähler für kleine Funkenregen an Rocky
    @Published private(set) var burst = 0
    /// Rocky hüpft bei jeder neuen Nachricht
    @Published private(set) var bounce = 0
    /// Karte, die Rocky gerade vorschlägt (leuchtet in der Sammlung)
    @Published private(set) var suggestedIn: CardType?
    /// Karte im Deck, die Rocky zum Tauschen vorschlägt
    @Published private(set) var suggestedOut: CardType?
    @Published private(set) var removed: CardType?
    @Published private(set) var starsBefore = 0
    /// Ultimate, die Rocky im Ultimate-Schritt gerade erklärt, und welche schon angetippt wurden (v0.9.33)
    @Published private(set) var focusUltimate: Ultimate?
    @Published private(set) var ultimatesSeen: Set<Ultimate> = []
    /// Erstes Mal (mit Belohnung) oder Wiederholung über den Rocky-Knopf
    private(set) var firstRun = false
    private var known: [CardType] = []
    private var token = 0

    var isActive: Bool { step != nil }

    func start(deck: [CardType], firstRun: Bool) {
        self.firstRun = firstRun
        known = deck
        reaction = nil
        suggestedIn = nil
        suggestedOut = nil
        removed = nil
        token += 1
        step = .hello
        bounce += 1
        Feedback.play(.notify, .summon)
    }

    func finish() {
        token += 1
        step = nil
        reaction = nil
        suggestedIn = nil
        suggestedOut = nil
    }

    /// Weiter-Knopf in der Blase
    func next(deck: [CardType], available: [CardType]) {
        guard let step else { return }
        token += 1
        known = deck
        switch step {
        case .hello:
            reaction = nil
            self.step = deck.count >= PlayerDeck.size ? .check : (deck.isEmpty ? .pick : .fill)
        case .check:
            let check = DeckCheck(deck: deck)
            starsBefore = check.stars
            let s = check.suggestion(available: available)
            suggestedOut = s?.out
            suggestedIn = s?.into
            removed = nil
            self.step = .swapOut
        case .recheck:
            self.step = .ultimate
        case .ultimate:
            focusUltimate = nil
            ultimatesSeen = []
            self.step = .ultimates
        case .ultimates:
            self.step = .done
        default:
            return
        }
        bounce += 1
        Haptics.shared.play(.select)
    }

    /// Im Ultimate-Schritt eine Ultimate angetippt: Rocky erklärt sie.
    func explain(_ ultimate: Ultimate) {
        guard step == .ultimates else { return }
        focusUltimate = ultimate
        let firstTime = !ultimatesSeen.contains(ultimate)
        ultimatesSeen.insert(ultimate)
        bounce += 1
        if firstTime { burst += 1 }
        Haptics.shared.play(.cardFlip)
    }

    /// Den Tausch-Trick auslassen
    func skipToUltimate() {
        token += 1
        suggestedIn = nil
        suggestedOut = nil
        step = .ultimate
        bounce += 1
        Haptics.shared.play(.select)
    }

    /// Das Deck hat sich geändert (Antippen, Vorlage, Tausch) – Rocky reagiert.
    func deckChanged(_ deck: [CardType], available: [CardType]) {
        let old = known
        known = deck
        guard let step, old != deck else { return }
        let added = deck.first { !old.contains($0) }
        let gone = old.first { !deck.contains($0) }
        token += 1
        switch step {
        case .hello, .pick, .fill:
            if let added {
                reaction = Self.quip(for: added)
                burst += 1
            } else if let gone {
                reaction = L("{0} ist wieder raus – auch okay! Ausprobieren ist erlaubt.", gone.name)
            }
            bounce += 1
            if deck.count >= PlayerDeck.size {
                self.step = .fill
                go(.check, after: 1.9)
            } else {
                self.step = deck.isEmpty && added == nil ? .pick : .fill
            }
        case .swapOut:
            if let gone, deck.count < old.count {
                removed = gone
                suggestedOut = nil
                let check = DeckCheck(deck: deck)
                suggestedIn = check.bestAddition(from: available, avoiding: gone)
                self.step = .swapIn
                bounce += 1
            } else if deck.count >= PlayerDeck.size, let added {
                // Getauscht über den Tausch-Modus (Karte unten, dann Platz oben)
                removed = gone
                reaction = Self.quip(for: added)
                burst += 1
                bounce += 1
                suggestedOut = nil
                suggestedIn = nil
                self.step = .swapIn
                go(.recheck, after: 1.7)
            }
        case .swapIn:
            if deck.count >= PlayerDeck.size, let added {
                reaction = Self.quip(for: added)
                burst += 1
                bounce += 1
                suggestedIn = nil
                go(.recheck, after: 1.7)
            } else if let gone {
                removed = gone
                suggestedIn = DeckCheck(deck: deck).bestAddition(from: available, avoiding: gone)
                reaction = nil
                bounce += 1
            }
        case .check, .recheck, .ultimate, .ultimates, .done:
            break
        }
    }

    private func go(_ next: DeckTourStep, after delay: Double) {
        let t = token
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.token == t, self.step != nil else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                self.step = next
                self.bounce += 1
            }
            Haptics.shared.play(.select)
        }
    }

    /// Was Rocky gerade sagt.
    func message(deck: [CardType]) -> String {
        guard let step else { return "" }
        let left = PlayerDeck.size - deck.count
        switch step {
        case .hello:
            return deck.count >= PlayerDeck.size
                ? L("Hey, ich bin Rocky! Willkommen in meiner Deck-Werkstatt. Deine 4 Deckkarten hast du in jeder Partie auf der Hand – lass uns dein Deck mal durchchecken!")
                : L("Hey, ich bin Rocky! Willkommen in meiner Deck-Werkstatt. Oben liegen deine 4 Deckplätze – genau diese Karten hast du in jeder Partie auf der Hand.")
        case .pick:
            return (reaction.map { $0 + "\n" } ?? "")
                + L("Tippe unten eine Karte an – schwupps, liegt sie auf Platz 1! Lange drücken zeigt dir vorher alle Details.")
        case .fill:
            let lead = reaction.map { $0 + "\n" } ?? ""
            if left <= 0 { return lead + L("Deck voll! Moment, ich schau's mir mal genauer an …") }
            let rest = left == 1 ? L("Noch 1 Platz frei!") : L("Noch {0} Plätze frei.", left)
            let tip = DeckCheck(deck: deck).missingRoles.isEmpty ? "" : " " + L("Mein Tipp: Misch Angriff, Kontrolle und Verteidigung.")
            return lead + rest + tip
        case .check:
            return DeckCheck(deck: deck).verdict
        case .swapOut:
            let lead = DeckCheck(deck: deck).suggestion(available: ProfileStore.shared.unlockedCards)?.text
            if let lead {
                return lead + " " + L("Tippe dazu oben eine Karte im Deck an – zack, ist sie raus.")
            }
            return L("Profi-Trick: Tippe oben eine Karte in deinem Deck an – zack, ist sie raus. Keine Sorge, du holst sie gleich wieder rein!")
        case .swapIn:
            if left <= 0 {
                return (reaction.map { $0 + "\n" } ?? "") + L("Und? Mal sehen, was die Wertung jetzt sagt …")
            }
            guard let removed else { return L("Jetzt tippe unten die Karte an, die rein soll.") }
            if let into = suggestedIn {
                return L("{0} ist raus! Jetzt tippe unten {1} an – die Karte leuchtet schon.", removed.name, into.name)
            }
            return L("{0} ist raus! Jetzt tippe unten die Karte an, die rein soll – oder hol {0} zurück.", removed.name)
        case .recheck:
            let now = DeckCheck(deck: deck).stars
            if now > starsBefore { return L("Besser! Von {0} auf {1} Sterne – genau so geht Deckbau.", starsBefore, now) }
            if now < starsBefore { return L("Hoppla, ein Stern weniger. Kein Problem – du kannst jederzeit zurücktauschen.") }
            return L("Gleich viele Sterne – auch gut! Probier ruhig verschiedene Mischungen aus.")
        case .ultimate:
            return L("Rechts liegt deine Ultimate – deine Superkraft! Jeder Zug lädt Mana. Ab 8 Mana (Festung schon ab 6) zündest du sie statt eines Zugs. Und: Dein Gegner sieht, welche du dabeihast.")
        case .ultimates:
            guard let u = focusUltimate else {
                return L("Fünf Ultimates gibt es. Tippe eine an – ich erzähl dir, wofür sie gut ist!")
            }
            let store = ProfileStore.shared
            let status: String
            if !store.isUnlocked(u) {
                status = L("Freigeschaltet ab Arena {0}.", u.arena)
            } else if store.activeUltimate == u {
                status = L("Die hast du gerade dabei.")
            } else {
                status = L("Lust drauf? Tippe auf „Ausrüsten“.")
            }
            let all = ultimatesSeen.count == Ultimate.allCases.count
                ? " " + L("Jetzt kennst du alle fünf – ausprobieren kannst du sie in der Schule!") : ""
            return Self.ultimateTake(u) + " " + status + all
        case .done:
            return L("Starke Arbeit! Denk dran: Ein gutes Deck mischt Angriff, Kontrolle und Verteidigung – mit ein, zwei günstigen Karten für den Start.")
        }
    }

    /// Rockys Erklärung zu jeder Ultimate: was sie tut und wann sie glänzt
    static func ultimateTake(_ u: Ultimate) -> String {
        switch u {
        case .meteor: return L("Meteor: Rumms! Vernichtet eine gegnerische Figur – nur König und Dame nicht. Ideal gegen den Turm, der dir im Weg steht.")
        case .iceAge: return L("Eiszeit: Alles friert ein! Zwei Züge lang kann der Gegner nur mit dem König ziehen – Zeit für deinen Großangriff.")
        case .fortress: return L("Festung: Mauern hoch! Bis nach dem nächsten Gegnerzug ist keine deiner Figuren schlagbar, danach ziehst du noch. Schon ab 6 Mana – deine Rettung in der Not.")
        case .coronation: return L("Krönung: Ein Bauer wird sofort zur Dame! Hast du schon eine, muss er dafür in der gegnerischen Hälfte stehen.")
        case .rebirth: return L("Wiedergeburt: Deine wertvollste geschlagene Figur kehrt zurück – sogar die Dame! Der perfekte Comeback-Trick.")
        }
    }

    /// Rockys Spruch zu jeder Karte
    static func quip(for card: CardType) -> String {
        switch card {
        case .shield: return L("Schild! Sehr vernünftig – so verlierst du keine wichtige Figur.")
        case .freeze: return L("Frost! Brrr … damit legst du die gefährlichste Figur auf Eis.")
        case .bulwark: return L("Bollwerk! Deine Bauern bauen sich eine Mauer. Gemütlich!")
        case .sprint: return L("Sturmlauf! Deine Bauern bekommen Raketenschuhe.")
        case .lightning: return L("Blitz! Zack – vorwitzige Bauern in deiner Hälfte sind Geschichte.")
        case .knighting: return L("Ritterschlag! Aus einem Bauern wird ein Springer – das sieht kein Gegner kommen.")
        case .reinforce: return L("Verstärkung! Frischer Bauer, frisches Glück – Löcher in der Reihe, ade!")
        case .revive: return L("Wiederkehr! Totgesagte leben länger – deine beste Figur kommt zurück.")
        case .bishopize: return L("Läuferweihe! Ein Bauer wird zum Läufer – ab jetzt geht's diagonal.")
        case .advance: return L("Vormarsch! Alle Bauern – marsch! Ich hör schon die Trommeln.")
        case .swap: return L("Leibwache! Dein König hat jetzt einen Bodyguard.")
        case .drain: return L("Manaraub! Fies … aber genial. Der Gegner wird ganz blass.")
        case .focus: return L("Konzentration! Tief durchatmen – und +4 Mana.")
        case .sacrifice: return L("Bauernopfer! Mutig – ein Bauer für 3 Mana.")
        case .retreat: return L("Rückzug! Kluger Schachzug – ein Schritt zurück, und der Bauer ist in Sicherheit.")
        }
    }
}

// MARK: - Rocky

/// Rockys Gesicht (aus dem Logo): wippt sanft und hüpft bei jeder neuen Nachricht.
struct RockyAvatar: View {
    var size: CGFloat = 60
    var bounce: Int = 0
    var excited = false
    @State var squash = false

    var body: some View {
        Image("RockyFace")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold, CardStyle.ultimateDeep],
                                                          startPoint: .top, endPoint: .bottom), lineWidth: max(2, size / 22)))
            .shadow(color: Theme.gold.opacity(0.45), radius: size / 7)
            .scaleEffect(x: squash ? 1.12 : 1, y: squash ? 0.88 : 1, anchor: .bottom)
            .modifier(RoadBob(active: true, amplitude: excited ? 5 : 3, speed: excited ? 6 : 2.6))
            .onChange(of: bounce) { _ in
                withAnimation(.spring(response: 0.16, dampingFraction: 0.4)) { squash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) { squash = false }
                }
            }
            .accessibilityHidden(true)
    }
}

/// Text, der wie getippt erscheint. Ein Tipp zeigt sofort alles.
struct TypewriterText: View {
    let text: String
    var size: CGFloat = 14
    @State var shown = 0

    var body: some View {
        let font = Font.system(size: size, weight: .semibold)
        ZStack(alignment: .topLeading) {
            // Unsichtbarer Volltext hält die Höhe fest, damit die Blase beim Tippen nicht wächst
            Text(text).font(font).opacity(0)
            Text(String(text.prefix(shown))).font(font).foregroundColor(Theme.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { shown = text.count }
        .task(id: text) {
            shown = 0
            let total = text.count
            while shown < total {
                try? await Task.sleep(nanoseconds: 15_000_000)
                if Task.isCancelled { return }
                shown = min(total, shown + 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Spitze der Sprechblase (zeigt nach links unten zu Rocky).
struct RockyBubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY * 0.55 + r.minY * 0.45))
        p.closeSubpath()
        return p
    }
}

struct TourButton {
    let title: String
    var icon: String? = nil
    let action: () -> Void
}

/// Rocky unten links mit Sprechblase – Text, optionaler Zusatz (Rollen-Zähler, Deck-Check) und Knöpfe.
struct RockyTourPanel<Extra: View>: View {
    let message: String
    let bounce: Int
    let burst: Int
    let progress: Int
    var primary: TourButton? = nil
    var secondary: TourButton? = nil
    var onClose: (() -> Void)? = nil
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(spacing: 3) {
                ZStack {
                    RockyAvatar(size: 58, bounce: bounce)
                    if burst > 0 {
                        SparkBurst()
                            .id(burst)
                    }
                }
                Text(verbatim: "ROCKY")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(Theme.navy)
                    .padding(.horizontal, 6)
                    .frame(height: 15)
                    .background(Capsule().fill(Theme.gold))
            }
            .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 4) {
                    ForEach(0..<DeckTourStep.progressCount, id: \.self) { i in
                        Capsule()
                            .fill(i < progress ? Theme.gold : (i == progress ? Theme.gold.opacity(0.7) : Color.white.opacity(0.15)))
                            .frame(width: i == progress ? 16 : 6, height: 6)
                    }
                    Spacer(minLength: 4)
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(Theme.textMuted)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("Tour beenden"))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)
                TypewriterText(text: message)
                extra()
                if primary != nil || secondary != nil {
                    HStack(spacing: 10) {
                        if let secondary {
                            Button(action: secondary.action) {
                                Text(secondary.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer(minLength: 0)
                        if let primary {
                            Button(action: primary.action) {
                                HStack(spacing: 5) {
                                    Text(primary.title)
                                    if let icon = primary.icon { Image(systemName: icon).font(.system(size: 12, weight: .black)) }
                                }
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.navy)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom))
                                        .shadow(color: CardStyle.ultimateDeep, radius: 0, y: 3)
                                )
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
                            }
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.55), lineWidth: 1.5))
            .background(alignment: .bottomLeading) {
                RockyBubbleTail()
                    .fill(Theme.panelRaised)
                    .frame(width: 14, height: 22)
                    .offset(x: -11, y: -16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
    }
}

extension RockyTourPanel where Extra == EmptyView {
    init(message: String, bounce: Int, burst: Int, progress: Int, primary: TourButton? = nil, secondary: TourButton? = nil,
         onClose: (() -> Void)? = nil) {
        self.init(message: message, bounce: bounce, burst: burst, progress: progress, primary: primary, secondary: secondary,
                  onClose: onClose, extra: { EmptyView() })
    }
}

/// Drei Rollen-Lämpchen: leuchten auf, sobald das Deck die Rolle abdeckt.
struct RoleTracker: View {
    let deck: [CardType]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DeckCheck.coreRoles, id: \.self) { role in
                let on = deck.contains { $0.role == role }
                let color = Color(hex: role.colorHex)
                HStack(spacing: 4) {
                    Image(systemName: on ? "checkmark" : role.icon)
                        .font(.system(size: 10, weight: .black))
                    Text(role.name)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundColor(on ? Theme.navy : color)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(on ? color : color.opacity(0.12)))
                .overlay(Capsule().strokeBorder(color.opacity(on ? 0 : 0.5), style: StrokeStyle(lineWidth: 1, dash: on ? [] : [3, 3])))
                .scaleEffect(on ? 1 : 0.96)
                .animation(.spring(response: 0.35, dampingFraction: 0.5), value: on)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DeckCheck(deck: deck).mixText)
    }
}

/// Rockys Deck-Check: Sterne springen nacheinander herein, darunter die drei Regeln und die Bonusaktionen.
struct DeckCheckPanel: View {
    let check: DeckCheck
    @State var shownStars = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(L("ROCKYS DECK-CHECK"))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(Theme.gold)
                Spacer(minLength: 4)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        let lit = i < shownStars
                        Image(systemName: lit ? "star.fill" : "star")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(lit ? AnyShapeStyle(LinearGradient(colors: [CardStyle.ultimateTop, Theme.gold], startPoint: .top, endPoint: .bottom))
                                                 : AnyShapeStyle(Theme.textMuted.opacity(0.6)))
                            .scaleEffect(lit ? 1 : 0.8)
                            .rotationEffect(.degrees(lit ? 0 : -30))
                            .shadow(color: lit ? Theme.gold.opacity(0.7) : .clear, radius: 5)
                    }
                }
            }
            row(ok: check.manaOK, icon: "drop.fill", title: L("Mana"), text: check.manaText)
            row(ok: check.mixOK, icon: "circle.hexagongrid.fill", title: L("Rollen-Mix"), text: check.mixText)
            row(ok: check.startOK, icon: "hare.fill", title: L("Schneller Start"), text: check.startText)
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Theme.blueLight)
                    .frame(width: 16)
                Text(check.bonusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.background.opacity(0.6)))
        .task(id: check) {
            shownStars = 0
            for i in 1...check.stars {
                try? await Task.sleep(nanoseconds: 380_000_000)
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shownStars = i }
                if i == 3 { Feedback.play(.victory, .chestUpgrade) } else { Feedback.play(.select, .chestCount) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("{0} von 3 Sternen", check.stars))
    }

    private func row(ok: Bool, icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundColor(ok ? Color(hex: CardRole.defense.colorHex) : Theme.gold)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: icon).font(.system(size: 8, weight: .black))
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundColor(Theme.textMuted)
                Text(text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Abdunkeln mit Ausschnitt um den gezeigten Bereich, dazu ein pulsierender goldener Rahmen.
struct DeckTourSpotlight: View {
    let rect: CGRect?
    let dim: Double
    @State var pulse = false

    var body: some View {
        GeometryReader { geo in
            let full = CGRect(origin: .zero, size: geo.size).insetBy(dx: -300, dy: -300)
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.addRect(full)
                    if let r = rect {
                        p.addRoundedRect(in: r.insetBy(dx: -8, dy: -8), cornerSize: CGSize(width: 16, height: 16))
                    }
                }
                .fill(Color.black.opacity(dim), style: FillStyle(eoFill: true))
                if let r = rect?.insetBy(dx: -8, dy: -8) {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Theme.gold, lineWidth: 2.5)
                        .shadow(color: Theme.gold.opacity(0.8), radius: pulse ? 14 : 4)
                        .frame(width: r.width, height: r.height)
                        .scaleEffect(pulse ? 1.025 : 1)
                        .offset(x: r.minX, y: r.minY)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// Alle fünf Ultimates zum Antippen – gesperrte grau mit Schloss, die ausgerüstete mit Häkchen.
struct UltimateGallery: View {
    let focus: Ultimate?
    let seen: Set<Ultimate>
    let onTap: (Ultimate) -> Void
    @ObservedObject var store = ProfileStore.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Ultimate.allCases) { u in
                let unlocked = store.isUnlocked(u)
                let active = store.activeUltimate == u
                let selected = focus == u
                Button { onTap(u) } label: {
                    VStack(spacing: 3) {
                        UltimateCard(ultimate: u, mana: GameState.maxMana, compact: true)
                            .saturation(unlocked ? 1 : 0)
                            .opacity(unlocked ? 1 : 0.55)
                            .overlay(alignment: .topTrailing) {
                                if !unlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(width: 16, height: 16)
                                        .background(Circle().fill(Theme.background))
                                        .offset(x: 4, y: -4)
                                } else if active {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(Theme.navy)
                                        .frame(width: 16, height: 16)
                                        .background(Circle().fill(Theme.gold))
                                        .offset(x: 4, y: -4)
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Theme.gold, lineWidth: selected ? 2 : 0)
                                    .padding(-3)
                            )
                            .modifier(PulseGlow(color: Theme.gold, active: focus == nil && !seen.contains(u), strength: 0.5))
                        Text(u.name)
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundColor(selected ? Theme.gold : Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    .scaleEffect(selected ? 1.08 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(u.name + (unlocked ? "" : L(", gesperrt")))
            }
        }
    }
}

// MARK: - Feier

/// Zum Schluss: Konfetti, Rocky jubelt, das neue Deck fächert auf, Belohnung, ab in den Kampf.
struct DeckTourCelebration: View {
    let deck: [CardType]
    let message: String
    let reward: Int?
    let onBattle: () -> Void
    let onStay: () -> Void
    @State var appear = false
    @State var dealt = 0
    @State var bounce = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            ConfettiView(seed: 2032).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 12) {
                RockyAvatar(size: 88, bounce: bounce, excited: true)
                    .rotationEffect(.degrees(appear ? 0 : -25))
                    .scaleEffect(appear ? 1 : 0.2)
                Text(L("Dein Deck ist kampfbereit!"))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                // Die vier Karten fächern nacheinander auf
                HStack(spacing: -12) {
                    ForEach(Array(deck.enumerated()), id: \.offset) { i, card in
                        let angle = (Double(i) - Double(deck.count - 1) / 2) * 7
                        CardView(card: card)
                            .frame(width: 56)
                            .rotationEffect(.degrees(i < dealt ? angle : 0), anchor: .bottom)
                            .offset(y: i < dealt ? abs(angle) * 0.6 : -260)
                            .opacity(i < dealt ? 1 : 0)
                            .zIndex(Double(i))
                    }
                }
                .frame(height: 92)
                TypewriterText(text: message, size: 14)
                    .multilineTextAlignment(.leading)
                if let reward {
                    HStack(spacing: 6) {
                        ShardIcon(size: 18)
                        Text(L("+{0} Splitter", reward))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(ShardStyle.color)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(ShardStyle.deep.opacity(0.3)))
                    .overlay(Capsule().strokeBorder(ShardStyle.color.opacity(0.6), lineWidth: 1))
                    .scaleEffect(dealt >= deck.count ? 1 : 0.3)
                    .opacity(dealt >= deck.count ? 1 : 0)
                }
                Button(action: onBattle) {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text(L("Ab in den Kampf!"))
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 56, textColor: Theme.navy))
                .padding(.top, 2)
                Button(L("Weiter basteln"), action: onStay)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 20)
            .scaleEffect(appear ? 1 : 0.85)
            .padding(24)
        }
        .onAppear {
            Feedback.play(.victory, .victory)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            for i in 0..<deck.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i) * 0.18) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { dealt = i + 1 }
                    Haptics.shared.play(.cardWhoosh)
                    if i == deck.count - 1 {
                        bounce += 1
                        if reward != nil { Feedback.play(.reward, .shardShower) }
                    }
                }
            }
        }
    }
}

// MARK: - Einladung auf der Startseite

/// Nach der ersten Partie springt Rocky auf die Startseite und lädt in die Deck-Werkstatt ein.
struct RockyInviteOverlay: View {
    let chestsWaiting: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    @State var appear = false
    @State var bounce = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(appear ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture {}
            VStack(spacing: 0) {
                RockyAvatar(size: 96, bounce: bounce, excited: true)
                    .rotationEffect(.degrees(appear ? 0 : 30))
                    .offset(y: appear ? 22 : 300)
                    .zIndex(1)
                VStack(spacing: 14) {
                    Text(verbatim: "ROCKY")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 9)
                        .frame(height: 19)
                        .background(Capsule().fill(Theme.gold))
                        .padding(.top, 26)
                    TypewriterText(text: chestsWaiting
                                   ? L("Hey, ich bin Rocky! Starke erste Schlacht! In deinen Truhen warten neue Karten – öffne sie zuerst, dann bauen wir zusammen dein Deck.")
                                   : L("Hey, ich bin Rocky! Starke erste Schlacht! Jetzt brauchst du ein eigenes Deck – komm mit in meine Werkstatt, ich zeig dir, wie's geht."),
                                   size: 16)
                    // Vier leere Plätze warten
                    HStack(spacing: 8) {
                        ForEach(0..<PlayerDeck.size, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Theme.gold.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
                                .overlay(Image(systemName: "plus").font(.system(size: 15, weight: .black)).foregroundColor(Theme.gold))
                                .frame(width: 44, height: 55)
                                .modifier(RoadBob(active: true, amplitude: 3, speed: 3, phase: Double(i) * 0.7))
                        }
                    }
                    Button(action: onPrimary) {
                        HStack(spacing: 8) {
                            Image(systemName: chestsWaiting ? "shippingbox.fill" : "hammer.fill")
                            Text(chestsWaiting ? L("Truhen öffnen") : L("Ab in die Werkstatt!"))
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: chestsWaiting ? Theme.gold : Theme.blue,
                                                   shadow: chestsWaiting ? CardStyle.ultimateDeep : Theme.blueDark,
                                                   height: 56, textColor: chestsWaiting ? Theme.navy : .white))
                    Button(chestsWaiting ? L("Gleich zum Deck") : L("Später"), action: onSecondary)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .frame(maxWidth: 380)
                .background(RoundedRectangle(cornerRadius: 24).fill(Theme.background))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.gold.opacity(0.7), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.5), radius: 20)
                .offset(y: appear ? 0 : 500)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .onAppear {
            Feedback.play(.notify, .summon)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { bounce += 1 }
        }
    }
}

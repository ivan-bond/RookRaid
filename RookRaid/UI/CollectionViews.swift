import SwiftUI

// MARK: - Deck-Editor

/// Deck bauen – aufgeräumt in drei klaren Teilen:
/// 1. Oben angeheftet dein Kampfdeck (4 Karten + Ultimate) mit Steckbrief und drei Knöpfen: Vorlagen, Ultimate, Testen.
/// 2. Darunter die Sammlung mit Filter nach Rolle – ein einziges Raster statt vieler Abschnitte.
/// Tauschen: Karte unten antippen, dann die Karte im Deck, die raus soll (oder umgekehrt).
/// Hinweise erscheinen kurz als Blase unten, statt dauerhaft Platz zu belegen.
struct DeckView: View {
    @ObservedObject var store = ProfileStore.shared
    @State var detail: DetailItem? = nil
    /// Ausgewählter Platz im Deck, der ersetzt werden soll.
    @State var selectedSlot: Int? = nil
    /// Karte aus der Sammlung, die auf einen Platz wartet.
    @State var incoming: CardType? = nil
    @State var hint: String? = nil
    /// Gesperrte Karte, deren Kauf bestätigt werden soll.
    @State var buyCandidate: CardType? = nil
    @State var panel: DeckPanel? = nil
    /// Filter der Sammlung (nil = alle Rollen).
    @State var roleFilter: CardRole? = nil
    /// Kartenschule (v0.9.26)
    @State var lab: LabItem? = nil
    /// Rockys Deck-Werkstatt (v0.9.32)
    @StateObject var tour = DeckTour()
    /// Karte im Deck, die gerade kurz wackelt („ist schon im Deck“)
    @State var nudged: CardType? = nil
    /// Hinweis auch während der Tour zeigen (dann oben statt unten)
    @State var hintDuringTour = false
    @Environment(\.liveAnimations) var live

    enum DeckPanel: String, Identifiable {
        case presets, ultimate
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                LinearGradient(colors: [Theme.blueDark.opacity(0.5), .clear], startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
                GeometryReader { geo in
                    ScrollView(.vertical, showsIndicators: false) {
                        // Das Kampfdeck ist ein angehefteter Abschnittskopf: Es bleibt beim Scrollen oben stehen,
                        // so lässt sich jede Karte tauschen, ohne zurückzuscrollen.
                        LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                            header
                                .padding(.horizontal, 14)
                            Section(header: stickyDeck) {
                                collectionSection
                                    .padding(.horizontal, 14)
                                    .padding(.top, 4)
                            }
                        }
                        // Während der Tour Platz für Rockys Blase lassen, damit alles erreichbar bleibt
                        .padding(.bottom, tour.isActive ? 240 : 40)
                        .frame(width: geo.size.width)
                    }
                }
                // Kurze Hinweise als Blase unten
                // (während Rockys Tour oben, damit sie seine Blase nicht verdecken)
                VStack {
                    if !tour.isActive { Spacer() }
                    if let hint, !swapping, !tour.isActive || hintDuringTour {
                        Text(hint)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.panelRaised))
                            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
                            .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                            .padding(.top, tour.isActive ? 10 : 0)
                            .transition(.move(edge: tour.isActive ? .top : .bottom).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                    if tour.isActive { Spacer() }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hint)
            }
            .overlayPreferenceValue(DeckTourAnchorKey.self) { anchors in
                tourLayer(anchors)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: tour.step)
            }
            .navigationBarHidden(true)
            .sheet(item: $panel) { p in
                switch p {
                case .presets: presetSheet
                case .ultimate: ultimateSheet
                }
            }
        }
        .sheet(item: $detail) { item in DetailSheet(item: item) }
        .fullScreenCover(item: $lab) { it in CardLabView(start: it) }
        // Rockys Deck-Werkstatt startet von selbst, sobald der Tab nach der ersten Partie sichtbar wird
        .onAppear { maybeStartTour() }
        .onChange(of: live) { _ in maybeStartTour() }
        .onChange(of: store.activeDeck) { deck in
            tour.deckChanged(deck, available: store.unlockedCards)
        }
        .onChange(of: tour.step) { step in
            guard step == .done, tour.firstRun, !store.profile.deckTourDone else { return }
            store.earnShards(DeckTour.reward)
            store.profile.deckTourDone = true
        }
        .confirmationDialog(buyCandidate.map { L("{0} freischalten?", $0.name) } ?? "",
                            isPresented: Binding(get: { buyCandidate != nil }, set: { if !$0 { buyCandidate = nil } }),
                            titleVisibility: .visible) {
            if let card = buyCandidate {
                Button(L("Für {0} Splitter freischalten", card.tier.price)) {
                    if store.buy(card) {
                        Haptics.shared.play(.chestBigReveal)
                        SoundPlayer.shared.play(.rewardBig)
                        showHint(L("{0} ist freigeschaltet!", card.name))
                    }
                    buyCandidate = nil
                }
                Button(L("Abbrechen"), role: .cancel) { buyCandidate = nil }
            }
        } message: {
            if let card = buyCandidate {
                Text("\(card.tier.name) · \(card.description)")
            }
        }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Theme.blueLight, Theme.blue], startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(-10))
            Text(L("Deck"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            rockyButton
            Spacer(minLength: 8)
            ShardPill()
        }
        .padding(.top, 10)
    }

    /// Kartenschule (Knopf „Schule“, v0.9.33 statt „Ultimate“ unter dem Deck): jede Karte und Ultimate auf einem
    /// kleinen Brett selbst ausprobieren. Startet bei der ersten noch offenen Lektion; die Zahl zeigt, wie viele fertig sind.
    private var labButton: some View {
        let all = LabItem.all
        let done = all.filter { store.profile.labDone.contains($0.key) }.count
        return Button {
            Haptics.shared.play(.cardWhoosh)
            lab = all.first { !store.profile.labDone.contains($0.key) } ?? all.first
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 12, weight: .black))
                    .modifier(Jiggle(active: done == 0, amplitude: 6, period: 1.4))
                Text(L("Schule"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(done)/\(all.count)")
                    .font(.system(size: 10, weight: .black, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .opacity(0.7)
            }
            .foregroundColor(Theme.navy)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color(hex: 0xF5B83D), Color(hex: 0xB0720F)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xB0720F).opacity(0.9), radius: 0, y: 3)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
            .modifier(PulseGlow(color: Theme.gold, active: done == 0 && !tour.isActive, strength: 0.6))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(L("Kartenschule, {0} von {1} geschafft", done, all.count))
    }

    // MARK: Kampfdeck (angeheftet)

    private var swapping: Bool { incoming != nil || selectedSlot != nil }

    private var stickyDeck: some View {
        let deck = store.activeDeck
        let avg = Double(deck.map(\.cost).reduce(0, +)) / Double(max(1, deck.count))
        let bonus = deck.filter(\.keepsTurn).count
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(L("DEIN KAMPFDECK"))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundColor(Theme.blueLight)
                Spacer()
                // Steckbrief: Ø Mana, Bonusaktionen, Rollen als Farbpunkte
                HStack(spacing: 6) {
                    statChip(String(format: "Ø %.1f", avg), icon: "drop.fill", color: Theme.manaLight)
                    statChip("\(bonus)", icon: "figure.walk", color: Theme.blueLight)
                    HStack(spacing: 3) {
                        ForEach(Array(deck.enumerated()), id: \.offset) { _, c in
                            Circle().fill(Color(hex: c.role.colorHex)).frame(width: 8, height: 8)
                        }
                    }
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L(bonus == 1 ? "Ø {0} Mana · {1} Bonusaktion · Tippe eine Karte unten an, um zu tauschen" : "Ø {0} Mana · {1} Bonusaktionen · Tippe eine Karte unten an, um zu tauschen", String(format: "%.1f", avg), bonus))
            }
            HStack(alignment: .bottom, spacing: 7) {
                // Vier Plätze: belegte zeigen die Karte (antippen = herausnehmen), freie einen Platzhalter (v0.9.31)
                HStack(alignment: .bottom, spacing: 7) {
                ForEach(0..<PlayerDeck.size, id: \.self) { idx in
                    if idx < deck.count {
                        let card = deck[idx]
                        CardView(card: card, isSelected: selectedSlot == idx)
                            .frame(maxWidth: 66)
                            .modifier(Jiggle(active: incoming != nil || tour.step == .swapOut, phase: Double(idx) * 1.3))
                            .modifier(PulseGlow(color: Theme.red, active: tour.step == .swapOut && tour.suggestedOut == card, strength: 0.9))
                            // Kurzes Wackeln, wenn man die Karte unten in der Sammlung antippt (sie ist schon im Deck)
                            .modifier(Jiggle(active: nudged == card, amplitude: 7, period: 0.12))
                            .scaleEffect(nudged == card ? 1.08 : 1)
                            .overlay(alignment: .top) {
                                // Nur beim Tauschen: goldenes Tausch-Zeichen (kein Minus mehr, v0.9.33)
                                if incoming != nil {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(Theme.navy)
                                        .frame(width: 22, height: 22)
                                        .background(Circle().fill(Theme.gold))
                                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 1.5))
                                        .offset(y: -10)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .onTapGesture { tapSlot(idx) }
                            .onLongPressGesture(minimumDuration: 0.35) { detail = .card(card) }
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityLabel(L("Deckplatz {0}: {1}", idx + 1, card.name))
                            .accessibilityHint(incoming != nil ? L("Tippen zum Tauschen") : L("Tippen zum Herausnehmen"))
                    } else {
                        emptySlot(idx, highlight: deck.isEmpty || selectedSlot == idx || incoming != nil)
                            .frame(maxWidth: 66)
                            .onTapGesture { tapSlot(idx) }
                            .accessibilityLabel(L("Deckplatz {0}: frei", idx + 1))
                    }
                }
                }
                .anchorPreference(key: DeckTourAnchorKey.self, value: .bounds) { [.slots: $0] }
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 56)
                    .padding(.bottom, 14)
                UltimateCard(ultimate: store.activeUltimate, mana: GameState.maxMana, compact: false)
                    .frame(width: 58)
                    .onTapGesture { panel = .ultimate }
                    .anchorPreference(key: DeckTourAnchorKey.self, value: .bounds) { [.ultimate: $0] }
                    .accessibilityLabel(L("Ultimate {0}, tippen zum Ändern", store.activeUltimate.name))
            }
            .frame(maxWidth: .infinity)

            // Beim Tauschen: Anleitung und Abbrechen. Sonst: die drei Knöpfe fürs Deck.
            if swapping {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(Theme.gold)
                    Text(incoming != nil ? L("Dein Deck ist voll – welche Karte soll raus? Tippe sie oben an.")
                                         : L("Jetzt unten die Karte antippen, die an diesen Platz soll."))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.gold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            incoming = nil
                            selectedSlot = nil
                            hint = nil
                        }
                        Haptics.shared.play(.select)
                    } label: {
                        Text(L("Abbrechen"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(Capsule().fill(Theme.panelHighlight))
                    }
                    .buttonStyle(.plain)
                }
                .frame(height: 34)
                .transition(.opacity)
            } else {
                if deck.count < PlayerDeck.size {
                    HStack(spacing: 6) {
                        Image(systemName: deck.isEmpty ? "hand.point.down.fill" : "plus.circle.fill")
                            .font(.system(size: 12, weight: .black))
                            .modifier(RoadBob(active: deck.isEmpty, amplitude: 2, speed: 4))
                        Text(deck.isEmpty ? L("Stell dein erstes Deck zusammen: Tippe unten 4 Karten an – erst dann kannst du kämpfen.")
                                          : (PlayerDeck.size - deck.count == 1 ? L("Noch 1 Karte – dann kannst du kämpfen.")
                                                                             : L("Noch {0} Karten – dann kannst du kämpfen.", PlayerDeck.size - deck.count)))
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .foregroundColor(Theme.gold)
                    .transition(.opacity)
                }
                HStack(spacing: 8) {
                    deckButton(L("Vorlagen"), icon: "square.stack.3d.up.fill", colors: [Color(hex: 0x3A6FE0), Color(hex: 0x23408F)], text: .white) {
                        panel = .presets
                    }
                    labButton
                    deckButton(L("Testen"), icon: deck.count < PlayerDeck.size ? "lock.fill" : "play.fill",
                               colors: deck.count < PlayerDeck.size ? [Theme.panelHighlight, Theme.panel] : [Theme.green, Theme.greenDark], text: .white) {
                        if store.deckIsFull {
                            NotificationCenter.default.post(name: .startPractice, object: nil)
                        } else {
                            Haptics.shared.play(.invalid)
                            showHint(L("Zum Spielen braucht dein Deck 4 Karten."))
                        }
                    }
                }
                .frame(height: 34)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: swapping)
        .padding(12)
        .background(
            // Kampfmatte: dunkles Blau mit Lichtkegel, Karten liegen darauf
            RoundedRectangle(cornerRadius: 18)
                .fill(RadialGradient(colors: [Color(hex: 0x24448A), Color(hex: 0x14254A)], center: .top, startRadius: 4, endRadius: 260))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(swapping ? Theme.gold.opacity(0.8) : Theme.blueLight.opacity(0.35), lineWidth: 1.5))
        )
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(
            Theme.background
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.panelHighlight).frame(height: 1) }
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        )
    }

    private func deckButton(_ title: String, icon: String, colors: [Color], text: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.play(.select)
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .black))
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(text)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
                    .shadow(color: (colors.last ?? .black).opacity(0.9), radius: 0, y: 3)
            )
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressScaleStyle())
    }

    private func statChip(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .black))
            Text(text).font(.system(size: 11, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Capsule().fill(color.opacity(0.14)))
    }

    // MARK: Sammlung

    /// Sammlung als ein Raster mit Filter nach Rolle. Freie Karten zuerst, dann nach Kosten.
    private var collectionSection: some View {
        let total = CardType.allCases.count
        let owned = store.unlockedCards.count
        let cards = CardType.allCases
            .filter { roleFilter == nil || $0.role == roleFilter }
            .sorted { (store.isUnlocked($0) ? 0 : 1, $0.cost, $0.rawValue) < (store.isUnlocked($1) ? 0 : 1, $1.cost, $1.rawValue) }
        // Während der Tour zeigt eine Hand auf die Karte, die Rocky meint (Vorschlag oder die erste freie)
        let pointer: CardType? = {
            switch tour.step {
            case .pick?: return cards.first { store.isUnlocked($0) && !store.activeDeck.contains($0) }
            case .swapIn?: return store.deckIsFull ? nil : tour.suggestedIn
            default: return nil
            }
        }()
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("Sammlung"))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text(L("{0} von {1} Karten", owned, total))
                        .font(.system(size: 12, weight: .heavy).monospacedDigit())
                        .foregroundColor(owned == total ? Theme.gold : Theme.textSecondary)
                }
                ShopProgressBar(fraction: Double(owned) / Double(max(1, total)), tint: owned == total ? Theme.gold : Theme.blueLight)
                    .frame(height: 6)
            }
            filterBar
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 14) {
                ForEach(cards) { card in
                    collectionTile(card, pointer: card == pointer)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: roleFilter)
            Text(L("Lange drücken zeigt eine Karte groß mit allen Details."))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity)
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                filterChip(nil, title: L("Alle"), icon: "square.grid.2x2.fill", color: Theme.blueLight,
                           count: CardType.allCases.count)
                ForEach(CardRole.allCases, id: \.self) { role in
                    let n = CardType.allCases.filter { $0.role == role }.count
                    if n > 0 {
                        filterChip(role, title: role.name, icon: role.icon, color: Color(hex: role.colorHex), count: n)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func filterChip(_ role: CardRole?, title: String, icon: String, color: Color, count: Int) -> some View {
        let active = roleFilter == role
        return Button {
            Haptics.shared.play(.select)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { roleFilter = role }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .black))
                Text(title).font(.system(size: 12, weight: .heavy, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .opacity(0.7)
            }
            .foregroundColor(active ? Theme.navy : color)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(active ? color : color.opacity(0.14)))
            .overlay(Capsule().strokeBorder(color.opacity(active ? 0 : 0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func collectionTile(_ card: CardType, pointer: Bool = false) -> some View {
        let unlocked = store.isUnlocked(card)
        let inDeck = store.activeDeck.contains(card)
        return VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                CardView(card: card, isPlayable: unlocked, isSelected: incoming == card)
                    .overlay(alignment: .topLeading) {
                        if store.isNew(card) { NewSticker().offset(x: -6, y: -8) }
                    }
                if inDeck {
                    Text(L("IM DECK"))
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 5)
                        .frame(height: 15)
                        .background(Capsule().fill(Theme.blueLight))
                        .overlay(Capsule().strokeBorder(Theme.background, lineWidth: 1.5))
                        .offset(x: 6, y: -6)
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.textMuted)
                        .padding(4)
                        .background(Circle().fill(Theme.background))
                        .offset(x: 4, y: -4)
                }
            }
            if unlocked {
                Text(card.shortText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: card.role.colorHex))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                HStack(spacing: 2) {
                    Image(systemName: "diamond.fill").font(.system(size: 7, weight: .bold))
                    Text("\(card.tier.price)")
                        .font(.system(size: 10, weight: .heavy).monospacedDigit())
                }
                .foregroundColor(store.canBuy(card) ? Color(hex: 0x7FE3FF) : Theme.textMuted)
            }
        }
        .saturation(unlocked ? 1 : 0.25)
        .opacity(inDeck && !swapping ? 0.75 : 1)
        .modifier(PulseGlow(color: Theme.gold, active: tourWants(card), strength: 0.8))
        .overlay(alignment: .top) {
            if pointer {
                Image(systemName: "hand.point.down.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Theme.gold)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                    .modifier(RoadBob(active: true, amplitude: 5, speed: 5))
                    .offset(y: -24)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onTapGesture {
            store.markSeen(card)
            tapCollection(card)
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            store.markSeen(card)
            detail = .card(card)
        }
        .accessibilityLabel(L("{0}, {1} Mana, {2}", card.name, card.cost, card.tier.name) + (store.isNew(card) ? L(", neu") : "") + (inDeck ? L(", im Deck") : "") + (unlocked ? "" : L(", gesperrt, {0} Splitter", card.tier.price)))
    }

    // MARK: Fenster: Vorlagen

    private var presetSheet: some View {
        PresetPickerSheet(onApplied: { preset in
            selectedSlot = nil
            incoming = nil
            showHint(L("{0} übernommen.", preset.name))
        }, onClose: { panel = nil })
    }

    // MARK: Fenster: Ultimate

    private var ultimateSheet: some View {
        UltimatePickerSheet { panel = nil }
    }

    // MARK: Tauschen

    /// Deckplatz angetippt: belegte Karte herausnehmen (oder beim Tauschen ersetzen), freien Platz vormerken.
    private func tapSlot(_ idx: Int) {
        let deck = store.activeDeck
        if let card = incoming {
            place(card, at: idx)
            return
        }
        if idx < deck.count {
            let card = deck[idx]
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.removeFromDeck(card) }
            selectedSlot = nil
            Haptics.shared.play(.cardWhoosh)
            showHint(L("{0} aus dem Deck genommen.", card.name))
        } else {
            selectedSlot = selectedSlot == idx ? nil : idx
            Haptics.shared.play(.select)
        }
    }

    /// Karte in der Sammlung angetippt: ins Deck legen (freier Platz), herausnehmen (schon drin) oder tauschen (Deck voll).
    private func tapCollection(_ card: CardType) {
        guard store.isUnlocked(card) else {
            if store.canBuy(card) {
                buyCandidate = card
                Haptics.shared.play(.select)
            } else {
                Haptics.shared.play(.invalid)
                if store.level < card.tier.gateLevel {
                    showHint(L("Karten der Stufe „{0}“ gibt es ab Level {1}.", card.tier.name, card.tier.gateLevel))
                } else {
                    showHint(L("{0}: aus Truhen oder für {1} Splitter (du hast {2}).", card.name, card.tier.price, store.profile.shards))
                }
            }
            return
        }
        if store.activeDeck.contains(card) {
            // Schon im Deck: nicht herausnehmen, sondern zeigen, wo sie liegt (v0.9.33)
            incoming = nil
            selectedSlot = nil
            Haptics.shared.play(.check)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { nudged = card }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { if nudged == card { nudged = nil } }
            }
            showHint(L("{0} ist schon in deinem Deck.", card.name), duringTour: true)
            return
        }
        if !store.deckIsFull {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { _ = store.addToDeck(card) }
            selectedSlot = nil
            incoming = nil
            Haptics.shared.play(.cardCast)
            let left = PlayerDeck.size - store.activeDeck.count
            showHint(left == 0 ? L("Dein Deck ist komplett!")
                     : (left == 1 ? L("{0} ist im Deck – noch 1 Platz frei.", card.name) : L("{0} ist im Deck – noch {1} Plätze frei.", card.name, left)))
            return
        }
        incoming = incoming == card ? nil : card
        Haptics.shared.play(.select)
        if incoming == nil { showHint(L("Abgebrochen.")) }
    }

    /// Karte auf einen Platz legen: belegten Platz ersetzen, freien Platz füllen.
    private func place(_ card: CardType, at idx: Int) {
        var deck = store.activeDeck
        let old: CardType? = deck.indices.contains(idx) ? deck[idx] : nil
        if old != nil {
            deck[idx] = card
        } else if deck.count < PlayerDeck.size {
            deck.append(card)
        } else {
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { store.setDeck(deck) }
        selectedSlot = nil
        incoming = nil
        Haptics.shared.play(.cardCast)
        showHint(old.map { L("{0} statt {1}.", card.name, $0.name) } ?? L("{0} ist im Deck.", card.name))
    }

    /// Freier Deckplatz: gestrichelter Rahmen mit Plus, leuchtet, solange das Deck leer ist.
    private func emptySlot(_ idx: Int, highlight: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(highlight ? Theme.gold.opacity(0.8) : Color.white.opacity(0.25),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                    Text(L("Platz {0}", idx + 1))
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
                .foregroundColor(highlight ? Theme.gold : Theme.textMuted)
            )
            .aspectRatio(0.8, contentMode: .fit)
            .modifier(PulseGlow(color: Theme.gold, active: highlight, strength: 0.5))
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: Rockys Deck-Werkstatt

    /// Kleiner Rocky neben dem Titel „Deck“: startet die Tour (erneut).
    private var rockyButton: some View {
        Button {
            Haptics.shared.play(.cardWhoosh)
            if !tour.isActive { startTour(firstRun: store.needsDeckTour) }
        } label: {
            Image("RockyFace")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Theme.gold, lineWidth: 1.5))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 6, weight: .black))
                        .foregroundColor(Theme.navy)
                        .frame(width: 11, height: 11)
                        .background(Circle().fill(Theme.gold))
                        .offset(x: 3, y: 3)
                }
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(L("Rocky erklärt dir das Deck"))
    }

    /// Leuchtet diese Karte gerade für Rocky? (frei, nicht im Deck, Platz frei – beim Tauschen nur der Vorschlag)
    private func tourWants(_ card: CardType) -> Bool {
        guard let step = tour.step, step == .pick || step == .fill || step == .swapIn,
              store.isUnlocked(card), !store.activeDeck.contains(card), !store.deckIsFull else { return false }
        if step == .swapIn, let s = tour.suggestedIn { return s == card }
        return true
    }

    private func maybeStartTour() {
        guard live, store.needsDeckTour, !tour.isActive else { return }
        let t = tour
        let s = store
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard s.needsDeckTour, !t.isActive else { return }
            startTour(firstRun: true)
        }
    }

    private func startTour(firstRun: Bool) {
        incoming = nil
        selectedSlot = nil
        hint = nil
        panel = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            tour.start(deck: store.activeDeck, firstRun: firstRun)
        }
    }

    private func advanceTour() {
        incoming = nil
        selectedSlot = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            tour.next(deck: store.activeDeck, available: store.unlockedCards)
        }
    }

    /// Im Ultimate-Schritt die erklärte Ultimate gleich ausrüsten.
    private func equipFromTour(_ u: Ultimate) {
        guard store.isUnlocked(u) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { store.profile.settings.ultimate = u }
        Haptics.shared.play(.chestReveal)
        SoundPlayer.shared.play(.reward)
        tour.explain(u)
    }

    private func skipSwap() {
        incoming = nil
        selectedSlot = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { tour.skipToUltimate() }
    }

    /// Tour beenden (Schließen, „Weiter basteln“ oder „Ab in den Kampf“). Danach startet sie nicht mehr von selbst.
    private func endTour() {
        store.profile.deckTourDone = true
        withAnimation(.easeOut(duration: 0.3)) { tour.finish() }
    }

    /// Spotlight, Rockys Blase und zum Schluss die Feier – liegt über dem ganzen Deck-Tab.
    @ViewBuilder
    private func tourLayer(_ anchors: [DeckTourTarget: Anchor<CGRect>]) -> some View {
        if let step = tour.step {
            GeometryReader { geo in
                let target: DeckTourTarget? = {
                    switch step {
                    case .hello, .check, .recheck: return .slots
                    case .ultimate, .ultimates: return .ultimate
                    default: return nil
                    }
                }()
                let rect = target.flatMap { anchors[$0] }.map { geo[$0] }
                ZStack(alignment: .bottom) {
                    if !step.isHandsOn && step != .done {
                        // Erklär-Schritte: abdunkeln, nur der gezeigte Bereich bleibt hell; Tippen daneben bewirkt nichts
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture {}
                        DeckTourSpotlight(rect: rect, dim: 0.62)
                            .transition(.opacity)
                    }
                    if step == .done {
                        DeckTourCelebration(deck: store.activeDeck, message: tour.message(deck: store.activeDeck),
                                            reward: tour.firstRun ? DeckTour.reward : nil,
                                            onBattle: {
                                                endTour()
                                                NotificationCenter.default.post(name: .startQuickBattle, object: nil)
                                            },
                                            onStay: { endTour() })
                            .transition(.opacity)
                    } else {
                        tourPanel(step)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea(edges: .top)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func tourPanel(_ step: DeckTourStep) -> some View {
        let deck = store.activeDeck
        let msg = tour.message(deck: deck)
        let full = deck.count >= PlayerDeck.size
        switch step {
        case .hello:
            RockyTourPanel(message: msg, bounce: tour.bounce, burst: tour.burst, progress: step.progress,
                           primary: TourButton(title: full ? L("Los geht's!") : L("Zeig her!"), icon: "arrow.right", action: { advanceTour() }),
                           onClose: { endTour() })
        case .pick, .fill:
            RockyTourPanel(message: msg, bounce: tour.bounce, burst: tour.burst, progress: step.progress,
                           onClose: { endTour() }) {
                RoleTracker(deck: deck)
            }
        case .check, .recheck:
            RockyTourPanel(message: msg, bounce: tour.bounce, burst: tour.burst, progress: step.progress,
                           primary: TourButton(title: step == .check ? L("Profi-Trick zeigen") : L("Weiter"),
                                               icon: step == .check ? "wand.and.stars" : "arrow.right", action: { advanceTour() }),
                           secondary: step == .check ? TourButton(title: L("Passt so"), action: { skipSwap() }) : nil,
                           onClose: { endTour() }) {
                DeckCheckPanel(check: DeckCheck(deck: deck))
            }
        case .swapOut, .swapIn:
            RockyTourPanel(message: msg, bounce: tour.bounce, burst: tour.burst, progress: step.progress,
                           secondary: full ? TourButton(title: L("Überspringen"), action: { skipSwap() }) : nil,
                           onClose: { endTour() })
        case .ultimate:
            RockyTourPanel(message: msg, bounce: tour.bounce, burst: tour.burst, progress: step.progress,
                           primary: TourButton(title: L("Welche gibt's?"), icon: "sparkles", action: { advanceTour() }),
                           onClose: { endTour() })
        case .ultimates:
            let focus = tour.focusUltimate
            let canEquip = focus.map { store.isUnlocked($0) && store.activeUltimate != $0 } ?? false
            RockyTourPanel(message: msg, bounce: tour.bounce, burst: tour.burst, progress: step.progress,
                           primary: TourButton(title: L("Verstanden!"), icon: "checkmark", action: { advanceTour() }),
                           secondary: canEquip ? TourButton(title: L("Ausrüsten"), icon: nil, action: { if let focus { equipFromTour(focus) } }) : nil,
                           onClose: { endTour() }) {
                UltimateGallery(focus: focus, seen: tour.ultimatesSeen) { u in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tour.explain(u) }
                }
            }
        case .done:
            EmptyView()
        }
    }

    private func showHint(_ text: String, duringTour: Bool = false) {
        hintDuringTour = duringTour
        hint = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if hint == text && incoming == nil && selectedSlot == nil { hint = nil }
        }
    }
}

/// Schräger „NEU“-Aufkleber für frisch gezogene Karten; pulsiert leicht (über die Uhrzeit).
struct NewSticker: View {
    var body: some View {
        Text(L("NEU"))
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .frame(height: 16)
            .background(Capsule().fill(Theme.red))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
            .rotationEffect(.degrees(-12))
            .modifier(RoadBreathe(active: true, speed: 4.5))
            .accessibilityHidden(true)
    }
}

// MARK: - Ultimate wählen

/// Ultimate-Auswahl: oben die gewählte Ultimate groß mit Beschreibung, darunter alle fünf als Karten.
/// Antippen zeigt sie oben an, „Ausrüsten“ übernimmt sie mit Blitz und Haptik.
struct UltimatePickerSheet: View {
    @ObservedObject var store = ProfileStore.shared
    let onClose: () -> Void
    @State var preview: Ultimate?
    @State var equipPop = false
    @State var burst = 0

    private var shown: Ultimate { preview ?? store.activeUltimate }

    var body: some View {
        let u = shown
        let unlocked = store.isUnlocked(u)
        let equipped = store.activeUltimate == u
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Bühne
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [CardStyle.ultimate.opacity(unlocked ? 0.45 : 0.12), .clear],
                                                     center: .center, startRadius: 4, endRadius: 120))
                                .frame(width: 240, height: 240)
                                .scaleEffect(equipPop ? 1.25 : 1)
                            UltimateCard(ultimate: u, mana: unlocked ? GameState.maxMana : 0, usable: unlocked, compact: false)
                                .frame(width: 112)
                                .scaleEffect(equipPop ? 1.12 : 1)
                                .rotation3DEffect(.degrees(Double(burst) * 360), axis: (x: 0, y: 1, z: 0))
                                .overlay {
                                    if !unlocked {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 26, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(14)
                                            .background(Circle().fill(Color.black.opacity(0.55)))
                                    }
                                }
                        }
                        .frame(height: 190)
                        .id(u)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))

                        HStack(spacing: 8) {
                            Text(u.name)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(u.style.uppercased())
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(1)
                                .foregroundColor(Theme.navy)
                                .padding(.horizontal, 8)
                                .frame(height: 20)
                                .background(Capsule().fill(CardStyle.ultimate))
                        }
                        Text(u.description)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 330)
                        HStack(spacing: 14) {
                            fact("bolt.fill", L("{0} Mana", u.cost))
                            fact(u.keepsTurn ? "figure.walk" : "hourglass", u.keepsTurn ? L("Danach noch ein Zug") : L("Ersetzt deinen Zug"))
                            fact(u.needsTarget ? "scope" : "sparkles", u.needsTarget ? L("Mit Ziel") : L("Ohne Ziel"))
                        }

                        if equipped {
                            Label(L("Ausgerüstet"), systemImage: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.green)
                                .frame(height: 52)
                        } else if unlocked {
                            Button {
                                equip(u)
                            } label: {
                                Label(L("Ausrüsten"), systemImage: "sparkles")
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 52, textColor: Theme.navy))
                            .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
                        } else {
                            let arena = Arena.all.first { $0.number == u.arena }
                            VStack(spacing: 6) {
                                Label(L("Arena {0} · ab {1} Trophäen", u.arena, arena?.trophies ?? 0), systemImage: "lock.fill")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundColor(Theme.textSecondary)
                                ProgressPill(fraction: Double(store.profile.trophies) / Double(max(1, arena?.trophies ?? 1)),
                                             text: "\(store.profile.trophies)/\(arena?.trophies ?? 0)")
                                    .frame(width: 200)
                            }
                            .frame(height: 52)
                        }
                    }
                    .padding(.vertical, 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: u)

                    // Alle Ultimates
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(Ultimate.allCases) { option in
                            let open = store.isUnlocked(option)
                            Button {
                                Haptics.shared.play(.select)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { preview = option }
                            } label: {
                                VStack(spacing: 4) {
                                    UltimateCard(ultimate: option, mana: open ? GameState.maxMana : 0, isSelected: option == u, compact: true)
                                        .overlay(alignment: .topTrailing) {
                                            if store.activeUltimate == option {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Theme.green)
                                                    .background(Circle().fill(Theme.background))
                                                    .offset(x: 5, y: -5)
                                            } else if !open {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 9, weight: .black))
                                                    .foregroundColor(.white)
                                                    .padding(4)
                                                    .background(Circle().fill(Theme.panelHighlight))
                                                    .offset(x: 5, y: -5)
                                            }
                                        }
                                        .opacity(open ? 1 : 0.5)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.name + (open ? "" : L(", gesperrt")))
                        }
                    }
                    Text(L("Einsetzbar ab {0} Mana (Festung schon ab {1}). Dein Gegner sieht deine Wahl.", GameState.ultimateCost, Ultimate.fortress.cost))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.background
                    LinearGradient(colors: [CardStyle.ultimateDeep.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(L("Ultimate"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig"), action: onClose) }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    private func fact(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(CardStyle.ultimate)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 92)
    }

    private func equip(_ u: Ultimate) {
        store.profile.settings.ultimate = u
        Haptics.shared.play(.chestReveal)
        SoundPlayer.shared.play(.reward)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { burst += 1 }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { equipPop = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring()) { equipPop = false }
        }
    }
}


/// Vorlagen-Fenster im Stil des Ultimate-Fensters: oben die Bühne mit aufgefächerten Karten und der Ultimate,
/// Kurzinfos und „Übernehmen“, darunter alle Vorlagen zum Durchblättern.
struct PresetPickerSheet: View {
    @ObservedObject var store = ProfileStore.shared
    let onApplied: (DeckPreset) -> Void
    let onClose: () -> Void
    @State var preview: DeckPreset?
    @State var applyPop = false
    @State var burst = 0
    @State var fanned = false

    private var activePreset: DeckPreset? {
        DeckPreset.all.first { Set(store.activeDeck) == Set($0.cards) && store.activeUltimate == $0.ultimate }
    }

    private var shown: DeckPreset { preview ?? activePreset ?? DeckPreset.all[0] }

    var body: some View {
        let preset = shown
        let unlocked = store.isUnlocked(preset)
        let active = activePreset?.id == preset.id
        let avg = Double(preset.cards.map(\.cost).reduce(0, +)) / Double(max(1, preset.cards.count))
        let bonus = preset.cards.filter(\.keepsTurn).count
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Bühne: oben die vier Karten im Bogen, darunter frei die Ultimate – nichts überdeckt sich
                    VStack(spacing: 12) {
                        VStack(spacing: 6) {
                            ZStack {
                                ForEach(Array(preset.cards.enumerated()), id: \.offset) { i, card in
                                    let spread = Double(i) - 1.5
                                    CardView(card: card, isPlayable: store.isUnlocked(card))
                                        .frame(width: 60)
                                        .overlay(alignment: .topTrailing) {
                                            if !store.isUnlocked(card) {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 9, weight: .black))
                                                    .foregroundColor(.white)
                                                    .padding(4)
                                                    .background(Circle().fill(Color.black.opacity(0.6)))
                                            }
                                        }
                                        .rotationEffect(.degrees(fanned ? spread * 7 : 0), anchor: .bottom)
                                        .offset(x: fanned ? CGFloat(spread) * 64 : 0, y: fanned ? abs(CGFloat(spread)) * 7 : 0)
                                        .zIndex(-abs(spread))
                                }
                            }
                            .frame(height: 112)

                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(Theme.textMuted)
                                .frame(height: 14)

                            UltimateCard(ultimate: preset.ultimate, mana: store.isUnlocked(preset.ultimate) ? GameState.maxMana : 0,
                                         usable: unlocked, compact: false)
                                .frame(width: 70)
                                .scaleEffect(applyPop ? 1.12 : 1)
                                .rotation3DEffect(.degrees(Double(burst) * 360), axis: (x: 0, y: 1, z: 0))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            Ellipse()
                                .fill(RadialGradient(colors: [Theme.blueLight.opacity(unlocked ? 0.38 : 0.1), .clear],
                                                     center: .center, startRadius: 4, endRadius: 150))
                                .frame(width: 320, height: 250)
                                .scaleEffect(applyPop ? 1.2 : 1)
                        )
                        .id(preset.id)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))

                        HStack(spacing: 8) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(Theme.gold)
                            Text(preset.name)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Text(unlocked ? preset.strategy : lockedHint(preset))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(unlocked ? Theme.textSecondary : Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 330)
                        HStack(spacing: 14) {
                            fact("drop.fill", L("Ø {0} Mana", String(format: "%.1f", avg)))
                            fact("forward.fill", "\(bonus) " + L("Bonusaktionen"))
                            fact(preset.ultimate.icon, preset.ultimate.name)
                        }

                        if active {
                            Label(L("Aktiv"), systemImage: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.green)
                                .frame(height: 52)
                        } else if unlocked {
                            Button { apply(preset) } label: {
                                Label(L("Übernehmen"), systemImage: "square.stack.3d.up.fill")
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, height: 52, textColor: Theme.navy))
                            .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
                        } else {
                            Label(L("Noch gesperrt – aus Truhen oder für Splitter"), systemImage: "lock.fill")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(minHeight: 52)
                        }
                    }
                    .padding(.vertical, 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: preset.id)

                    // Alle Vorlagen
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(DeckPreset.all) { option in
                            tile(option, selected: option.id == preset.id)
                        }
                    }
                    Text(L("Ein Tipp übernimmt Karten und Ultimate. Danach kannst du jede Karte einzeln tauschen."))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.background
                    LinearGradient(colors: [Theme.blue.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(L("Vorlagen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig"), action: onClose) }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { fanned = true }
            }
        }
        .onChange(of: preview?.id) { _ in
            // Beim Blättern fächern die Karten neu auf
            fanned = false
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 30_000_000)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { fanned = true }
            }
        }
    }

    private func tile(_ option: DeckPreset, selected: Bool) -> some View {
        let open = store.isUnlocked(option)
        let isActive = activePreset?.id == option.id
        return Button {
            Haptics.shared.play(.select)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { preview = option }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selected ? Theme.gold.opacity(0.25) : Theme.panelHighlight)
                        .frame(width: 44, height: 44)
                    Image(systemName: option.icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(open ? Theme.gold : Theme.textMuted)
                }
                Text(option.name)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(open ? Theme.textPrimary : Theme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 2) {
                    ForEach(option.cards) { c in
                        CardArtThumb(art: "art-card-\(c.rawValue)", width: 14)
                            .opacity(open ? 1 : 0.45)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Theme.gold : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.green)
                        .background(Circle().fill(Theme.background))
                        .offset(x: 4, y: -4)
                } else if !open {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Theme.panelHighlight))
                        .offset(x: 4, y: -4)
                }
            }
            .scaleEffect(selected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.name + (open ? "" : L(", gesperrt")))
    }

    private func fact(_ icon: String, _ text: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.gold)
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 92)
    }

    private func lockedHint(_ preset: DeckPreset) -> String {
        let missing = preset.cards.filter { !store.isUnlocked($0) }
        if !missing.isEmpty {
            return L("Fehlt noch: ") + missing.map(\.name).joined(separator: ", ") + L(" – aus Truhen oder für Splitter.")
        }
        return L("Braucht die Ultimate {0} (Arena {1}).", preset.ultimate.name, preset.ultimate.arena)
    }

    private func apply(_ preset: DeckPreset) {
        store.apply(preset)
        onApplied(preset)
        Haptics.shared.play(.chestReveal)
        SoundPlayer.shared.play(.reward)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { burst += 1 }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { applyPop = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring()) { applyPop = false }
        }
    }
}

import SwiftUI

// MARK: - Splitter-Anzeige

/// Splitter in der Kopfzeile. Steigt der Stand, hüpft die Anzeige und ein „+N“ schwebt auf.
/// Ein Tipp öffnet den Splitter-Laden.
struct ShardPill: View {
    @ObservedObject var store = ProfileStore.shared
    @State var showShop = false
    @State var shown = 0
    @State var gain: Int?
    @State var pop = false

    var body: some View {
        Button {
            Haptics.shared.play(.select)
            showShop = true
        } label: {
            HStack(spacing: 4) {
                ShardIcon(size: 15)
                Text(ShardPill.short(shown))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.panelRaised))
            .overlay(Capsule().strokeBorder(ShardStyle.color.opacity(pop ? 0.9 : 0), lineWidth: 1.5))
            .scaleEffect(pop ? 1.12 : 1)
            .overlay(alignment: .top) {
                if let gain {
                    Text("+\(gain)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(ShardStyle.color)
                        .shadow(color: .black, radius: 2)
                        .offset(y: -18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("{0} Splitter. Tippen für den Laden", store.profile.shards))
        .onAppear { shown = store.profile.shards }
        .onChange(of: store.profile.shards) { new in
            let diff = new - shown
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { shown = new }
            guard diff > 0 else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                gain = diff
                pop = true
            }
            Haptics.shared.play(.chestCount)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                withAnimation(.spring()) { pop = false }
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.easeOut) { gain = nil }
            }
        }
        .sheet(isPresented: $showShop) { ShardShopSheet() }
    }
}

extension ShardPill {
    /// Kurzform für enge Kopfzeilen: 999 · 1.2k · 12k · 1.2M
    static func short(_ n: Int) -> String {
        func one(_ v: Double, _ unit: String) -> String {
            let r = (v * 10).rounded(.down) / 10
            return r == r.rounded() ? "\(Int(r))\(unit)" : String(format: "%.1f%@", r, unit)
        }
        switch n {
        case ..<1000: return "\(n)"
        case ..<10_000: return one(Double(n) / 1000, "k")
        case ..<1_000_000: return "\(n / 1000)k"
        default: return one(Double(n) / 1_000_000, "M")
        }
    }
}

/// Kristall-Symbol der Splitter (Raute mit Glanzkante).
struct ShardIcon: View {
    var size: CGFloat = 16

    var body: some View {
        ZStack {
            Image(systemName: "diamond.fill")
                .font(.system(size: size, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color.white, ShardStyle.color, ShardStyle.deep], startPoint: .top, endPoint: .bottom))
            Image(systemName: "diamond")
                .font(.system(size: size * 0.55, weight: .heavy))
                .foregroundColor(.white.opacity(0.7))
        }
        .shadow(color: ShardStyle.color.opacity(0.6), radius: size * 0.25)
    }
}

// MARK: - Laden

/// Splitter-Laden: oben die Schatzkammer mit Stand und Sparziel, darunter Reiter statt einer langen Liste.
/// Jeder Artikel ist eine Kachel mit Vorschau auf farbigem Grund, Preis-Knopf und – wenn noch Splitter fehlen –
/// einem Balken, wie weit man ist. Ein Kauf endet mit einer kleinen Feier.
struct ShardShopSheet: View {
    @ObservedObject var store = ProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State var confirm: (item: ShopItem, price: Int, offerID: String?)?
    @State var chestToOpen: Chest?
    @State var tab: ShopTab = .offers
    @State var celebrate: ShopItem?

    enum ShopTab: CaseIterable, Identifiable {
        case offers, cards, chests, style, extras
        var id: Self { self }
        var title: String {
            switch self {
            case .offers: return L("Angebote")
            case .cards: return L("Karten")
            case .chests: return L("Truhen")
            case .style: return L("Style")
            case .extras: return L("Extras")
            }
        }
        var icon: String {
            switch self {
            case .offers: return "sparkles"
            case .cards: return "rectangle.stack.fill"
            case .chests: return "shippingbox.fill"
            case .style: return "paintpalette.fill"
            case .extras: return "snowflake"
            }
        }
    }

    private let grid = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    treasury
                    tabBar
                    Group {
                        switch tab {
                        case .offers: offersTab
                        case .cards: cardsTab
                        case .chests: chestsTab
                        case .style: styleTab
                        case .extras: extrasTab
                        }
                    }
                    .id(tab)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.background
                    RadialGradient(colors: [ShardStyle.deep.opacity(0.35), .clear], center: .top, startRadius: 10, endRadius: 420)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(L("Splitter-Laden"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
            .overlay {
                if let item = celebrate {
                    PurchaseCelebration(item: item) {
                        withAnimation(.easeOut(duration: 0.2)) { celebrate = nil }
                    } preview: { preview(item, size: 96) }
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $chestToOpen) { c in ChestOpeningView(start: c, only: [c.id]) }
        .confirmationDialog(confirm.map { L("{0} kaufen?", $0.item.title) } ?? "",
                            isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } }),
                            titleVisibility: .visible) {
            if let c = confirm {
                Button(L("Für {0} Splitter kaufen", c.price)) { purchase(c.item, price: c.price, offerID: c.offerID) }
                Button(L("Abbrechen"), role: .cancel) { confirm = nil }
            }
        }
    }

    // MARK: Schatzkammer

    private var treasury: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                ShardCrystal()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.profile.shards)")
                        .font(.system(size: 38, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(LinearGradient(colors: [.white, ShardStyle.color], startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.profile.shards)
                    Text(L("Splitter · insgesamt {0} gesammelt", store.profile.shardsEarned))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer(minLength: 0)
            }
            goalCard
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Theme.panelRaised, Theme.panel], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ShardStyle.color.opacity(0.35), lineWidth: 1))
        .shadow(color: ShardStyle.deep.opacity(0.35), radius: 14)
    }

    @ViewBuilder
    private var goalCard: some View {
        if let goal = store.shardGoalItem {
            let have = store.profile.shards
            let frac = min(1, Double(have) / Double(max(1, goal.price)))
            HStack(spacing: 10) {
                preview(goal.item, size: 34)
                    .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(L("Sparziel: {0}", goal.item.shortTitle))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.gold)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Button {
                            store.setShardGoal(nil)
                            Haptics.shared.play(.select)
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("Sparziel entfernen"))
                    }
                    ShopProgressBar(fraction: frac, tint: Theme.gold)
                    Text(have >= goal.price ? L("Genug gesammelt – hol es dir!") : L("{0} / {1} · noch {2}", have, goal.price, goal.price - have))
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundColor(have >= goal.price ? Theme.gold : Theme.textSecondary)
                }
                if have >= goal.price && !store.isOwned(goal.item) {
                    Button { confirm = (goal.item, goal.price, nil) } label: {
                        Text(L("Holen"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(Theme.navy)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Capsule().fill(Theme.gold))
                            .overlay(ShineSweep().clipShape(Capsule()).allowsHitTesting(false))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.gold.opacity(0.8))
                Text(L("Tipp auf den Stern einer Kachel: Das wird dein Sparziel, der Fortschritt steht auf der Startseite."))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Reiter

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShopTab.allCases) { t in
                    Button {
                        guard t != tab else { return }
                        Haptics.shared.play(.select)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
                    } label: {
                        Label(t.title, systemImage: t.icon)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(t == tab ? Theme.navy : Theme.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            // Jede Kapsel trägt ihr eigenes Leuchten (an/aus). Vorher wanderte ein gemeinsames
                            // Leuchten per matchedGeometryEffect – beim Scrollen der Leiste oder schnellem Tippen
                            // blieb es manchmal hängen oder sprang an die falsche Stelle.
                            .background(
                                ZStack {
                                    Capsule().fill(Theme.panelRaised)
                                    Capsule()
                                        .fill(LinearGradient(colors: [.white, ShardStyle.color], startPoint: .top, endPoint: .bottom))
                                        .shadow(color: ShardStyle.color.opacity(0.6), radius: 8)
                                        .opacity(t == tab ? 1 : 0)
                                        .scaleEffect(t == tab ? 1 : 0.85)
                                }
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: tab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Inhalte

    private var offersTab: some View {
        let offers = store.dailyOffers()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Heute im Laden"))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                    Label(L("Neu in {0}", ProfileStore.untilMidnightShort(ctx.date)), systemImage: "clock")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundColor(Theme.textMuted)
                }
            }
            if let hero = offers.first {
                heroOffer(hero)
            }
            LazyVGrid(columns: grid, spacing: 10) {
                ForEach(offers.dropFirst()) { offer in
                    tile(offer.item, subtitle: subtitle(for: offer.item), price: offer.price,
                         basePrice: offer.basePrice, offerID: offer.id)
                }
            }
        }
    }

    private var cardsTab: some View {
        let cards = CardType.allCases.filter { !store.isUnlocked($0) }
            .sorted { (store.level >= $0.tier.gateLevel ? 0 : 1, $0.tier.price) < (store.level >= $1.tier.gateLevel ? 0 : 1, $1.tier.price) }
        return VStack(alignment: .leading, spacing: 10) {
            tabIntro(L("Neue Karten für dein Deck – jede einmal kaufen, für immer behalten."))
            if cards.isEmpty {
                emptyState(icon: "checkmark.seal.fill", text: L("Du hast schon alle Karten. Stark!"))
            } else {
                LazyVGrid(columns: grid, spacing: 10) {
                    ForEach(cards) { card in tile(.card(card), subtitle: subtitle(for: .card(card))) }
                }
            }
        }
    }

    private var chestsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            tabIntro(L("Truhen öffnen sich sofort – mit Chance auf Aufwertung beim Antippen."))
            LazyVGrid(columns: grid, spacing: 10) {
                tile(.chest(.gold), subtitle: L("Garantiert XP und Splitter, mit Glück eine Karte"))
                tile(.chest(.magic), subtitle: L("Hohe Chance auf eine neue Karte"))
            }
        }
    }

    private var styleTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            styleSection(L("Avatare"), items: Avatar.allCases.filter { $0 != .knight }.map { ShopItem.avatar($0) })
            styleSection(L("Avatar-Rahmen"), items: AvatarFrame.shopFrames.map { ShopItem.frame($0) })
            styleSection(L("Sammelbretter"), items: BoardTheme.allCases.filter(\.isCollectible).map { ShopItem.board($0) })
        }
    }

    private func styleSection(_ title: String, items: [ShopItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Theme.textSecondary)
            LazyVGrid(columns: grid, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in tile(item, subtitle: subtitle(for: item)) }
            }
        }
    }

    private var extrasTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            tabIntro(L("Rettet deine Serie, wenn du einen Tag verpasst (max. {0})", ProfileStore.maxFreezes))
            LazyVGrid(columns: grid, spacing: 10) {
                tile(.freeze, subtitle: L("Du hast {0} von {1}", store.profile.streakFreezes, ProfileStore.maxFreezes))
            }
        }
    }

    private func tabIntro(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 34, weight: .bold)).foregroundColor(Theme.green)
            Text(text).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func subtitle(for item: ShopItem) -> String {
        switch item {
        case .card(let c):
            return store.level >= c.tier.gateLevel ? c.tier.name : L("ab Level {0}", c.tier.gateLevel)
        case .chest(let r):
            return r == .magic ? L("Hohe Chance auf eine neue Karte") : L("Garantiert XP und Splitter, mit Glück eine Karte")
        case .avatar(let a): return a.rarity.name
        case .frame(let f): return f.rarity.name
        case .board: return L("Brett für alle Partien")
        case .freeze: return L("Rettet deine Serie")
        }
    }

    private func accent(_ item: ShopItem) -> Color {
        switch item {
        case .chest(let r): return r.glowColor
        case .card(let c): return Color(hex: c.tier.colorHex)
        case .avatar(let a): return Color(hex: a.rarity.colorHex)
        case .frame(let f): return Color(hex: f.rarity.colorHex)
        case .board: return Color(hex: 0xC9A2FF)
        case .freeze: return FlameStyle.ice
        }
    }

    // MARK: Angebot des Tages

    private func heroOffer(_ offer: ShopOffer) -> some View {
        let bought = store.isBought(offer) || store.isOwned(offer.item)
        let affordable = store.profile.shards >= offer.price
        let color = accent(offer.item)
        return Button {
            buyTapped(offer.item, price: offer.price, offerID: offer.id, bought: bought, affordable: affordable)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    if !bought {
                        LightRays(color: color, count: 10, speed: 0.25)
                            .frame(width: 150, height: 150)
                            .opacity(0.7)
                    }
                    preview(offer.item, size: 82)
                        .saturation(bought ? 0 : 1)
                }
                .frame(width: 104, height: 104)
                .clipped()
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("ANGEBOT DES TAGES"))
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.3)
                        .foregroundColor(color)
                    Text(offer.item.title)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(subtitle(for: offer.item))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(2)
                    priceButton(price: offer.price, basePrice: offer.basePrice, bought: bought, owned: false, gated: false, affordable: affordable)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [color.opacity(0.28), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(color.opacity(bought ? 0.15 : 0.6), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(ShopPressStyle())
    }

    // MARK: Kachel

    private func tile(_ item: ShopItem, subtitle: String, price explicitPrice: Int? = nil, basePrice: Int? = nil, offerID: String? = nil) -> some View {
        let price = explicitPrice ?? store.basePrice(item)
        let base = basePrice ?? price
        let bought = offerID.map { id in store.isBought(ShopOffer(id: id, item: item, price: price, basePrice: base)) } ?? false
        let owned = store.isOwned(item)
        let gated: Bool = {
            if case .card(let c) = item { return store.level < c.tier.gateLevel }
            return false
        }()
        let have = store.profile.shards
        let affordable = have >= price
        let isGoal = store.profile.shardGoal == item.goalID
        let color = accent(item)
        let discount = base > price ? Int((1 - Double(price) / Double(base)) * 100 + 0.5) : 0
        // Kachel ohne äußeren Knopf, damit der Stern darin eigenständig antippbar bleibt
        return VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(RadialGradient(colors: [color.opacity(owned || bought ? 0.12 : 0.4), color.opacity(0.06)],
                                             center: .center, startRadius: 4, endRadius: 70))
                    preview(item, size: 56)
                        .saturation(gated || owned || bought ? 0.25 : 1)
                    if gated {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                            .padding(7)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                }
                .frame(height: 84)
                .overlay(alignment: .topLeading) {
                    if discount > 0 && !bought {
                        Text("−\(discount) %")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(Theme.navy)
                            .padding(.horizontal, 6)
                            .frame(height: 18)
                            .background(Capsule().fill(Theme.gold))
                            .rotationEffect(.degrees(-8))
                            .offset(x: -4, y: -4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !owned && !gated && !bought {
                        Button {
                            store.setShardGoal(isGoal ? nil : item)
                            Haptics.shared.play(.select)
                        } label: {
                            Image(systemName: isGoal ? "star.fill" : "star")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isGoal ? Theme.gold : Theme.textMuted)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isGoal ? L("Sparziel entfernen") : L("Als Sparziel setzen"))
                    }
                }
                VStack(spacing: 2) {
                    Text(item.shortTitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(color.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                priceButton(price: price, basePrice: base, bought: bought, owned: owned, gated: gated, affordable: affordable,
                            freezeFull: item == .freeze)
                if !owned && !gated && !bought && !affordable {
                    ShopProgressBar(fraction: Double(have) / Double(max(1, price)), tint: ShardStyle.color)
                        .padding(.horizontal, 4)
                }
            }
            .padding(10)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isGoal ? Theme.gold.opacity(0.7) : color.opacity(0.25), lineWidth: isGoal ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture {
                buyTapped(item, price: price, offerID: offerID, bought: bought || owned || gated, affordable: affordable)
            }
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func priceButton(price: Int, basePrice: Int, bought: Bool, owned: Bool, gated: Bool, affordable: Bool, freezeFull: Bool = false) -> some View {
        if bought || owned {
            Label(freezeFull ? L("Voll") : (bought ? L("Gekauft") : L("Im Besitz")), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.green)
                .frame(height: 30)
        } else if gated {
            Text(L("Noch gesperrt"))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textMuted)
                .frame(height: 30)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "diamond.fill").font(.system(size: 11, weight: .black))
                Text("\(price)").font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                if basePrice > price {
                    Text("\(basePrice)")
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .strikethrough()
                        .opacity(0.6)
                }
            }
            .foregroundColor(affordable ? Theme.navy : Theme.redLight)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .frame(minWidth: 84)
            .background(
                Capsule().fill(affordable
                               ? AnyShapeStyle(LinearGradient(colors: [.white, ShardStyle.color], startPoint: .top, endPoint: .bottom))
                               : AnyShapeStyle(Color.black.opacity(0.3)))
            )
            .overlay {
                if affordable { ShineSweep().clipShape(Capsule()).allowsHitTesting(false) }
            }
        }
    }

    @ViewBuilder
    private func preview(_ item: ShopItem, size: CGFloat) -> some View {
        switch item {
        case .chest(let r):
            ChestView(rarity: r, size: size * 1.1)
        case .card(let c):
            CardView(card: c, compact: true)
                .frame(width: size * 0.8)
        case .board(let b):
            let colors = BoardColors.forTheme(b)
            VStack(spacing: 0) {
                HStack(spacing: 0) { Rectangle().fill(colors.light); Rectangle().fill(colors.dark) }
                HStack(spacing: 0) { Rectangle().fill(colors.dark); Rectangle().fill(colors.light) }
            }
            .frame(width: size * 0.85, height: size * 0.85)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        case .frame(let f):
            PlayerAvatar(size: size, frame: f)
        case .avatar(let a):
            PlayerAvatar(size: size, frame: AvatarFrame.none, avatar: a)
        case .freeze:
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(FlameStyle.ice.opacity(0.25))
                Image(systemName: "snowflake")
                    .font(.system(size: size * 0.45, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: size * 0.85, height: size * 0.85)
        }
    }

    // MARK: Kaufen

    private func buyTapped(_ item: ShopItem, price: Int, offerID: String?, bought: Bool, affordable: Bool) {
        guard !bought else { return }
        if affordable {
            Haptics.shared.play(.select)
            confirm = (item, price, offerID)
        } else {
            Haptics.shared.play(.invalid)
        }
    }

    private func purchase(_ item: ShopItem, price: Int, offerID: String?) {
        confirm = nil
        guard let result = store.buy(item, price: price, offerID: offerID) else {
            Haptics.shared.play(.invalid)
            return
        }
        Haptics.shared.play(.shardShower)
        SoundPlayer.shared.play(.shardShower, volume: 0.7)
        switch result {
        case .chest(let chest):
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                Haptics.shared.play(.chestLand)
                chestToOpen = chest
            }
        case .unlocked(let item):
            Haptics.shared.play(.chestBigReveal)
            SoundPlayer.shared.play(.rewardBig)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { celebrate = item }
        }
    }
}

/// Leichtes Eindrücken beim Antippen einer Kachel.
private struct ShopPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Dünner Fortschrittsbalken (Splitter bis zum Preis).
struct ShopProgressBar: View {
    let fraction: Double
    var tint: Color = ShardStyle.color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.6), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(5, geo.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: 6)
    }
}

/// Großer Kristall der Schatzkammer: schwebt, funkelt und dreht sich leicht.
struct ShardCrystal: View {
    @Environment(\.liveAnimations) private var live
    @Environment(\.animationClock) private var clock
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { ctx in
            let t = clock.time(ctx.date)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [ShardStyle.color.opacity(0.55), .clear], center: .center, startRadius: 2, endRadius: 34))
                    .scaleEffect(1 + 0.08 * sin(t * 2))
                ShardIcon(size: 40)
                    .rotation3DEffect(.degrees(sin(t * 1.3) * 18), axis: (x: 0, y: 1, z: 0))
                    .offset(y: CGFloat(sin(t * 1.8)) * 3)
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .offset(x: 18, y: -18)
                    .opacity(max(0, sin(t * 2.6)))
                    .scaleEffect(0.6 + 0.4 * max(0, sin(t * 2.6)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Feier nach einem Kauf: Strahlen, Konfetti, der Artikel springt groß herein.
struct PurchaseCelebration<Preview: View>: View {
    let item: ShopItem
    let onClose: () -> Void
    @ViewBuilder let preview: () -> Preview
    @State private var pop = false
    @State private var seed = UInt64.random(in: 1...UInt64.max)

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            LightRays(colors: [ShardStyle.color, Theme.gold], count: 14, speed: 0.3)
                .frame(width: 700, height: 700)
                .opacity(pop ? 0.9 : 0)
            ConfettiView(seed: seed).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 16) {
                preview()
                    .scaleEffect(pop ? 1 : 0.2)
                    .rotationEffect(.degrees(pop ? 0 : -25))
                    .shadow(color: ShardStyle.color.opacity(0.8), radius: 24)
                Text(L("GEHÖRT DIR!"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                    .shadow(color: CardStyle.ultimateDeep, radius: 0, y: 4)
                    .rotationEffect(.degrees(-4))
                    .scaleEffect(pop ? 1 : 2.4)
                    .opacity(pop ? 1 : 0)
                Text(item.title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(pop ? 1 : 0)
                Text(L("Tippen zum Fortfahren"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 10)
                    .opacity(pop ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onClose)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { pop = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                onClose()
            }
        }
    }
}

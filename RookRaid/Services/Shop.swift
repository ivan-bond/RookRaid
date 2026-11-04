import Foundation

// MARK: - Splitter-Laden

/// Was man im Laden kaufen kann.
enum ShopItem: Equatable {
    case chest(ChestRarity)
    case card(CardType)
    case board(BoardTheme)
    case frame(AvatarFrame)
    case avatar(Avatar)
    case freeze

    /// Kennung für das Sparziel.
    var goalID: String {
        switch self {
        case .chest(let r): return "chest.\(r.rawValue)"
        case .card(let c): return "card.\(c.rawValue)"
        case .board(let b): return "board.\(b.rawValue)"
        case .frame(let f): return "frame.\(f.rawValue)"
        case .avatar(let a): return "avatar.\(a.rawValue)"
        case .freeze: return "freeze"
        }
    }

    var title: String {
        switch self {
        case .chest(let r): return r.name
        case .card(let c): return c.name
        case .board(let b): return L("Brett „{0}“", b.name)
        case .frame(let f): return L("Rahmen „{0}“", f.name)
        case .avatar(let a): return L("Avatar „{0}“", a.name)
        case .freeze: return L("Flammenschutz")
        }
    }

    var shortTitle: String {
        switch self {
        case .chest(let r): return r.name
        case .card(let c): return c.name
        case .board(let b): return b.name
        case .frame(let f): return f.name
        case .avatar(let a): return a.name
        case .freeze: return L("Flammenschutz")
        }
    }
}

/// Tagesangebot: wechselt um Mitternacht, jedes einmal pro Tag kaufbar.
struct ShopOffer: Identifiable, Equatable {
    let id: String
    let item: ShopItem
    let price: Int
    let basePrice: Int
    var discount: Int { basePrice > price ? Int((1 - Double(price) / Double(basePrice)) * 100 + 0.5) : 0 }
}

/// Ergebnis eines Kaufs.
enum ShopPurchase {
    case chest(Chest)
    case unlocked(ShopItem)
}

extension ProfileStore {
    static let shopFramePrice = 500
    static let chestPrices: [ChestRarity: Int] = [.silver: 60, .gold: 220, .magic: 600, .legendary: 900]

    /// Fester Zufall pro Tag (gleiche Angebote den ganzen Tag, auch nach Neustart).
    private static func seed(for day: String) -> UInt64 {
        var h: UInt64 = 1469598103934665603
        for b in day.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return h
    }

    private struct DayRNG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double((state >> 33) % 1_000_000) / 1_000_000
        }
        mutating func pick<T>(_ a: [T]) -> T? { a.isEmpty ? nil : a[min(a.count - 1, Int(next() * Double(a.count)))] }
    }

    /// Drei Tagesangebote: eine Truhe, eine Karte (−20 %) und etwas zum Angeben.
    func dailyOffers(now: Date = Date()) -> [ShopOffer] {
        let day = ProfileStore.dayKey(now)
        var rng = DayRNG(state: ProfileStore.seed(for: day))
        var offers: [ShopOffer] = []

        // 1) Truhe: meist Gold, manchmal Magisch
        let chest: ChestRarity = rng.next() < 0.7 ? .gold : .magic
        let cp = ProfileStore.chestPrices[chest] ?? 220
        offers.append(ShopOffer(id: "\(day).chest", item: .chest(chest), price: cp, basePrice: cp))

        // 2) Karte mit Rabatt (nur, was schon zum Level passt), sonst eine Silbertruhe zum Schnäppchenpreis
        let cards = CardType.allCases.filter { !isUnlocked($0) && level >= $0.tier.gateLevel }
        if let card = rng.pick(cards) {
            offers.append(ShopOffer(id: "\(day).card", item: .card(card), price: card.tier.price * 4 / 5, basePrice: card.tier.price))
        } else {
            offers.append(ShopOffer(id: "\(day).silver", item: .chest(.silver), price: 40, basePrice: 60))
        }

        // 3) Laden-Rahmen oder Sammelbrett, sonst eine zweite Goldtruhe
        var cosmetics: [ShopItem] = AvatarFrame.shopFrames.filter { !profile.shopFrames.contains($0.rawValue) }.map { .frame($0) }
        cosmetics += Avatar.allCases.filter { !isOwned($0) }.map { .avatar($0) }
        cosmetics += BoardTheme.allCases.filter { $0.isCollectible && !isOwned($0) }.map { .board($0) }
        if let item = rng.pick(cosmetics) {
            let base = basePrice(item)
            offers.append(ShopOffer(id: "\(day).cosmetic", item: item, price: base * 9 / 10, basePrice: base))
        } else {
            let gold = ProfileStore.chestPrices[.gold] ?? 220
            offers.append(ShopOffer(id: "\(day).gold2", item: .chest(.gold), price: gold * 4 / 5, basePrice: gold))
        }
        return offers
    }

    func basePrice(_ item: ShopItem) -> Int {
        switch item {
        case .chest(let r): return ProfileStore.chestPrices[r] ?? 220
        case .card(let c): return c.tier.price
        case .board: return BoardTheme.collectiblePrice
        case .frame: return ProfileStore.shopFramePrice
        case .avatar(let a): return a.price
        case .freeze: return ProfileStore.freezePrice
        }
    }

    func isBought(_ offer: ShopOffer) -> Bool {
        profile.shopDay == ProfileStore.dayKey() && profile.shopBought.contains(offer.id)
    }

    /// Schon im Besitz / nicht (mehr) kaufbar?
    func isOwned(_ item: ShopItem) -> Bool {
        switch item {
        case .chest: return false
        case .card(let c): return isUnlocked(c)
        case .board(let b): return isOwned(b)
        case .frame(let f): return profile.shopFrames.contains(f.rawValue)
        case .avatar(let a): return isOwned(a)
        case .freeze: return profile.streakFreezes >= ProfileStore.maxFreezes
        }
    }

    /// Kauf mit Preis (Tagesangebot oder Dauerangebot). Truhen landen im Lager und werden zurückgegeben.
    func buy(_ item: ShopItem, price: Int, offerID: String? = nil) -> ShopPurchase? {
        if let offerID, profile.shopDay == ProfileStore.dayKey(), profile.shopBought.contains(offerID) { return nil }
        guard !isOwned(item), profile.shards >= price else { return nil }
        if case .card(let c) = item, level < c.tier.gateLevel { return nil }
        profile.shards -= price
        if let offerID {
            let today = ProfileStore.dayKey()
            if profile.shopDay != today {
                profile.shopDay = today
                profile.shopBought = []
            }
            profile.shopBought.append(offerID)
        }
        if profile.shardGoal == item.goalID { profile.shardGoal = nil }
        switch item {
        case .chest(let r):
            grantChest(.shop, r)
            return profile.chests.last.map { ShopPurchase.chest($0) }
        case .card(let c):
            profile.unlockedCards.append(c.rawValue)
            profile.seenCards.append(c.rawValue)
            profile.cardsBought += 1
        case .board(let b):
            profile.ownedBoards.append(b.rawValue)
        case .frame(let f):
            profile.shopFrames.append(f.rawValue)
            profile.selectedFrame = f.rawValue
        case .avatar(let a):
            profile.ownedAvatars.append(a.rawValue)
            profile.selectedAvatar = a.rawValue
        case .freeze:
            profile.streakFreezes += 1
        }
        return .unlocked(item)
    }

    // MARK: Sparziel

    /// Gewähltes Sparziel mit Preis (nil, wenn keins oder schon im Besitz).
    var shardGoalItem: (item: ShopItem, price: Int)? {
        guard let id = profile.shardGoal else { return nil }
        let parts = id.split(separator: ".").map(String.init)
        let item: ShopItem?
        switch parts.first {
        case "card": item = parts.count > 1 ? CardType(rawValue: parts[1]).map { .card($0) } : nil
        case "board": item = parts.count > 1 ? BoardTheme(rawValue: parts[1]).map { .board($0) } : nil
        case "frame": item = parts.count > 1 ? AvatarFrame(rawValue: parts[1]).map { .frame($0) } : nil
        case "avatar": item = parts.count > 1 ? Avatar(rawValue: parts[1]).map { .avatar($0) } : nil
        case "chest": item = parts.count > 1 ? Int(parts[1]).flatMap { ChestRarity(rawValue: $0) }.map { .chest($0) } : nil
        case "freeze": item = .freeze
        default: item = nil
        }
        guard let item, !isOwned(item) else { return nil }
        return (item, basePrice(item))
    }

    func setShardGoal(_ item: ShopItem?) {
        profile.shardGoal = item?.goalID
    }
}

import Foundation

// MARK: - Trophäenpfad

/// Belohnung auf einer Stufe der Trophäenpfad.
enum RoadReward: Equatable {
    case chest(ChestRarity)
    case shards(Int)
    case board(BoardTheme)
    /// Neue Arena: Arena-Truhe, dazu werden die Ultimates der Arena automatisch frei.
    case arena(Int, ChestRarity)

    var title: String {
        switch self {
        case .chest(let r): return r.name
        case .shards(let n): return L("{0} Splitter", n)
        case .board(let b): return L("Brett „{0}“", b.name)
        case .arena(_, let r): return r.name
        }
    }
}

/// Eine Stufe der Straße: ab dieser Trophäenzahl abholbar.
struct RoadStep: Identifiable, Equatable {
    let trophies: Int
    let reward: RoadReward
    var id: Int { trophies }

    var arena: Arena? {
        if case .arena(let n, _) = reward { return Arena.all.first { $0.number == n } }
        return nil
    }
}

/// Was beim Abholen herauskam.
enum RoadClaim {
    case chest(Chest)
    case shards(Int)
    case board(BoardTheme)
}

extension ProfileStore {
    /// Alle 50–150 Trophäen eine Belohnung; Arenen sind die großen Meilensteine.
    static let road: [RoadStep] = [
        RoadStep(trophies: 50, reward: .chest(.silver)),
        RoadStep(trophies: 90, reward: .arena(2, .magic)),
        RoadStep(trophies: 150, reward: .shards(100)),
        RoadStep(trophies: 200, reward: .chest(.gold)),
        RoadStep(trophies: 240, reward: .arena(3, .legendary)),
        RoadStep(trophies: 300, reward: .board(.emerald)),
        RoadStep(trophies: 400, reward: .chest(.gold)),
        RoadStep(trophies: 500, reward: .shards(200)),
        RoadStep(trophies: 600, reward: .arena(4, .magic)),
        RoadStep(trophies: 700, reward: .chest(.gold)),
        RoadStep(trophies: 800, reward: .board(.lava)),
        RoadStep(trophies: 900, reward: .chest(.magic)),
        RoadStep(trophies: 1000, reward: .shards(300)),
        RoadStep(trophies: 1100, reward: .chest(.gold)),
        RoadStep(trophies: 1200, reward: .arena(5, .legendary)),
        RoadStep(trophies: 1350, reward: .chest(.magic)),
        RoadStep(trophies: 1500, reward: .board(.midnight)),
        RoadStep(trophies: 1650, reward: .chest(.gold)),
        RoadStep(trophies: 1800, reward: .chest(.magic)),
        RoadStep(trophies: 1950, reward: .shards(500)),
        RoadStep(trophies: 2100, reward: .arena(6, .legendary)),
        RoadStep(trophies: 2400, reward: .chest(.legendary))
    ]

    /// Maßgeblich ist der Rekord: Wer wieder etwas abrutscht, behält seine Stufen.
    var roadTrophies: Int { max(profile.trophies, profile.bestTrophies) }

    func isClaimed(_ step: RoadStep) -> Bool {
        if profile.roadClaimed.contains(step.trophies) { return true }
        // Arena-Truhen aus älteren Versionen zählen als abgeholt.
        if case .arena(let n, _) = step.reward, n <= profile.arenaChestsGranted { return true }
        return false
    }

    func isReached(_ step: RoadStep) -> Bool { roadTrophies >= step.trophies }

    func canClaim(_ step: RoadStep) -> Bool { isReached(step) && !isClaimed(step) }

    var claimableRoadSteps: [RoadStep] { ProfileStore.road.filter { canClaim($0) } }

    var nextRoadStep: RoadStep? { ProfileStore.road.first { !isReached($0) } }

    /// Belohnung abholen. Ein Brett, das schon aus einer Truhe kam, wird zu Splittern.
    @discardableResult
    func claim(_ step: RoadStep) -> RoadClaim? {
        guard canClaim(step) else { return nil }
        profile.roadClaimed.append(step.trophies)
        switch step.reward {
        case .chest(let rarity):
            grantChest(.road, rarity, label: "\(step.trophies) Trophäen")
            return profile.chests.last.map { RoadClaim.chest($0) }
        case .arena(let n, let rarity):
            profile.arenaChestsGranted = max(profile.arenaChestsGranted, n)
            let name = Arena.all.first { $0.number == n }?.name ?? L("Arena {0}", n)
            grantChest(.arena, rarity, label: name)
            return profile.chests.last.map { RoadClaim.chest($0) }
        case .shards(let n):
            earnShards(n)
            return .shards(n)
        case .board(let board):
            if profile.ownedBoards.contains(board.rawValue) {
                earnShards(BoardTheme.collectiblePrice)
                return .shards(BoardTheme.collectiblePrice)
            }
            profile.ownedBoards.append(board.rawValue)
            return .board(board)
        }
    }
}

import Foundation

// MARK: - Flammen: Flammenschutz und Meilensteine

/// Belohnung für einen Flammen-Meilenstein (einmalig pro Profil).
struct StreakMilestone: Identifiable {
    let days: Int
    let chest: ChestRarity?
    let shards: Int
    let freeze: Bool
    var id: Int { days }

    var rewardText: String {
        var parts: [String] = []
        if let chest { parts.append(chest.name) }
        if shards > 0 { parts.append(L("{0} Splitter", shards)) }
        if freeze { parts.append(L("Flammenschutz")) }
        return parts.joined(separator: " + ")
    }
}

extension ProfileStore {
    static let maxFreezes = 2
    static let freezePrice = 200

    static let streakMilestones: [StreakMilestone] = [
        StreakMilestone(days: 3, chest: nil, shards: 25, freeze: false),
        StreakMilestone(days: 7, chest: .gold, shards: 0, freeze: true),
        StreakMilestone(days: 14, chest: nil, shards: 100, freeze: false),
        StreakMilestone(days: 30, chest: .magic, shards: 0, freeze: true),
        StreakMilestone(days: 50, chest: nil, shards: 250, freeze: false),
        StreakMilestone(days: 100, chest: .legendary, shards: 0, freeze: true),
        StreakMilestone(days: 365, chest: .legendary, shards: 1000, freeze: true)
    ]

    var nextStreakMilestone: StreakMilestone? {
        ProfileStore.streakMilestones.first { !profile.streakMilestones.contains($0.days) }
    }

    /// Tageskennung („2026-10-12“) → Datum (Mitternacht).
    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    func wasFrozen(on date: Date) -> Bool { profile.frozenDays.contains(ProfileStore.dayKey(date)) }

    /// Beim Öffnen der App: Wurden Tage verpasst, retten vorhandene Flammenschutze die Serie.
    /// Reicht der Schutz nicht für alle Lücken, erlischt die Serie wie bisher.
    func checkStreak(now: Date = Date()) {
        guard profile.streak > 0, let lastKey = profile.lastStreakDay,
              let last = ProfileStore.date(fromKey: lastKey) else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let gap = cal.dateComponents([.day], from: last, to: today).day ?? 0
        let missed = gap - 1
        guard missed > 0, missed <= profile.streakFreezes else { return }
        var p = profile
        for d in 1...missed {
            if let day = cal.date(byAdding: .day, value: d, to: last) {
                let key = ProfileStore.dayKey(day)
                if !p.frozenDays.contains(key) { p.frozenDays.append(key) }
            }
        }
        if p.frozenDays.count > 400 { p.frozenDays = Array(p.frozenDays.suffix(400)) }
        p.streakFreezes -= missed
        // Die Serie läuft weiter, als hätte man gestern gespielt (sie wächst durch Eis aber nicht).
        p.lastStreakDay = ProfileStore.dayKey(cal.date(byAdding: .day, value: -1, to: today) ?? today)
        p.freezeNotice = missed
        profile = p
    }

    var canBuyFreeze: Bool { profile.streakFreezes < ProfileStore.maxFreezes && profile.shards >= ProfileStore.freezePrice }

    @discardableResult
    func buyFreeze() -> Bool {
        guard profile.streakFreezes < ProfileStore.maxFreezes, spendShards(ProfileStore.freezePrice) else { return false }
        profile.streakFreezes += 1
        if profile.shardGoal == "freeze" { profile.shardGoal = nil }
        return true
    }

    /// Meilenstein erreicht: Belohnung sofort gutschreiben, Truhen ins Lager.
    func grantStreakMilestones() {
        for m in ProfileStore.streakMilestones where profile.streak >= m.days && !profile.streakMilestones.contains(m.days) {
            profile.streakMilestones.append(m.days)
            if let chest = m.chest { grantChest(.streak, chest, label: "\(m.days) Tage") }
            if m.shards > 0 { earnShards(m.shards) }
            if m.freeze {
                if profile.streakFreezes < ProfileStore.maxFreezes { profile.streakFreezes += 1 } else { earnShards(100) }
            }
        }
    }
}

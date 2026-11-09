import Foundation
import UserNotifications

/// Erinnerungen im Stil einer Tages-Serie: Rocky meldet sich, wenn die Flamme noch dunkel ist.
/// 18:00 der gewöhnliche Stupser, 21:00 nur wenn die Serie um Mitternacht wirklich erlischt
/// (ein Flammenschutz hält sie, also gibt es dann keinen Alarm).
enum FlameReminders {
    static let eveningID = "rookraid.flame.evening"
    static let dangerID = "rookraid.flame.danger"

    static func install() {
        UNUserNotificationCenter.current().delegate = FlameReminderDelegate.shared
    }

    /// Erlaubnis erst, wenn schon einmal eine Flamme brannte. Beim ersten Start bleibt es still.
    @MainActor
    static func askIfReady() async {
        guard ProfileStore.shared.profile.lastStreakDay != nil else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let ok = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if ok { await sync() }
        case .authorized, .provisional, .ephemeral:
            await sync()
        default:
            break
        }
    }

    /// Legt die nächsten Hinweise neu, oder räumt sie weg, wenn keine Erlaubnis da ist.
    @MainActor
    static func sync() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral else {
            center.removePendingNotificationRequests(withIdentifiers: [eveningID, dangerID])
            return
        }
        try? await center.setBadgeCount(0)

        let store = ProfileStore.shared
        let now = Date()
        let lit = store.flameLitToday
        let streak = store.currentStreak
        let freezes = store.profile.streakFreezes
        let diesTonight = !lit && streak > 0 && freezes == 0
        let diesTomorrow = lit && streak > 0 && freezes == 0

        center.removePendingNotificationRequests(withIdentifiers: [eveningID, dangerID])

        var planned: [(String, Date, Kind)] = []
        if let evening = next(hour: 18, minute: 0, now: now, allowToday: !lit) {
            planned.append((eveningID, evening, .evening))
        }
        if diesTonight, let danger = next(hour: 21, minute: 0, now: now, allowToday: true),
           Calendar.current.isDate(danger, inSameDayAs: now) {
            planned.append((dangerID, danger, .danger))
        } else if diesTomorrow, let danger = next(hour: 21, minute: 0, now: now, allowToday: false) {
            planned.append((dangerID, danger, .danger))
        }

        for (id, date, kind) in planned {
            let content = UNMutableNotificationContent()
            content.title = streak > 0
                ? (streak == 1 ? L("1 Tag in Folge") : L("{0} Tage in Folge", streak))
                : "Rocky"
            content.body = kind.line(on: date)
            content.sound = .default
            content.badge = 1
            var parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
            parts.hour = Calendar.current.component(.hour, from: date)
            parts.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    private enum Kind {
        case evening, danger

        func line(on date: Date) -> String {
            let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
            switch self {
            case .evening:
                let lines = [
                    L("Deine Flamme wird kalt. Ein Puzzle oder eine Partie, und sie brennt wieder."),
                    L("Heute noch keine Flamme. Die Glut wartet nur auf dich."),
                    L("Ein kurzes Puzzle genügt. Die Flamme will heute noch hoch."),
                    L("Die Flamme von heute fehlt noch. Rocky hält schon das Streichholz bereit.")
                ]
                return lines[day % lines.count]
            case .danger:
                let lines = [
                    L("Um Mitternacht erlischt deine Serie. Rette sie jetzt!"),
                    L("Noch bis Mitternacht. Sonst beginnt die Flamme wieder bei 1."),
                    L("Deine Serie hält den Atem an. Ein Zug, und sie bleibt am Leben.")
                ]
                return lines[day % lines.count]
            }
        }
    }

    /// Nächster Zeitpunkt an diesem Tag, oder morgen, wenn er schon vorbei ist.
    private static func next(hour: Int, minute: Int, now: Date, allowToday: Bool) -> Date? {
        let cal = Calendar.current
        var parts = cal.dateComponents([.year, .month, .day], from: now)
        parts.hour = hour
        parts.minute = minute
        guard let today = cal.date(from: parts) else { return nil }
        if allowToday, today > now { return today }
        return cal.date(byAdding: .day, value: 1, to: today)
    }
}

private final class FlameReminderDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = FlameReminderDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Freundschafts-Push bei offener App: kein Systembanner, der eigene Hinweis oben zeigt es (FriendBanner).
        if notification.request.content.userInfo["type"] as? String == "friends" {
            Task { @MainActor in await FriendsStore.shared.refresh() }
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == FlameReminders.eveningID
            || response.notification.request.identifier == FlameReminders.dangerID {
            NotificationCenter.default.post(name: .showPuzzles, object: nil)
        } else if response.notification.request.content.userInfo["type"] as? String == "friends" {
            NotificationCenter.default.post(name: .showFriends, object: nil)
        }
        completionHandler()
    }
}

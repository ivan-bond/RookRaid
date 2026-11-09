import Foundation
import UIKit
import UserNotifications

/// Push-Nachrichten für Freundschaftsanfragen (wie web/src/push.ts). Das Gerät meldet sein APNs-Token bei
/// `register_push_token`; verschickt wird von der Edge Function push-dispatch.
@MainActor
final class PushRegistration {
    static let shared = PushRegistration()

    private var token: String?
    private var registeredFor: String?

    /// Debug-Builds bekommen Tokens vom Test-Server von Apple, App-Store-Builds vom echten.
    private var environment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// Fragt einmal nach der Erlaubnis (aus dem Freunde-Bereich, nach einem Tipp) und meldet das Gerät an.
    @discardableResult
    func enable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        var allowed = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        if settings.authorizationStatus == .notDetermined {
            allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        if allowed { UIApplication.shared.registerForRemoteNotifications() }
        return allowed
    }

    /// Beim Start und nach dem Anmelden: ist die Erlaubnis schon da, still beim Server anmelden.
    func syncIfAllowed() async {
        guard OnlineAccount.shared.hasAccount else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }
        UIApplication.shared.registerForRemoteNotifications()
        await upload()
    }

    func didRegister(deviceToken: Data) {
        token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await upload() }
    }

    private func upload() async {
        guard let token, let client = Backend.client, OnlineAccount.shared.hasAccount else { return }
        // Neu melden, wenn Konto oder Sprache wechselt (die Nachricht kommt in der Sprache des Geräts).
        let lang = ProfileStore.shared.profile.settings.language.rawValue
        let account = (client.auth.currentUser?.id.uuidString ?? "") + ":" + lang + ":" + token
        guard registeredFor != account else { return }
        struct Params: Encodable {
            let p_platform = "ios"
            let p_token: String
            let p_environment: String
            let p_subscription: String? = nil
            let p_locale: String
        }
        do {
            try await client.rpc("register_push_token", params: Params(p_token: token, p_environment: environment, p_locale: lang)).execute()
            registeredFor = account
        } catch {
            // offline: beim nächsten Start
        }
    }

    /// Vor dem Abmelden: Dieses Gerät soll keine Nachrichten des alten Kontos mehr bekommen.
    func unregister() async {
        guard let token, let client = Backend.client else { return }
        _ = try? await client.rpc("unregister_push_token", params: ["p_token": token]).execute()
        registeredFor = nil
    }
}

/// Nur für das APNs-Token (SwiftUI hat dafür keinen eigenen Weg).
final class RookRaidAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushRegistration.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Simulator ohne Push oder kein Netz: dann eben ohne Push.
    }
}

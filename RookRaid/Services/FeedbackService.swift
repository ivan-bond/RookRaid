import Foundation
import UIKit
import Supabase

/// Feedback aus Profil → Feedback. Die Edge Function `send-feedback` speichert die Nachricht und mailt sie an
/// rookraidchess@gmail.com (Backend/supabase/functions/send-feedback). Wie web/src/feedback.ts.
enum FeedbackService {
    static let email = "rookraidchess@gmail.com"

    enum Category: String, CaseIterable, Identifiable {
        case bug, balance, idea, other
        var id: String { rawValue }
        var label: String {
            switch self {
            case .bug: return L("Bug")
            case .balance: return L("Balance")
            case .idea: return L("Idee")
            case .other: return L("Sonstiges")
            }
        }
        var icon: String {
            switch self {
            case .bug: return "ladybug.fill"
            case .balance: return "scalemass.fill"
            case .idea: return "lightbulb.fill"
            case .other: return "ellipsis.bubble.fill"
            }
        }
    }

    enum SendError: Error { case rateLimited, invalid, failed }

    @MainActor
    static func send(category: Category, message: String, contact: String) async throws {
        guard let client = Backend.client else { throw SendError.failed }
        struct Meta: Encodable {
            let platform: String, app_version: String, language: String, player_name: String, trophies: Int, device: String
        }
        struct Body: Encodable { let category: String; let message: String; let contact: String; let meta: Meta }
        struct OK: Decodable { let ok: Bool? }
        let p = ProfileStore.shared.profile
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        let device = "\(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)"
        let body = Body(
            category: category.rawValue,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines),
            meta: Meta(platform: "ios", app_version: "\(version) (\(build))", language: Localizer.shared.language.rawValue,
                       player_name: p.name, trophies: p.trophies, device: device)
        )
        do {
            let _: OK = try await client.functions.invoke("send-feedback", options: .init(body: body))
        } catch let error as FunctionsError {
            if case .httpError(let code, _) = error {
                if code == 429 { throw SendError.rateLimited }
                if code == 400 { throw SendError.invalid }
            }
            throw SendError.failed
        } catch {
            throw SendError.failed
        }
    }
}

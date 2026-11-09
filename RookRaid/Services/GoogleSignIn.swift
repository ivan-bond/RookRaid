import AuthenticationServices
import SwiftUI

/// Womit ein Konto gesichert ist (wie `SignInProvider` in web/src/online.ts).
enum SignInProvider: String {
    case apple, google

    /// „Mit Apple gesichert“ / „Mit Google gesichert“
    var securedText: String { self == .google ? L("Mit Google gesichert") : L("Mit Apple gesichert") }
}

/// Anmeldefenster von iOS (ASWebAuthenticationSession) für eine Adresse, die mit `scheme://…` zurückspringt.
/// Für „Mit Google sichern“: supabase-swift öffnet das Verknüpfen sonst in Safari statt im Anmeldefenster.
enum WebAuthFlow {
    @MainActor
    static func run(_ url: URL, scheme: String) async throws -> URL {
        let anchor = Anchor()
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                _ = anchor
                if let error { continuation.resume(throwing: error) }
                else if let callback { continuation.resume(returning: callback) }
                else { continuation.resume(throwing: AccountError.notAuthenticated) }
            }
            session.presentationContextProvider = anchor
            session.start()
        }
    }

    private final class Anchor: NSObject, ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first ?? ASPresentationAnchor()
        }
    }
}

/// „Mit Google anmelden“ nach Googles Gestaltungsregeln: weiß, farbiges „G“, dunkle Schrift, gleiche Höhe wie der Apple-Knopf.
/// `linking` hängt Google an das anonyme Konto; sonst Anmeldung (neues Gerät).
struct GoogleSignInButton: View {
    var linking: Bool
    var onError: (String) -> Void
    @ObservedObject private var account = OnlineAccount.shared

    var body: some View {
        Button {
            Task {
                do {
                    if linking { try await account.linkGoogle() } else { try await account.signInWithGoogle() }
                } catch {
                    switch AccountError(error) {
                    case .cancelled: break
                    case .server: onError(L("Anmeldung mit Google fehlgeschlagen. Bitte versuche es noch einmal."))
                    case let e: onError(e.message)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleG").resizable().frame(width: 18, height: 18)
                Text(linking ? L("Mit Google sichern") : L("Mit Google anmelden"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: 0x1F1F1F))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(hex: 0x747775), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(account.busy)
    }
}

/// Apple und Google untereinander – überall, wo man ein Konto sichert oder sich anmeldet.
struct SignInButtons: View {
    var linking: Bool
    var onError: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            AppleSecureButton(linking: linking, onError: onError)
            GoogleSignInButton(linking: linking, onError: onError)
        }
    }
}

import AuthenticationServices
import CryptoKit
import SwiftUI

/// Zufälliger Nonce für Sign in with Apple. Apple bekommt den SHA-256, Supabase den Klartext.
enum AppleNonce {
    static func make(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Offizieller Apple-Knopf. `linking` hängt Apple an das anonyme Konto; sonst Anmeldung (neues Gerät).
struct AppleSecureButton: View {
    var linking: Bool
    var onError: (String) -> Void
    @State private var nonce = NonceBox()

    var body: some View {
        SignInWithAppleButton(linking ? .continue : .signIn, onRequest: { request in
            let raw = AppleNonce.make()
            nonce.raw = raw
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleNonce.sha256(raw)
        }, onCompletion: { result in
            Task { await finish(result) }
        })
        .signInWithAppleButtonStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }

    private func finish(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            onError(L("Anmeldung mit Apple fehlgeschlagen. Bitte versuche es noch einmal."))
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8),
                  !nonce.raw.isEmpty else {
                onError(L("Anmeldung mit Apple fehlgeschlagen. Bitte versuche es noch einmal."))
                return
            }
            do {
                if linking {
                    try await OnlineAccount.shared.linkApple(idToken: token, nonce: nonce.raw)
                } else {
                    try await OnlineAccount.shared.signInWithApple(idToken: token, nonce: nonce.raw)
                }
            } catch {
                onError(AccountError(error).message)
            }
        }
    }
}

/// Vor dem Löschen eines mit Apple gesicherten Kontos: ein frischer Autorisierungscode von Apple (Face ID / Code).
/// Mit ihm widerruft der Server „Sign in with Apple“ für die App (App-Store-Richtlinie 5.1.1(v)).
final class AppleReauth: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    enum Failure: Error { case cancelled, noCode }

    private var continuation: CheckedContinuation<String, Error>?
    /// Hält sich selbst, bis Apple antwortet (der Controller hält seinen Delegate nur schwach).
    private var keepAlive: AppleReauth?

    @MainActor
    static func authorizationCode() async throws -> String {
        try await AppleReauth().run()
    }

    @MainActor
    private func run() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            keepAlive = self
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = []
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        keepAlive = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let code = (authorization.credential as? ASAuthorizationAppleIDCredential)?.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) }
        finish(code.map { .success($0) } ?? .failure(Failure.noCode))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        finish(.failure(cancelled ? Failure.cancelled : error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first ?? ASPresentationAnchor()
    }
}

/// Hält den Klartext-Nonce, ohne bei jedem Tippen die Ansicht neu zu bauen.
private final class NonceBox {
    var raw = ""
}

/// Nach der dritten Online-Partie: Rocky bittet einmal, das anonyme Konto mit Apple zu sichern.
struct RockyAppleSecureOverlay: View {
    let onClose: () -> Void
    @ObservedObject private var account = OnlineAccount.shared
    @State private var appear = false
    @State private var bounce = 0
    @State private var errorText: String?

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
                    Text(L("Sichere dein Konto"))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(L("Drei Online-Partien geschafft! Sichere dein Konto mit Apple, dann bleibt dein Fortschritt auch, wenn du die App löschst oder das iPhone wechselst."))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    AppleSecureButton(linking: true) { errorText = $0 }
                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.red)
                            .multilineTextAlignment(.center)
                    }
                    Button(L("Später"), action: onClose)
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
        .onChange(of: account.status) { status in
            if status == .apple { onClose() }
        }
    }
}

import SwiftUI

// Freundschaftsspiele: Hinweis „X fordert dich heraus“ und das Warten auf die Antwort (wie web/src/screens/FriendMatch.tsx).

/// Hängt die Freundschaftsspiel-Anzeigen an die Startseite und schließt die Freundesliste, sobald es losgeht.
struct FriendMatchLinks: ViewModifier {
    @ObservedObject var center: FriendMatchCenter
    @Binding var friendsSheet: FriendsInvite?
    @Binding var tab: RootTab
    /// Während einer Partie oder vor dem Start nichts zeigen
    let quiet: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if let out = center.outgoing {
                    FriendMatchWaiting(outgoing: out)
                        .transition(.opacity)
                } else if !quiet, let invite = center.incoming.first {
                    FriendMatchInviteBanner(invite: invite)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: center.outgoing)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: center.incoming)
            .onChange(of: center.outgoing?.inviteId) { id in
                if id != nil { friendsSheet = nil }
            }
            .onChange(of: center.readyMatch) { id in
                guard let id else { return }
                center.readyMatch = nil
                friendsSheet = nil
                tab = .play
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    NotificationCenter.default.post(name: .startFriendMatch, object: id)
                }
            }
    }
}

/// Oben auf der Startseite: Einladung annehmen oder ablehnen. Läuft nach 2 Minuten ab.
struct FriendMatchInviteBanner: View {
    let invite: MatchInvite
    @ObservedObject private var center = FriendMatchCenter.shared
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, Int(FriendMatchCenter.lifetime - context.date.timeIntervalSince(invite.createdAt)))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    PlayerAvatar(size: 40, frame: invite.frame.flatMap(AvatarFrame.init(rawValue:)) ?? AvatarFrame.none,
                                 avatar: Avatar(rawValue: invite.avatar) ?? .knight)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L("Freundschaftsspiel"))
                            .font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(Theme.textPrimary)
                        Text(L("{0} fordert dich zu einem Freundschaftsspiel heraus.", invite.name))
                            .font(.system(size: 12)).foregroundColor(Theme.textSecondary).lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundColor(Theme.gold)
                }
                if let errorText {
                    Text(errorText).font(.system(size: 12)).foregroundColor(Theme.redLight)
                }
                HStack(spacing: 8) {
                    Button(L("Annehmen")) {
                        busy = true
                        Task {
                            do { try await center.accept(invite) } catch { errorText = FriendError.message(error) }
                            busy = false
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 38, textColor: Theme.navy))
                    .disabled(busy)
                    Button(L("Ablehnen")) { center.decline(invite) }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 38, textColor: Theme.textPrimary))
                        .frame(width: 120)
                }
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                Text(L("5 | 0 · ohne Trophäen"))
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textMuted)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1B2A4C)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color(hex: 0xF07AA8).opacity(0.6), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
            .onChange(of: left) { s in if s == 0 { center.decline(invite) } }
        }
        .onAppear { Haptics.shared.play(.select) }
    }
}

/// Eigene Herausforderung: warten, bis der Freund antwortet (höchstens 2 Minuten).
struct FriendMatchWaiting: View {
    let outgoing: FriendMatchCenter.Outgoing
    @ObservedObject private var center = FriendMatchCenter.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 14) {
                PlayerAvatar(size: 88, frame: outgoing.frame.flatMap(AvatarFrame.init(rawValue:)) ?? AvatarFrame.none,
                             avatar: Avatar(rawValue: outgoing.avatar) ?? .knight)
                Text(outgoing.name)
                    .font(.system(size: 22, weight: .black, design: .rounded)).foregroundColor(.white)
                FriendlyTag()
                switch outgoing.state {
                case .waiting:
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(FriendMatchCenter.lifetime - context.date.timeIntervalSince(outgoing.startedAt)))
                        VStack(spacing: 6) {
                            ProgressView().tint(Theme.gold)
                            Text(L("Warte auf {0} …", outgoing.name))
                                .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textSecondary)
                            Text(String(format: "%d:%02d", left / 60, left % 60))
                                .font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit().foregroundColor(Theme.gold)
                        }
                    }
                    Button(L("Abbrechen")) { center.cancelOutgoing() }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 46, textColor: Theme.textPrimary))
                case .declined, .expired, .failed:
                    Text(message)
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button(L("OK")) { center.cancelOutgoing() }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 46, textColor: Theme.navy))
                }
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .padding(24)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1.5))
            .padding(24)
        }
    }

    private var message: String {
        switch outgoing.state {
        case .declined: return L("{0} kann gerade nicht spielen.", outgoing.name)
        case .expired: return L("{0} hat nicht geantwortet.", outgoing.name)
        case .failed(let text): return text
        case .waiting: return ""
        }
    }
}

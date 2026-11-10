import SwiftUI
import UIKit
import UserNotifications

/// Freunde (wie web/src/screens/Friends.tsx): Karte im Profil, Freundesliste mit Einladung, Suche, Anfragen und
/// Freundes-Rangliste, Profil-Übersicht eines Freundes und der Hinweis oben bei neuen Anfragen.

/// Inhalt für `.sheet(item:)`: die Freundesliste, optional mit einem Code aus einem Einladungslink.
struct FriendsInvite: Identifiable {
    let id = UUID()
    let code: String?
}

private func inviteText(_ code: String) -> String { L("Spiel mit mir Rook Raid! Mein Freundescode: {0}", code) }

@MainActor
private func shortDate(_ date: Date?) -> String {
    guard let date else { return "" }
    let f = DateFormatter()
    f.locale = ProfileStore.shared.profile.settings.language.locale
    f.dateStyle = .medium
    f.timeStyle = .none
    return f.string(from: date)
}

private func avatarOf(_ raw: String) -> Avatar { Avatar(rawValue: raw) ?? .knight }
private func frameOf(_ raw: String?) -> AvatarFrame { raw.flatMap(AvatarFrame.init(rawValue:)) ?? AvatarFrame.none }

// MARK: - Karte im Profil

struct FriendsCard: View {
    @ObservedObject private var friends = FriendsStore.shared
    @ObservedObject private var account = OnlineAccount.shared
    var onOpen: () -> Void
    @State private var bob = false

    var body: some View {
        let list = friends.friends
        let requests = friends.incoming.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10).fill(LinearGradient(colors: [Theme.blueLight, Theme.blue], startPoint: .top, endPoint: .bottom)))
                    .rotationEffect(.degrees(-8))
                Text(L("Freunde"))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                if !list.isEmpty {
                    Text("\(list.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 7).frame(height: 22)
                        .background(Capsule().fill(Color.black.opacity(0.25)))
                }
                Spacer()
                if requests > 0 {
                    Button(action: onOpen) {
                        Text(requests == 1 ? L("1 Anfrage") : L("{0} Anfragen", requests))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9).frame(height: 22)
                            .background(Capsule().fill(Theme.red))
                            .scaleEffect(bob ? 1.07 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(action: onOpen) {
                HStack(spacing: 0) {
                    if list.isEmpty {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(Theme.blueLight)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Theme.navy.opacity(0.4)))
                                .overlay(Circle().strokeBorder(Theme.blueLight.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5, 4])))
                                .offset(y: bob && i % 2 == 0 ? -4 : 0)
                                .padding(.trailing, -10)
                        }
                    } else {
                        ForEach(Array(list.prefix(6).enumerated()), id: \.element.id) { i, f in
                            PlayerAvatar(size: 46, frame: frameOf(f.frame), avatar: avatarOf(f.avatar))
                                .overlay(Circle().strokeBorder(Color(hex: 0x22306A), lineWidth: 3))
                                .zIndex(Double(10 - i))
                                .padding(.trailing, -12)
                        }
                    }
                    Text(list.isEmpty ? L("Lade deine Freunde ein – zu zweit macht Rook Raid doppelt Spaß!")
                         : list.count == 1 ? L("Du und {0}", list[0].name) : L("Du, {0} und {1} weitere", list[0].name, list.count - 1))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .padding(.leading, 24)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PressScaleStyle())
            HStack(spacing: 8) {
                if let code = friends.code {
                    ShareLink(item: FriendCode.link(code)?.absoluteString ?? code, message: Text(inviteText(code))) {
                        Label(L("Freund einladen"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 44, textColor: Theme.navy))
                } else {
                    Button(action: onOpen) { Label(L("Freund einladen"), systemImage: "square.and.arrow.up") }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 44, textColor: Theme.navy))
                }
                Button(action: onOpen) { Text(L("Alle Freunde")) }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 44, textColor: Theme.textPrimary))
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [Color(hex: 0x1D3D7A), Color(hex: 0x2A2366), Theme.panelRaised], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.blueLight.opacity(0.33), lineWidth: 1.5))
        .task { await friends.refresh() }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { bob = true } }
    }
}

// MARK: - Freundesliste

struct FriendsSheet: View {
    @ObservedObject private var friends = FriendsStore.shared
    @ObservedObject private var matches = FriendMatchCenter.shared
    @ObservedObject private var account = OnlineAccount.shared
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    /// Aus einem Einladungslink: dieser Code wird gleich gesucht.
    var invite: String? = nil

    @State private var query = ""
    @State private var results: [FriendPlayer]?
    @State private var busy = false
    @State private var errorText: String?
    @State private var toast: String?
    @State private var pushStatus: UNAuthorizationStatus?
    @State private var blocked: [BlockedPlayer]?
    @State private var showProfile: UUID?
    @State private var nameSheet: OnlineNameSheet.Purpose?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if account.hasAccount { content } else { gate }
                if let toast {
                    Text(toast)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.navy)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(Theme.cream))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(L("Freunde"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
            // iOS 16: navigationDestination(item:) gibt es erst ab iOS 17.
            .navigationDestination(isPresented: Binding(get: { showProfile != nil }, set: { if !$0 { showProfile = nil } })) {
                if let id = showProfile { FriendProfileView(userId: id) }
            }
        }
        // Freund herausgefordert (aus der Liste oder dem Profil): die Freunde schließen, damit das Warten zu sehen ist (wie im Web).
        .onChange(of: matches.outgoing != nil) { challenged in
            if challenged { dismiss() }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $nameSheet) { purpose in OnlineNameSheet(purpose: purpose) }
        .task {
            await friends.refresh()
            pushStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if let invite, query.isEmpty { query = invite; await search() }
        }
    }

    private var gate: some View {
        VStack(spacing: 14) {
            RockyAvatar(size: 92)
            Text(L("Freunde brauchen ein Online-Konto."))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .multilineTextAlignment(.center)
            Text(L("Mit Konto findest du Freunde über ihren Namen oder Code, siehst ihre Trophäen und bekommst ihre Anfragen."))
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
            if account.status != .unavailable {
                Button(L("Online-Konto erstellen")) { nameSheet = .create }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 48, textColor: Theme.navy))
            }
        }
        .padding(24)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if !matches.incoming.isEmpty {
                    SectionHeader(title: L("Herausforderungen"))
                    panel {
                        ForEach(matches.incoming) { inv in
                            HStack(spacing: 10) {
                                PlayerAvatar(size: 38, frame: frameOf(inv.frame), avatar: avatarOf(inv.avatar))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(inv.name).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                                    Text(L("Freundschaftsspiel")).font(.system(size: 12)).foregroundColor(Theme.textMuted)
                                }
                                Spacer(minLength: 0)
                                Button(L("Annehmen")) { act { try await matches.accept(inv); return nil } }
                                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 34, textColor: Theme.navy))
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .frame(width: 104)
                                Button { matches.decline(inv) } label: {
                                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textSecondary).frame(width: 34, height: 34)
                                }
                                .accessibilityLabel(L("Ablehnen"))
                            }
                            .padding(.horizontal, 12).padding(.vertical, 9)
                        }
                    }
                    .padding(.bottom, 8)
                }
                inviteCard
                SectionHeader(title: L("Spieler suchen")).padding(.top, 10)
                HStack(spacing: 8) {
                    TextField(L("Name oder Freundescode"), text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                        .padding(.horizontal, 14).frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                        .onChange(of: query) { _ in results = nil; errorText = nil }
                    Button(L("Suchen")) { Task { await search() } }
                        .buttonStyle(ChunkyButtonStyle(height: 46))
                        .frame(width: 96)
                        .disabled(busy || query.trimmingCharacters(in: .whitespaces).count < 2)
                }
                .font(.system(size: 15, weight: .bold))
                if let errorText { Text(errorText).font(.system(size: 13)).foregroundColor(Theme.textSecondary) }
                if let results, !results.isEmpty {
                    panel { ForEach(results) { r in row(r) { relationButton(r) } } }
                }

                if pushStatus == .notDetermined {
                    Button {
                        Task {
                            await PushRegistration.shared.enable()
                            pushStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
                        }
                    } label: {
                        HStack(spacing: 12) {
                            iconBox("bell.badge.fill", Theme.red)
                            Text(L("Benachrichtigen, wenn dich jemand hinzufügt"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text(L("Aktivieren")).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundColor(Theme.navy)
                                .padding(.horizontal, 9).frame(height: 24).background(Capsule().fill(Theme.gold))
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                } else if pushStatus == .denied {
                    Text(L("Benachrichtigungen sind aus. Du kannst sie in den Einstellungen erlauben."))
                        .font(.system(size: 13)).foregroundColor(Theme.textSecondary).padding(.top, 8)
                }

                if !friends.incoming.isEmpty {
                    SectionHeader(title: L("Anfragen") + " · \(friends.incoming.count)").padding(.top, 12)
                    panel {
                        ForEach(friends.incoming) { r in
                            row(r, open: true) {
                                Button(L("Annehmen")) { act { try await friends.respond(to: r.userId, accept: true); return L("Ihr seid jetzt Freunde!") } }
                                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 34, textColor: Theme.navy))
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .frame(width: 104)
                                Button { act { try await friends.respond(to: r.userId, accept: false); return nil } } label: {
                                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textSecondary).frame(width: 34, height: 34)
                                }
                                .accessibilityLabel(L("Ablehnen"))
                            }
                        }
                    }
                }

                SectionHeader(title: L("Freundes-Rangliste")).padding(.top, 12)
                if friends.friends.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill").font(.system(size: 28)).foregroundColor(Theme.blueLight)
                        Text(L("Noch keine Freunde. Teile deinen Link oder suche nach einem Namen."))
                            .font(.system(size: 14)).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
                        if !store.profile.firstFriendChestGiven {
                            HStack(spacing: 8) {
                                ChestView(rarity: .gold, size: 30)
                                Text(L("Für deinen ersten Freund gibt es eine Goldtruhe!"))
                                    .font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundColor(Theme.gold)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold.opacity(0.08)))
                        }
                    }
                    .frame(maxWidth: .infinity).padding(22)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                } else {
                    panel { ranking }
                }

                if !friends.outgoing.isEmpty {
                    SectionHeader(title: L("Gesendete Anfragen")).padding(.top, 12)
                    panel {
                        ForEach(friends.outgoing) { r in
                            row(r, open: true) {
                                Button(L("Zurückziehen")) { act { try await friends.cancel(r.userId); return nil } }
                                    .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.textSecondary)
                            }
                        }
                    }
                }

                if let show = friends.showOnline {
                    Toggle(isOn: Binding(get: { show }, set: { v in act { try await friends.setShowOnline(v); return nil } })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Online-Status zeigen")).font(.system(size: 15, weight: .semibold)).foregroundColor(Theme.textPrimary)
                            Text(L("Freunde sehen, wenn du gerade in Rook Raid bist, und können dich herausfordern."))
                                .font(.system(size: 12)).foregroundColor(Theme.textMuted)
                        }
                    }
                    .tint(Theme.gold)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                    .padding(.top, 18)
                }

                Button(L("Blockierte Spieler")) {
                    Task {
                        do { blocked = try await friends.blocked() } catch { flash(FriendError.message(error)) }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .refreshable { await friends.refresh() }
        .confirmationDialog(L("Blockierte Spieler"), isPresented: Binding(get: { blocked != nil }, set: { if !$0 { blocked = nil } }), titleVisibility: .visible) {
            ForEach(blocked ?? []) { b in
                Button(L("{0} freigeben", b.name)) { Task { try? await friends.unblock(b.userId) } }
            }
            Button(L("Fertig"), role: .cancel) {}
        } message: {
            if blocked?.isEmpty ?? true { Text(L("Niemand blockiert.")) }
        }
    }

    private var inviteCard: some View {
        VStack(spacing: 8) {
            Text(L("Dein Freundescode").uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded)).kerning(1.3)
                .foregroundColor(Color(hex: 0xFFE08A))
            Text(friends.code ?? "······")
                .font(.system(size: 36, weight: .black, design: .monospaced)).kerning(6)
                .foregroundColor(Color(hex: 0xFFE08A))
                .shadow(color: Theme.gold.opacity(0.4), radius: 12)
                .textSelection(.enabled)
            Text(L("Schick den Link per Messenger. Wer ihn öffnet, landet direkt bei dir."))
                .font(.system(size: 13)).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                if let code = friends.code {
                    ShareLink(item: FriendCode.link(code)?.absoluteString ?? code, message: Text(inviteText(code))) {
                        Label(L("Link teilen"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 44, textColor: Theme.navy))
                    Button(L("Code kopieren")) {
                        UIPasteboard.general.string = code
                        Haptics.shared.play(.select)
                        flash(L("Kopiert!"))
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 44, textColor: Theme.textPrimary))
                }
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(RadialGradient(colors: [Color(hex: 0x3B2C86), Color(hex: 0x1A2550)], center: .top, startRadius: 10, endRadius: 260)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.gold.opacity(0.33), lineWidth: 1.5))
    }

    /// Eine Zeile der Freundes-Rangliste (id nil = man selbst)
    private struct RankEntry {
        let id: UUID?
        let name: String
        let avatar: Avatar
        let frame: AvatarFrame
        let trophies: Int
        let title: String?
        var isBot = false
        var online = false
    }

    private var rankEntries: [RankEntry] {
        var entries = friends.friends.map {
            RankEntry(id: $0.userId, name: $0.name, avatar: avatarOf($0.avatar), frame: frameOf($0.frame), trophies: $0.trophies, title: $0.title,
                      isBot: $0.isBot, online: $0.online)
        }
        let myTitle: String? = store.activeTitle
        entries.append(RankEntry(id: nil, name: store.profile.name, avatar: store.activeAvatar, frame: store.activeFrame,
                                 trophies: account.progress?.trophies ?? store.profile.trophies, title: myTitle))
        return entries.sorted { $0.trophies > $1.trophies }
    }

    @ViewBuilder
    private var ranking: some View {
        ForEach(Array(rankEntries.enumerated()), id: \.offset) { i, e in
          HStack(spacing: 0) {
            Button { if let id = e.id { showProfile = id } } label: {
                HStack(spacing: 10) {
                    Text("\(i + 1)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(i == 0 ? Theme.gold : i == 1 ? Color(hex: 0xD6DCE8) : i == 2 ? Color(hex: 0xE39B6A) : Theme.textMuted)
                        .frame(width: 22)
                    PlayerAvatar(size: 38, frame: e.frame, avatar: e.avatar)
                        .overlay(alignment: .bottomTrailing) { if e.online { OnlineDot() } }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(e.id == nil ? "\(e.name) · \(L("Du"))" : e.name)
                                .font(.system(size: 15, weight: .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                            if e.isBot { TrainingTag(botPlayer: true) }
                        }
                        trophyLine(e.trophies, e.title)
                    }
                    Spacer()
                }
                .padding(.leading, 12).padding(.trailing, e.id == nil ? 12 : 4).padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(e.id == nil)
            if let id = e.id {
                // Direkt aus der Liste herausfordern (wie der Knopf im Profil); online = hervorgehoben
                Button {
                    Task {
                        do { try await FriendMatchCenter.shared.invite(id, name: e.name, avatar: e.avatar.rawValue, frame: e.frame == AvatarFrame.none ? nil : e.frame.rawValue) }
                        catch { flash(FriendError.message(error)) }
                    }
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(e.online ? Theme.navy : Theme.gold)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(e.online ? Theme.gold : Theme.gold.opacity(0.12)))
                        .shadow(color: e.online ? Theme.gold.opacity(0.5) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 10)
                .accessibilityLabel(L("{0} herausfordern", e.name))
            }
          }
          .background(e.id == nil ? Theme.blue.opacity(0.12) : Color.clear)
        }
    }

    // MARK: Bausteine

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func iconBox(_ name: String, _ color: Color) -> some View {
        Image(systemName: name).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8).fill(color))
    }

    private func trophyLine(_ trophies: Int, _ title: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill").font(.system(size: 9)).foregroundColor(Theme.gold)
            Text("\(trophies)" + (title.map { " · " + L($0) } ?? ""))
                .font(.system(size: 12)).foregroundColor(Theme.textMuted).lineLimit(1)
        }
    }

    private func row<Trailing: View>(_ p: FriendPlayer, open: Bool = false, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            Button { if open || p.relation == .friend { showProfile = p.userId } } label: {
                HStack(spacing: 10) {
                    PlayerAvatar(size: 38, frame: frameOf(p.frame), avatar: avatarOf(p.avatar))
                        .overlay(alignment: .bottomTrailing) { if p.online { OnlineDot() } }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(p.name).font(.system(size: 15, weight: .bold)).foregroundColor(Theme.textPrimary).lineLimit(1)
                            if p.isBot { TrainingTag(botPlayer: true) }
                        }
                        trophyLine(p.trophies, p.title)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            trailing()
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }

    @ViewBuilder
    private func relationButton(_ p: FriendPlayer) -> some View {
        switch p.relation {
        case .none:
            Button { act {
                let r = try await friends.send(to: p.userId)
                return r == "accepted" ? L("Ihr seid jetzt Freunde!") : r == "already_friends" ? L("Ihr seid schon Freunde.") : L("Anfrage gesendet!")
            } } label: { Label(L("Hinzufügen"), systemImage: "plus") }
                .buttonStyle(ChunkyButtonStyle(height: 34))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .frame(width: 130)
        case .incoming:
            Button(L("Annehmen")) { act { try await friends.respond(to: p.userId, accept: true); return L("Ihr seid jetzt Freunde!") } }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 34, textColor: Theme.navy))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .frame(width: 110)
        case .outgoing:
            chip(L("Gesendet"), color: Theme.textSecondary)
        case .friend:
            chip(L("Befreundet"), color: Theme.gold)
        case .me:
            chip(L("Das bist du"), color: Theme.textSecondary)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(color)
            .padding(.horizontal, 8).frame(height: 22)
            .background(Capsule().fill(Color.black.opacity(0.25)))
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return }
        busy = true
        defer { busy = false }
        do {
            let found = try await friends.find(q)
            results = found
            errorText = found.isEmpty ? L("Niemand gefunden. Prüfe den Namen oder den Code.") : nil
        } catch {
            results = nil
            errorText = FriendError.message(error)
        }
    }

    /// Aktion ausführen, kurze Rückmeldung zeigen, Suchergebnis auffrischen.
    private func act(_ work: @escaping () async throws -> String?) {
        Task {
            do {
                if let text = try await work() {
                    if text == L("Ihr seid jetzt Freunde!") { Haptics.shared.play(.victory) }
                    flash(text)
                }
                if results != nil { await search() }
            } catch {
                flash(FriendError.message(error))
            }
        }
    }

    private func flash(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.easeOut(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }
}

// MARK: - Profil-Übersicht

struct FriendProfileView: View {
    let userId: UUID
    @ObservedObject private var friends = FriendsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var profile: FriendProfile?
    @State private var errorText: String?
    @State private var confirmRemove = false
    @State private var confirmBlock = false
    @State private var showReport = false
    @State private var toast: String?
    @State private var challenging = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    if let errorText { Text(errorText).foregroundColor(Theme.textSecondary).padding(.top, 40) }
                    if let p = profile { content(p) } else if errorText == nil { ProgressView().padding(.top, 60) }
                }
                .padding(16)
            }
            if let toast {
                Text(toast).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.navy)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.cream))
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 24)
            }
        }
        .navigationTitle(profile?.name ?? L("Freunde"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do { profile = try await friends.profile(userId) } catch { errorText = FriendError.message(error) }
    }

    @ViewBuilder
    private func content(_ p: FriendProfile) -> some View {
        let arena = Arena.forTrophies(p.trophies)
        let games = p.wins + p.losses + p.draws
        VStack(spacing: 6) {
            PlayerAvatar(size: 96, frame: frameOf(p.frame), avatar: avatarOf(p.avatar))
                .overlay(alignment: .bottomTrailing) { if p.online == true { OnlineDot(size: 18) } }
            HStack(spacing: 8) {
                Text(p.name).font(.system(size: 24, weight: .black, design: .rounded)).foregroundColor(Theme.textPrimary)
                if p.isBot == true { TrainingTag(large: true, botPlayer: true) }
            }
            if let title = p.title {
                Text(L(title).uppercased()).font(.system(size: 11, weight: .black, design: .rounded)).kerning(1.3).foregroundColor(Theme.blueLight)
            }
            HStack(spacing: 6) {
                chip(L("Level {0}", p.level))
                chip(L("Arena {0}", arena.number))
                if p.relation == .friend, p.since != nil { chip(L("Freunde seit {0}", shortDate(p.since)), gold: true) }
            }
            if p.relation == .friend {
                Text(p.online == true ? L("Online") : L("Offline"))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(p.online == true ? Color(hex: 0x6FDC8C) : Theme.textMuted)
            }
            if p.isBot == true {
                Text(L("Das ist ein Bot-Spieler, kein Mensch."))
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 6)

        if p.relation == .friend {
            Button {
                challenging = true
                Task {
                    do { try await FriendMatchCenter.shared.invite(p.userId, name: p.name, avatar: p.avatar, frame: p.frame) }
                    catch { flash(FriendError.message(error)) }
                    challenging = false
                }
            } label: {
                Label(L("Freundschaftsspiel"), systemImage: "bolt.heart.fill")
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 48, textColor: Theme.navy))
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .disabled(challenging)
            Text(L("5 | 0 · ohne Trophäen · zählt für eure Bilanz"))
                .font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.textMuted)
        }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            stat("trophy.fill", Theme.gold, "\(p.trophies)", L("Rekord {0}", p.bestTrophies))
            stat("crown.fill", Color(hex: 0xFFE08A), "#\(p.rank)", L("Weltweit"))
            stat("bolt.fill", Theme.blueLight, "\(games == 0 ? 0 : Int((Double(p.wins) / Double(games) * 100).rounded())) %", L("{0} S · {1} N · {2} R", p.wins, p.losses, p.draws))
            stat("person.2.fill", Color(hex: 0x6FBF73), "\(p.friends)", p.friends == 1 ? L("1 Freund") : L("{0} Freunde", p.friends))
        }

        if p.relation == .friend {
            VStack(spacing: 2) {
                SectionHeader(title: L("Ihr gegeneinander")).multilineTextAlignment(.center)
                Text("\(p.vsWins) : \(p.vsLosses)").font(.system(size: 30, weight: .black, design: .rounded)).foregroundColor(Color(hex: 0xFFE08A))
                if p.vsDraws > 0 { Text(L("{0} Remis", p.vsDraws)).font(.system(size: 13)).foregroundColor(Theme.textSecondary) }
                else if p.vsWins + p.vsLosses == 0 { Text(L("Noch keine Partie gegeneinander.")).font(.system(size: 13)).foregroundColor(Theme.textSecondary) }
            }
            .frame(maxWidth: .infinity).padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
        }

        if p.relation == .friend { FriendHistory(userId: p.userId) }

        if p.relation == .incoming {
            HStack(spacing: 8) {
                Button(L("Annehmen")) { Task { await run { try await friends.respond(to: p.userId, accept: true) }; Haptics.shared.play(.victory); await load() } }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: Color(hex: 0xB8892B), height: 44, textColor: Theme.navy))
                Button(L("Ablehnen")) { Task { if await run({ try await friends.respond(to: p.userId, accept: false) }) { dismiss() } } }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 44, textColor: Theme.textPrimary))
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
        }
        if p.relation == .outgoing {
            Button(L("Anfrage zurückziehen")) { Task { if await run({ try await friends.cancel(p.userId) }) { dismiss() } } }
                .buttonStyle(ChunkyButtonStyle(color: Theme.panelHighlight, shadow: Theme.panel, height: 44, textColor: Theme.textPrimary))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
        }

        VStack(spacing: 0) {
            if p.relation == .friend {
                listButton(L("Freund entfernen"), "person.fill.xmark", Theme.textMuted) { confirmRemove = true }
                Divider().background(Theme.panelHighlight)
            }
            listButton(L("Melden"), "flag.fill", Color(hex: 0xE39B3A)) { showReport = true }
            Divider().background(Theme.panelHighlight)
            listButton(L("Blockieren"), "hand.raised.fill", Theme.red, destructive: true) { confirmBlock = true }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
        .padding(.top, 8)
        .confirmationDialog(L("{0} als Freund entfernen?", p.name), isPresented: $confirmRemove, titleVisibility: .visible) {
            Button(L("Entfernen"), role: .destructive) { Task { if await run({ try await friends.remove(p.userId) }) { dismiss() } } }
            Button(L("Abbrechen"), role: .cancel) {}
        }
        .confirmationDialog(L("{0} blockieren?", p.name), isPresented: $confirmBlock, titleVisibility: .visible) {
            Button(L("Blockieren"), role: .destructive) { Task { if await run({ try await friends.block(p.userId) }) { dismiss() } } }
            Button(L("Abbrechen"), role: .cancel) {}
        } message: {
            Text(L("Ihr seid dann keine Freunde mehr, und {0} kann dich nicht mehr finden oder anfragen.", p.name))
        }
        .confirmationDialog(L("Warum meldest du {0}?", p.name), isPresented: $showReport, titleVisibility: .visible) {
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) { Task { if await run({ try await friends.report(p.userId, reason: reason) }) { flash(L("Danke! Wir sehen uns das an.")) } } }
            }
            Button(L("Abbrechen"), role: .cancel) {}
        }
    }

    private func chip(_ text: String, gold: Bool = false) -> some View {
        Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(gold ? Theme.gold : Theme.textSecondary)
            .padding(.horizontal, 8).frame(height: 22)
            .background(Capsule().fill(Color.black.opacity(0.25)))
    }

    private func stat(_ icon: String, _ color: Color, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundColor(color)
            Text(value).font(.system(size: 20, weight: .black, design: .rounded)).foregroundColor(Theme.textPrimary)
            Text(caption).font(.system(size: 11)).foregroundColor(Theme.textMuted).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
    }

    private func listButton(_ title: String, _ icon: String, _ color: Color, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 8).fill(color))
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(destructive ? Theme.redLight : Theme.textPrimary)
                Spacer()
            }
            .padding(12)
        }
        .buttonStyle(.plain)
    }

    /// true = geklappt
    @discardableResult
    private func run(_ work: () async throws -> Void) async -> Bool {
        do { try await work(); return true } catch { flash(FriendError.message(error)); return false }
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation { if toast == text { toast = nil } }
        }
    }
}

// MARK: - Hinweis oben

/// Neue Anfrage (oder angenommene) während die App offen ist – der Zwilling der Push-Nachricht.
struct FriendBanner: View {
    @ObservedObject private var friends = FriendsStore.shared
    var onOpen: () -> Void
    /// Freundestruhe öffnen
    var onOpenChest: (UUID) -> Void = { _ in }

    var body: some View {
        if let news = friends.news {
            Group {
                if news.kind == .reward { rewardBanner(news) } else { requestBanner(news) }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x1B2A4C)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder((news.kind == .reward ? Theme.gold : Theme.blueLight).opacity(0.4), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear { Haptics.shared.play(news.kind == .reward ? .victory : .select) }
            .task(id: news) {
                try? await Task.sleep(nanoseconds: (news.kind == .reward ? 8 : 6) * 1_000_000_000)
                withAnimation(.easeOut(duration: 0.25)) { if friends.news == news { friends.news = nil } }
            }
        }
    }

    private func rewardBanner(_ news: FriendsStore.News) -> some View {
        HStack(spacing: 10) {
            ChestView(rarity: .gold, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Freundestruhe!"))
                    .font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(Theme.textPrimary)
                Text(L("Für deinen ersten Freund gibt es eine Goldtruhe."))
                    .font(.system(size: 12)).foregroundColor(Theme.textSecondary).lineLimit(2)
            }
            Spacer(minLength: 4)
            if let id = news.chestId {
                Button(L("Öffnen")) { friends.news = nil; onOpenChest(id) }
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.navy)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Capsule().fill(Theme.gold))
            }
        }
    }

    private func requestBanner(_ news: FriendsStore.News) -> some View {
            HStack(spacing: 10) {
                Image(systemName: news.kind == .request ? "person.2.fill" : "heart.fill")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(LinearGradient(colors: [Theme.blueLight, Theme.blue], startPoint: .top, endPoint: .bottom)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(news.kind == .request ? L("Neue Freundschaftsanfrage") : L("Neuer Freund!"))
                        .font(.system(size: 14, weight: .black, design: .rounded)).foregroundColor(Theme.textPrimary)
                    Text(news.kind == .request ? L("{0} möchte mit dir befreundet sein.", news.name) : L("{0} hat deine Freundschaftsanfrage angenommen.", news.name))
                        .font(.system(size: 12)).foregroundColor(Theme.textSecondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Button(L("Ansehen")) { friends.news = nil; onOpen() }
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.navy)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background(Capsule().fill(Theme.gold))
            }
    }
}

// MARK: - Partien gegeneinander

/// Die letzten Spiele gegen einen Freund im Profil (wie FriendHistory in Friends.tsx). Erst 5, auf Wunsch alle.
struct FriendHistory: View {
    let userId: UUID
    @State private var games: [FriendsStore.FriendMatch]?
    @State private var showAll = false

    var body: some View {
        Group {
            if let games, !games.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: L("Letzte Partien"))
                    VStack(spacing: 0) {
                        ForEach(Array((showAll ? games : Array(games.prefix(5))).enumerated()), id: \.element.id) { i, g in
                            if i > 0 { Divider().background(Theme.panelHighlight) }
                            row(g)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                    if games.count > 5, !showAll {
                        Button(L("Alle {0} Partien zeigen", games.count)) { withAnimation { showAll = true } }
                            .font(.system(size: 14, weight: .bold)).foregroundColor(Theme.blueLight)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .task(id: userId) { games = (try? await FriendsStore.shared.matches(with: userId)) ?? [] }
    }

    private func row(_ g: FriendsStore.FriendMatch) -> some View {
        let (label, color): (String, Color) = {
            switch g.result {
            case .win: return (L("Sieg"), Color(hex: 0x8FE39A))
            case .loss: return (L("Niederlage"), Theme.redLight)
            case .draw: return (L("Remis"), Theme.textSecondary)
            }
        }()
        return HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded)).foregroundColor(color)
                .frame(minWidth: 84).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.18)))
            VStack(alignment: .leading, spacing: 1) {
                Text(g.reason.map { L(OnlineAccount.serverReasons[$0] ?? $0) } ?? "")
                    .font(.system(size: 14)).foregroundColor(Theme.textPrimary).lineLimit(1)
                Text(g.endedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12)).foregroundColor(Theme.textMuted)
            }
            Spacer(minLength: 4)
            if g.rated {
                let d = g.trophyDelta ?? 0
                Label("\(d > 0 ? "+" : "")\(d)", systemImage: "trophy.fill")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(d >= 0 ? Theme.gold : Theme.textSecondary)
            } else {
                FriendlyTag()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
    }
}

/// Grüner Punkt am Avatar: gerade online.
struct OnlineDot: View {
    var size: CGFloat = 12
    var body: some View {
        Circle().fill(Color(hex: 0x4CD964))
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Theme.panelRaised, lineWidth: size * 0.2))
            .accessibilityLabel(L("Online"))
    }
}

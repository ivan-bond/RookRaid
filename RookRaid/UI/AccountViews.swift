import SwiftUI

/// Dialog auf der Startseite, solange die Einstellungen zu sind (dort zeigt ihn der Konto-Bereich selbst).
struct AccountRestoreAlert: ViewModifier {
    var settingsOpen: Bool
    @ObservedObject private var account = OnlineAccount.shared

    func body(content: Content) -> some View {
        content.alert(L("Spielstand vom Konto laden?"), isPresented: Binding(
            get: { !settingsOpen && account.pendingRestore != nil },
            set: { shown in
                if !shown, account.pendingRestore != nil { account.resolveRestore(load: false) }
            }
        ), presenting: account.pendingRestore) { _ in
            Button(L("Spielstand laden")) { account.resolveRestore(load: true) }
            Button(L("Diesen Stand behalten"), role: .cancel) { account.resolveRestore(load: false) }
        } message: { p in
            Text(AccountRestore.message(p))
        }
    }
}

/// Text für „Spielstand vom Konto laden?“ – auf der Startseite und im Konto-Bereich.
enum AccountRestore {
    static func message(_ p: ServerProgress) -> String {
        guard let s = p.snapshot else { return "" }
        let date = s.createdAt.formatted(date: .abbreviated, time: .shortened)
        return L("Auf deinem Konto ist ein Spielstand gesichert: {0} Trophäen, {1} Karten, {2} Siege (Stand {3}). Laden ersetzt den Spielstand auf diesem iPhone.",
                 p.trophies, s.unlockedCards.count, s.wins, date)
    }
}

// MARK: - Konto (Online-Phase 1, Anleitung Schritt 7)

/// Abschnitt „Konto“ in den Einstellungen: Status, Spielername, Server-Trophäen, Sichern, Abmelden, Löschen.
struct AccountSection: View {
    @ObservedObject private var account = OnlineAccount.shared
    @ObservedObject private var store = ProfileStore.shared
    @State private var nameSheet: OnlineNameSheet.Purpose?
    @State private var confirmDelete = false
    @State private var confirmDeleteFinal = false
    @State private var confirmSignOut = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Konto"))
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(Theme.textMuted)
                .padding(.horizontal, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                statusRow
                if account.hasAccount {
                    divider
                    button(L("Spielername ändern"), "pencil", Theme.blueLight) { nameSheet = .rename }
                    divider
                    appleRow
                    if account.status == .apple {
                        divider
                        button(L("Abmelden"), "rectangle.portrait.and.arrow.right", Theme.textSecondary) { confirmSignOut = true }
                    }
                    divider
                    button(L("Konto löschen"), "trash", Theme.red) { confirmDelete = true }
                } else {
                    divider
                    button(L("Online-Konto erstellen"), "person.crop.circle.badge.plus", Theme.green) { nameSheet = .create }
                    divider
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Schon ein Konto?"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        AppleSecureButton(linking: false) { errorText = $0 }
                    }
                    .padding(12)
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))
            .disabled(account.busy)

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.red)
                    .padding(.horizontal, 4)
            }
        }
        .task { await account.reload() }
        .sheet(item: $nameSheet) { purpose in OnlineNameSheet(purpose: purpose) }
        .confirmationDialog(L("Online-Konto löschen?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L("Weiter"), role: .destructive) { confirmDeleteFinal = true }
            Button(L("Abbrechen"), role: .cancel) {}
        } message: {
            Text(L("Spielername, Online-Trophäen, Online-Bilanz und die Sicherung deines Fortschritts werden vom Server gelöscht. Dein Spielstand auf diesem iPhone bleibt erhalten."))
        }
        .alert(L("Wirklich endgültig löschen?"), isPresented: $confirmDeleteFinal) {
            Button(L("Endgültig löschen"), role: .destructive) { Task { await delete() } }
            Button(L("Abbrechen"), role: .cancel) {}
        } message: {
            Text(L("Das lässt sich nicht rückgängig machen."))
        }
        .alert(L("Spielstand vom Konto laden?"), isPresented: restoreBinding, presenting: account.pendingRestore) { _ in
            Button(L("Spielstand laden")) { account.resolveRestore(load: true) }
            Button(L("Diesen Stand behalten"), role: .cancel) { account.resolveRestore(load: false) }
        } message: { p in
            Text(restoreMessage(p))
        }
        .confirmationDialog(L("Abmelden?"), isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button(L("Abmelden")) { Task { await account.signOut() } }
            Button(L("Abbrechen"), role: .cancel) {}
        } message: {
            Text(L("Mit Apple kannst du dich jederzeit wieder anmelden und deinen Fortschritt laden."))
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.hasAccount ? store.profile.name : L("Gast"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if let p = account.progress, account.hasAccount {
                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(p.trophies)", systemImage: "trophy.fill")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(Theme.gold)
                    Text(L("{0} S · {1} N · {2} R", p.onlineWins, p.onlineLosses, p.onlineDraws))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                }
            }
            if account.busy { ProgressView().tint(.white) }
        }
        .padding(12)
    }

    private var appleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo").foregroundColor(.white).frame(width: 22)
                Text(account.status == .apple ? L("Mit Apple gesichert") : L("Mit Apple sichern"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(account.status == .apple ? Theme.green : .white)
                Spacer()
            }
            if account.status != .apple {
                AppleSecureButton(linking: true) { errorText = $0 }
            }
        }
        .padding(12)
    }

    private var statusIcon: String {
        switch account.status {
        case .apple: return "checkmark.shield.fill"
        case .anonymous: return "exclamationmark.shield.fill"
        case .guest, .unavailable: return "person.crop.circle"
        }
    }

    private var statusColor: Color {
        switch account.status {
        case .apple: return Theme.green
        case .anonymous: return Theme.gold
        case .guest, .unavailable: return Theme.textMuted
        }
    }

    private var statusText: String {
        switch account.status {
        case .apple: return L("Mit Apple gesichert")
        case .anonymous: return L("Nicht gesichert – geht verloren, wenn du die App löschst.")
        case .guest: return L("Noch kein Online-Konto. Dein Fortschritt liegt nur auf diesem iPhone.")
        case .unavailable: return L("Keine Verbindung zum Server.")
        }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { account.pendingRestore != nil }, set: { shown in
            if !shown && account.pendingRestore != nil { account.resolveRestore(load: false) }
        })
    }

    private func restoreMessage(_ p: ServerProgress) -> String {
        AccountRestore.message(p)
    }

    private func delete() async {
        errorText = nil
        do { try await account.deleteAccount() } catch { errorText = AccountError(error).message }
    }

    private var divider: some View {
        Rectangle().fill(Theme.panelHighlight).frame(height: 1).padding(.leading, 46)
    }

    private func button(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundColor(color).frame(width: 22)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(color == Theme.red ? Theme.red : .white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Spielername wählen (eindeutig, Entscheidung E8): beim ersten Online-Konto oder zum Umbenennen.
struct OnlineNameSheet: View {
    enum Purpose: String, Identifiable {
        case create, rename
        var id: String { rawValue }
    }

    let purpose: Purpose
    /// Nach erfolgreichem Anlegen (Gegnersuche kann danach starten)
    var onDone: (() -> Void)? = nil

    @ObservedObject private var account = OnlineAccount.shared
    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var check: OnlineAccount.NameCheck?
    @State private var checking = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var unchanged: Bool { purpose == .rename && trimmed.lowercased() == store.profile.name.lowercased() }
    private var canSave: Bool { check == .available && !account.busy && !checking && !unchanged }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(purpose == .create
                     ? L("So sehen dich deine Gegner. Jeden Namen gibt es nur einmal.")
                     : L("Dein neuer Name gilt sofort für alle Online-Partien."))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    TextField(L("Spielername"), text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { if canSave { Task { await save() } } }
                    checkBadge
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelRaised))

                Text(hint)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(hintColor)
                    .fixedSize(horizontal: false, vertical: true)

                if let errorText {
                    Text(errorText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.red)
                }

                Button { Task { await save() } } label: {
                    HStack {
                        if account.busy { ProgressView().tint(.white) }
                        Text(purpose == .create ? L("Konto erstellen") : L("Speichern"))
                            .font(.system(size: 16, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(canSave ? Theme.green : Theme.panelHighlight))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)

                if purpose == .create {
                    Text(L("Deine Trophäen werden übernommen (höchstens 1.500). Danach zählen online nur die Trophäen vom Server."))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(16)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(purpose == .create ? L("Online-Konto") : L("Spielername ändern"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Abbrechen")) { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            // Name-Dialog ohne Konto geschlossen: anonyme Anmeldung vom Namen-Prüfen wieder löschen
            if purpose == .create && !account.hasAccount {
                Task { await account.discardProbeSession() }
            }
        }
        .onAppear {
            // Vorbelegt mit dem lokalen Namen, außer dem Platzhalter „Du“
            let local = store.profile.name
            name = local == L("Du") || local == "Du" ? "" : local
            focused = true
        }
        .task(id: trimmed) {
            check = nil
            errorText = nil
            guard !trimmed.isEmpty, !unchanged else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            checking = true
            let result = await account.checkName(trimmed)
            guard !Task.isCancelled else { return }
            check = result
            checking = false
        }
    }

    @ViewBuilder private var checkBadge: some View {
        if checking {
            ProgressView().tint(.white)
        } else if let check {
            Image(systemName: check == .available ? "checkmark.circle.fill" : check == .unknown ? "wifi.exclamationmark" : "xmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(check == .available ? Theme.green : check == .unknown ? Theme.gold : Theme.red)
        }
    }

    private var hint: String {
        switch check {
        case .available: return L("Der Name ist frei.")
        case .taken: return L("Dieser Name ist schon vergeben.")
        case .invalid: return L("2–16 Zeichen: Buchstaben, Ziffern, Leerzeichen, _ . - (kein Leerzeichen am Anfang oder Ende)")
        case .unknown: return L("Keine Verbindung zum Server.")
        case nil: return L("2–16 Zeichen: Buchstaben, Ziffern, Leerzeichen, _ . - (kein Leerzeichen am Anfang oder Ende)")
        }
    }

    private var hintColor: Color {
        switch check {
        case .available: return Theme.green
        case .taken, .invalid: return Theme.red
        case .unknown: return Theme.gold
        case nil: return Theme.textMuted
        }
    }

    private func save() async {
        errorText = nil
        do {
            switch purpose {
            case .create: try await account.createAccount(name: trimmed)
            case .rename: try await account.rename(to: trimmed)
            }
            Haptics.shared.play(.select)
            dismiss()
            onDone?()
        } catch {
            let e = AccountError(error)
            if e == .nameTaken { check = .taken }
            errorText = e.message
        }
    }
}

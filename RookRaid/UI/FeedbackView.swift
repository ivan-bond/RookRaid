import SwiftUI

/// Profil → Feedback: eine Notiz von Ivan und ein kurzes Formular (wie web/src/screens/Feedback.tsx).
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: FeedbackService.Category = .bug
    @State private var message = ""
    @State private var contact = ""
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?
    @FocusState private var focus: Field?

    private enum Field { case message, contact }
    private var valid: Bool { message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 }

    var body: some View {
        NavigationStack {
            ScrollView {
                if sent { done } else { form }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("Feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !sent { Button(L("Abbrechen")) { dismiss() } }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            note
            label(L("Worum geht es?"))
            HStack(spacing: 8) {
                ForEach(FeedbackService.Category.allCases) { c in
                    Button {
                        Haptics.shared.play(.select)
                        category = c
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: c.icon).font(.system(size: 16, weight: .bold))
                            Text(c.label).font(.system(size: 12, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundColor(category == c ? .white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(category == c ? Theme.blue.opacity(0.25) : Theme.panelRaised))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(category == c ? Theme.blueLight : Color.white.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(PressScaleStyle())
                    .accessibilityAddTraits(category == c ? .isSelected : [])
                }
            }
            label(L("Deine Nachricht"))
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(L("Was ist passiert? Was würdest du ändern?"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                        .padding(.horizontal, 14).padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .message)
                    .frame(minHeight: 130)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .onChange(of: message) { v in if v.count > 4000 { message = String(v.prefix(4000)) } }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(focus == .message ? Theme.blueLight : Color.white.opacity(0.1), lineWidth: 1))
            label(L("E-Mail für eine Antwort (optional)"))
            TextField("name@example.com", text: $contact)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .focused($focus, equals: .contact)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panelRaised))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(focus == .contact ? Theme.blueLight : Color.white.opacity(0.1), lineWidth: 1))
            Text(L("App-Version, Gerät und Sprache werden mitgeschickt."))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textMuted)
            if let error {
                Text(error)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.red.opacity(0.25)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: submit) {
                HStack(spacing: 8) {
                    if sending { ProgressView().tint(.white) }
                    Text(sending ? L("Wird gesendet …") : L("Feedback senden"))
                }
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(15)
                .background(RoundedRectangle(cornerRadius: 14).fill(valid && !sending ? Theme.green : Theme.panelHighlight))
                .foregroundColor(.white)
            }
            .buttonStyle(PressScaleStyle())
            .disabled(!valid || sending)
        }
        .padding(16)
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(LinearGradient(colors: [Theme.blue, Theme.blueDark], startPoint: .top, endPoint: .bottom)))
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Hi, ich bin Ivan!"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(L("Rook Raid ist gerade in der Beta. Ich freue mich riesig über dein Feedback: Bugs, unausgeglichene Karten, fehlende Funktionen – alles, was dir auffällt."))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L("Danke, dass du mitspielst! – Ivan"))
                    .font(.system(size: 13, weight: .bold).italic())
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: [Theme.blueDark.opacity(0.55), Color(hex: 0x4A1E2C).opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.blueLight.opacity(0.2), lineWidth: 1))
    }

    private var done: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundColor(Theme.green)
                .padding(.top, 30)
            Text(L("Danke für dein Feedback!"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            Text(L("Ich lese jede Nachricht und melde mich, wenn du eine E-Mail angegeben hast."))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { dismiss() } label: {
                Text(L("Fertig"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.green))
                    .foregroundColor(.white)
            }
            .buttonStyle(PressScaleStyle())
            .padding(.top, 8)
        }
        .padding(16)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .foregroundColor(Theme.textSecondary)
    }

    private func submit() {
        guard valid, !sending else { return }
        focus = nil
        sending = true
        error = nil
        Task {
            do {
                try await FeedbackService.send(category: category, message: message, contact: contact)
                Haptics.shared.play(.victory)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { sent = true }
            } catch FeedbackService.SendError.rateLimited {
                Haptics.shared.play(.invalid)
                error = L("Zu viele Nachrichten – bitte versuch es in einer Stunde noch einmal.")
            } catch {
                Haptics.shared.play(.invalid)
                self.error = L("Senden hat nicht geklappt. Prüfe deine Verbindung oder schreib direkt an {0}.", FeedbackService.email)
            }
            sending = false
        }
    }
}

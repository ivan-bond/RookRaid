import SwiftUI

/// Erster Start: den Spieler vorstellen, bevor Rocky die Regeln zeigt und die erste Schlacht beginnt
/// (wie `Welcome.tsx` im Web). Drei kurze Bildschirme wie bei den meisten Handyspielen:
/// 1 die Welt (was ist Rook Raid?) · 2 wer bist du (Name + Avatar, beides später änderbar) ·
/// 3 wie gut kennst du Schach (Rocky passt seine ersten Sätze an). „Überspringen“ lässt alles, wie es ist.
enum ChessLevel: String { case new, rules, pro }

/// Was die Begrüßung herausgefunden hat – Rocky nutzt es in seinen ersten Sätzen.
struct WelcomeHello: Equatable {
    var level: ChessLevel?
    var named: Bool
}

struct WelcomeView: View {
    let onFinish: (WelcomeHello) -> Void

    @ObservedObject private var store = ProfileStore.shared
    @State private var page = 0
    @State private var named = false
    @State private var name = ""
    @State private var avatar: Avatar = .knight
    @State private var appeared = false
    /// Ist der Name auf dem Server noch frei? (nil = noch nicht geprüft; wie im Namensdialog fürs Online-Spiel)
    @State private var check: OnlineAccount.NameCheck?
    @State private var checking = false
    @FocusState private var nameFocused: Bool

    /// Die sechs freien Avatare (der Springer gehört allen; der gewählte kommt in die Sammlung).
    private static let starters: [Avatar] = [.knight, .fox, .owl, .bear, .penguin, .frog]
    private static let first = ["Rook", "Knight", "Pawn", "Bishop", "Queen", "King", "Storm", "Frost", "Blitz", "Nova", "Shadow", "Iron"]
    private static let second = ["Raider", "Rider", "Hero", "Master", "Fox", "Wolf", "Star", "Ace", "Hawk", "Titan"]

    /// Namensvorschlag wie „FrostRider42“ (höchstens 14 Zeichen, in jeder Sprache gleich).
    static func suggestName() -> String {
        "\(first.randomElement()!)\(second.randomElement()!)\(Int.random(in: 10...99))"
    }

    /// Der Standardname in jeder Sprache („Du“ wird übersetzt gespeichert – wie `isDefaultName` im Web).
    static func isDefaultName(_ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty || ["Du", "You", "Tú", "Toi", "Tu", "Ты", "你", L("Du")].contains(n)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var valid: Bool { trimmed.isEmpty || (OnlineAccount.isValidName(trimmed) && trimmed == name) }
    /// Weiter geht's, wenn der Name gültig und nicht vergeben ist (ohne Verbindung prüft das Online-Spiel später).
    private var nameOk: Bool { valid && !checking && check != .taken && (trimmed.isEmpty || check != nil) }

    /// Ein Vorschlag, der noch frei ist (bis zu 5 Versuche; ohne Verbindung der erste).
    private static func freeSuggestion() async -> String {
        var n = suggestName()
        for _ in 0..<5 {
            if await OnlineAccount.shared.checkName(n) != .taken { return n }
            n = suggestName()
        }
        return n
    }

    private struct Level {
        let id: ChessLevel
        let icon: String
        let color: Color
        let title: String
        let text: String
    }

    private static let levels: [Level] = [
        Level(id: .new, icon: "leaf.fill", color: Color(hex: 0x8FE39A), title: "Ich bin neu", text: "Ich lerne Schach gerade erst."),
        Level(id: .rules, icon: "book.fill", color: Theme.blueLight, title: "Ich kenne die Regeln", text: "Ich weiß, wie die Figuren ziehen."),
        Level(id: .pro, icon: "crown.fill", color: Theme.gold, title: "Ich spiele oft", text: "Schach ist mein Ding."),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x141C33), Theme.backgroundDeep], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            RadialGradient(colors: [Theme.blue.opacity(0.28), .clear], center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 360)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 6)
                Group {
                    switch page {
                    case 0: hero
                    case 1: identity
                    default: levelChoice
                    }
                }
                .id(page)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer(minLength: 6)
                card
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .onAppear {
            let suggested = Self.isDefaultName(store.profile.name)
            name = suggested ? Self.suggestName() : store.profile.name
            if suggested {
                let first = name
                Task { let free = await Self.freeSuggestion(); if name == first { name = free } }
            }
            if let raw = store.profile.selectedAvatar, let a = Avatar(rawValue: raw) { avatar = a }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) { appeared = true }
        }
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { k in
                Capsule()
                    .fill(k < page ? Theme.gold : k == page ? Theme.gold.opacity(0.55) : Color.white.opacity(0.12))
                    .frame(height: 5)
            }
            Button(L("Überspringen")) { finish(WelcomeHello(level: nil, named: named)) }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(Theme.panelRaised))
                .padding(.leading, 6)
        }
        .padding(.top, 10)
    }

    // MARK: 1 · Die Welt

    private var hero: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.gold.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 140))
                .frame(width: 280, height: 280)
                .scaleEffect(appeared ? 1 : 0.6)
            VStack(spacing: 22) {
                Image("AppLogo")
                    .resizable().scaledToFit()
                    .frame(maxWidth: 220, maxHeight: 220)
                    .shadow(color: .black.opacity(0.6), radius: 18, y: 10)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .opacity(appeared ? 1 : 0)
                HStack(spacing: 12) {
                    let pieces: [PieceType] = [.knight, .bishop, .queen, .rook]
                    ForEach(Array(pieces.enumerated()), id: \.offset) { k, p in
                        PieceImage(type: p, color: k % 2 == 1 ? .black : .white)
                            .frame(width: 46, height: 46)
                            .shadow(color: .black.opacity(0.6), radius: 6, y: 4)
                            .offset(y: appeared ? 0 : 30)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3 + Double(k) * 0.14), value: appeared)
                    }
                }
            }
        }
    }

    // MARK: 2 · Wer bist du?

    private var identity: some View {
        VStack(spacing: 10) {
            PlayerAvatar(size: 124, avatar: avatar)
                .id(avatar)
                .transition(.scale.combined(with: .opacity))
            Text(trimmed.isEmpty ? L("Du") : trimmed)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .frame(minHeight: 28)
            let columns = Array(repeating: GridItem(.fixed(60), spacing: 8), count: 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Self.starters) { a in
                    Button {
                        Feedback.play(.select, .select)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { avatar = a }
                    } label: {
                        PlayerAvatar(size: 52, avatar: a)
                            .padding(3)
                            .overlay(Circle().strokeBorder(avatar == a ? Theme.gold : .clear, lineWidth: 2))
                            .shadow(color: avatar == a ? Theme.gold.opacity(0.45) : .clear, radius: 8)
                            .scaleEffect(avatar == a ? 1.08 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(a.name)
                    .accessibilityAddTraits(avatar == a ? .isSelected : [])
                }
            }
            .frame(maxWidth: 400)
        }
    }

    // MARK: 3 · Schach-Erfahrung

    private var levelChoice: some View {
        VStack(spacing: 10) {
            ForEach(Array(Self.levels.enumerated()), id: \.offset) { k, l in
                Button { choose(l.id) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: l.icon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(l.color)
                            .frame(width: 46, height: 46)
                            .background(RoundedRectangle(cornerRadius: 14).fill(l.color.opacity(0.2)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(l.title))
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textPrimary)
                            Text(L(l.text))
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(Double(k) * 0.09), value: page)
            }
        }
        .frame(maxWidth: 440)
    }

    // MARK: Karte unten

    private var card: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L(page == 0 ? "Willkommen" : page == 1 ? "Dein Held" : "Fast geschafft").uppercased())
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundColor(Theme.gold)
            Text(L(page == 0 ? "Willkommen in Rook Raid!" : page == 1 ? "Wer bist du?" : "Wie gut kennst du Schach?"))
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L(page == 0
                   ? "Auf dem Schachbrett ist Chaos ausgebrochen: Die Figuren haben Superkräfte entdeckt. Führe deine eigene Armee an, sammle Karten und steig in der Arena bis an die Spitze auf."
                   : page == 1 ? "Such dir einen Namen und ein Bild aus. Beides kannst du später im Profil ändern."
                   : "Dann weiß Rocky, wie viel er dir erklären soll."))
                .font(.system(size: 14.5, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if page == 0 {
                Button { go(1) } label: {
                    HStack(spacing: 8) {
                        Text(L("Los geht's"))
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .black))
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold, shadow: CardStyle.ultimateDeep, textColor: Theme.navy))
                .modifier(PulseGlow(color: Theme.gold, active: true))
                .padding(.top, 4)
            } else if page == 1 {
                HStack(spacing: 8) {
                    TextField(L("Spielername"), text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { saveIdentity() }
                        .onChange(of: name) { v in if v.count > 16 { name = String(v.prefix(16)) } }
                        .padding(13)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
                    Button {
                        Haptics.shared.play(.select)
                        Task { name = await Self.freeSuggestion() }
                    } label: {
                        Image(systemName: "dice.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.gold)
                            .frame(width: 48, height: 48)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Anderer Vorschlag"))
                }
                if !valid {
                    Text(L("2–16 Zeichen: Buchstaben, Ziffern, Leerzeichen, _ . - (kein Leerzeichen am Anfang oder Ende)"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.redLight)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let hint = checkHint {
                    HStack(spacing: 5) {
                        if check == .available { Image(systemName: "checkmark.circle.fill") }
                        Text(hint.text)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(hint.color)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: saveIdentity) {
                    HStack(spacing: 8) {
                        Text(L("Weiter"))
                        Image(systemName: "chevron.right").font(.system(size: 15, weight: .black))
                    }
                }
                .buttonStyle(ChunkyButtonStyle())
                .disabled(!nameOk)
                .opacity(nameOk ? 1 : 0.5)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: 560, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: valid)
        .animation(.easeOut(duration: 0.2), value: check)
        .task(id: trimmed) { await checkTyped() }
    }

    private var checkHint: (text: String, color: Color)? {
        switch check {
        case .available: return (L("Der Name ist frei."), Color(hex: 0x8FE39A))
        case .taken: return (L("Dieser Name ist schon vergeben."), Theme.redLight)
        case .unknown: return (L("Ob der Name frei ist, prüfen wir, wenn du online spielst."), Theme.textSecondary)
        default: return nil
        }
    }

    /// Live-Prüfung beim Tippen: kurz nach der letzten Taste (wie der Namensdialog fürs Online-Spiel).
    private func checkTyped() async {
        check = nil
        checking = false
        let n = trimmed
        guard !n.isEmpty, valid else { return }
        checking = true
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        let result = await OnlineAccount.shared.checkName(n)
        guard !Task.isCancelled, n == trimmed else { return }
        check = result == .invalid ? nil : result
        checking = false
    }

    /// Die Prüfung braucht eine anonyme Anmeldung; ohne Online-Konto wird sie wieder weggeräumt.
    private func finish(_ hello: WelcomeHello) {
        Task { await OnlineAccount.shared.discardProbeSession() }
        onFinish(hello)
    }

    private func go(_ n: Int) {
        Feedback.play(.select, .select)
        nameFocused = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { page = n }
    }

    private func saveIdentity() {
        guard nameOk else { return }
        let n = trimmed
        if !n.isEmpty { store.profile.name = n }
        if avatar != .knight, !store.profile.ownedAvatars.contains(avatar.rawValue) {
            store.profile.ownedAvatars.append(avatar.rawValue)
        }
        store.profile.selectedAvatar = avatar == .knight ? nil : avatar.rawValue
        named = !n.isEmpty
        go(2)
    }

    private func choose(_ level: ChessLevel) {
        Feedback.play(.reward, .victory)
        finish(WelcomeHello(level: level, named: named))
    }
}

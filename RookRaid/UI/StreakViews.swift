import SwiftUI

enum FlameStyle {
    static let lit = Color(hex: 0xFF7A2F)
    static let glow = Color(hex: 0xFFB347)
    static let off = Color(hex: 0x5A6785)
    static let ice = Color(hex: 0x6CC8FF)
    static let iceDark = Color(hex: 0x2E7FB8)
}

enum ShardStyle {
    static let color = Color(hex: 0x7FE3FF)
    static let deep = Color(hex: 0x2A9CC4)
}

/// Kleine Flammen-Anzeige mit Serienlänge. Grau, solange heute noch keine Flamme brennt.
/// Ein Tipp öffnet die Flammen-Statistik mit Kalender, Flammenschutz und Meilensteinen.
struct FlameBadge: View {
    @ObservedObject var store = ProfileStore.shared
    var compact = false
    @State var showSheet = false

    var body: some View {
        let lit = store.flameLitToday
        Button {
            Haptics.shared.play(.select)
            showSheet = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: compact ? 15 : 17, weight: .bold))
                    .foregroundStyle(lit
                                     ? AnyShapeStyle(LinearGradient(colors: [FlameStyle.glow, FlameStyle.lit], startPoint: .top, endPoint: .bottom))
                                     : AnyShapeStyle(FlameStyle.off))
                Text("\(store.currentStreak)")
                    .font(.system(size: compact ? 14 : 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(lit ? Theme.textPrimary : Theme.textSecondary)
            }
            .padding(.horizontal, compact ? 6 : 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(compact ? Color.clear : Theme.panelRaised))
            // v0.9.34: ohne Eis-Abzeichen – den Flammenschutz zeigt die Flammen-Statistik
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("{0} Tage in Folge{1}, {2} Flammenschutz. Tippen für Statistik", store.currentStreak, lit ? L(", heute entzündet") : L(", heute noch offen"), store.profile.streakFreezes))
        .sheet(isPresented: $showSheet) { FlameSheet() }
    }
}

// MARK: - Flammen-Statistik

struct FlameSheet: View {
    @ObservedObject var store = ProfileStore.shared
    @Environment(\.dismiss) var dismiss
    @State var monthOffset = 0
    @State var bought = false
    @State var appear = false

    var body: some View {
        let lit = store.flameLitToday
        let streak = store.currentStreak
        let tier = FlameTier.forStreak(streak)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hero(lit: lit, streak: streak, tier: tier)
                    weekStrip
                    if !lit { igniteButton }
                    tierProgress(streak: streak, tier: tier)
                    statsRow
                    freezeCard
                    milestones
                    calendar
                }
                .padding(16)
            }
            .background(
                ZStack {
                    Theme.background
                    RadialGradient(colors: [(lit ? tier.colors[0] : FlameStyle.off).opacity(0.28), .clear],
                                   center: .top, startRadius: 10, endRadius: 460)
                }
                .ignoresSafeArea()
            )
            .navigationTitle(L("Flammen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L("Fertig")) { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        // Kein Dauer-Zustand mehr: Die Flamme flackert über ihre eigene Zeitleiste.
        // (Vorher hat eine Endlos-Animation beim Öffnen das ganze Fenster mitschwingen lassen.)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.15)) { appear = true }
            if lit { Haptics.shared.play(.chestReveal) }
        }
    }

    // MARK: Lebendige Flamme

    private func hero(lit: Bool, streak: Int, tier: FlameTier) -> some View {
        VStack(spacing: 8) {
            ZStack {
                LivingFlame(colors: lit ? tier.colors : [FlameStyle.off, Color(hex: 0x7A86A3), Color(hex: 0xA9B4C8)],
                            lit: lit, embers: lit ? tier.embers : 3)
                    .frame(width: 210, height: 230)
                    .scaleEffect(appear ? 1 : 0.3, anchor: .bottom)
                Text("\(streak)")
                    .font(.system(size: streak >= 100 ? 50 : 60, weight: .black, design: .rounded))
                    .foregroundColor(Theme.navy)
                    .shadow(color: .white.opacity(0.7), radius: 0, y: -2)
                    .shadow(color: (lit ? tier.colors[2] : .clear), radius: 10)
                    .offset(y: 48)
                    .scaleEffect(appear ? 1 : 2.2)
                    .opacity(appear ? 1 : 0)
                    .contentTransition(.numericText())
            }
            .frame(height: 236)

            Text(lit ? tier.name.uppercased() : L("FLAMME AUS"))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1.6)
                .foregroundColor(lit ? Theme.navy : Theme.textSecondary)
                .padding(.horizontal, 14)
                .frame(height: 26)
                .background(Capsule().fill(lit ? AnyShapeStyle(LinearGradient(colors: [tier.colors[2], tier.colors[0]], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.panelRaised)))
                .rotationEffect(.degrees(-3))
            Text(streak == 1 ? L("1 Tag in Folge") : L("{0} Tage in Folge", streak))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            TimelineView(.periodic(from: Date(), by: 60)) { ctx in
                Text(status(lit: lit, streak: streak, now: ctx.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(lit ? tier.colors[1] : Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func status(lit: Bool, streak: Int, now: Date) -> String {
        if lit { return L("Heute entzündet – bis morgen!") }
        if streak > 0 {
            let protect = store.profile.streakFreezes > 0 ? L(" Dein Flammenschutz springt notfalls ein.") : ""
            return L("Noch {0}, um die Flamme zu entzünden.{1}", ProfileStore.untilMidnightText(now), protect)
        }
        return L("Löse ein Puzzle oder beende eine Partie, um eine neue Serie zu starten.")
    }

    /// Diese Woche als sieben Fackeln: entzündet, eingefroren, offen – heute pulsiert.
    private var weekStrip: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let monday = cal.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        let names = [L("Mo"), L("Di"), L("Mi"), L("Do"), L("Fr"), L("Sa"), L("So")]
        return HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: monday) ?? monday
                let active = store.wasActive(on: day)
                let frozen = store.wasFrozen(on: day)
                let isToday = cal.isDate(day, inSameDayAs: today)
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(active ? FlameStyle.lit.opacity(0.25) : (frozen ? FlameStyle.ice.opacity(0.22) : Color.white.opacity(0.05)))
                        if active {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [FlameStyle.glow, FlameStyle.lit], startPoint: .top, endPoint: .bottom))
                        } else if frozen {
                            Image(systemName: "snowflake").font(.system(size: 17, weight: .black)).foregroundColor(FlameStyle.ice)
                        } else {
                            Image(systemName: "flame").font(.system(size: 16, weight: .bold))
                                .foregroundColor(day > today ? Theme.textMuted.opacity(0.4) : Theme.textMuted)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(isToday ? Theme.cream : .clear, lineWidth: 2))
                    .scaleEffect(appear ? 1 : 0.2)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.25 + Double(i) * 0.05), value: appear)
                    Text(names[i])
                        .font(.system(size: 10, weight: isToday ? .black : .bold))
                        .foregroundColor(isToday ? Theme.cream : Theme.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }

    /// Noch nicht entzündet: direkt zum Tagespuzzle.
    private var igniteButton: some View {
        Button {
            Haptics.shared.play(.select)
            dismiss()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                NotificationCenter.default.post(name: .showPuzzles, object: nil)
            }
        } label: {
            Label(L("Jetzt entzünden – Puzzle lösen"), systemImage: "flame.fill")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .buttonStyle(ChunkyButtonStyle(color: FlameStyle.lit, shadow: Color(hex: 0xB3471A), height: 54))
        .overlay(ShineSweep().clipShape(RoundedRectangle(cornerRadius: 12)).allowsHitTesting(false))
    }

    /// Flammenstufe: Funke → Lagerfeuer → Blaue Flamme → Inferno → Ewige Flamme
    private func tierProgress(streak: Int, tier: FlameTier) -> some View {
        HStack(spacing: 10) {
            ForEach(FlameTier.all, id: \.minDays) { t in
                let reached = streak >= t.minDays && streak > 0
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: t.minDays == tier.minDays && reached ? 24 : 17, weight: .black))
                        .foregroundStyle(reached
                                         ? AnyShapeStyle(LinearGradient(colors: [t.colors[2], t.colors[0]], startPoint: .top, endPoint: .bottom))
                                         : AnyShapeStyle(Theme.textMuted.opacity(0.5)))
                        .shadow(color: reached ? t.colors[0].opacity(0.7) : .clear, radius: 6)
                        .frame(height: 28)
                    Text("\(t.minDays)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(reached ? Theme.textPrimary : Theme.textMuted)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if let next = FlameTier.all.first(where: { $0.minDays > streak }) {
                Text(L("Noch {0} Tage bis {1}", next.minDays - streak, next.name))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(next.colors[1])
                    .offset(y: 14)
            }
        }
        .padding(.bottom, 12)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            stat(L("Aktuell"), "\(store.currentStreak)", "flame.fill", FlameStyle.lit)
            stat(L("Rekord"), "\(store.profile.bestStreak)", "crown.fill", Theme.gold)
            stat(L("Aktive Tage"), "\(store.profile.activeDays.count)", "calendar", Theme.blueLight)
            stat(L("Eingefroren"), "\(store.profile.frozenDays.count)", "snowflake", FlameStyle.ice)
        }
    }

    private func stat(_ label: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.16)))
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                .foregroundColor(Theme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Theme.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.25), lineWidth: 1))
    }

    private var freezeCard: some View {
        let n = store.profile.streakFreezes
        let full = n >= ProfileStore.maxFreezes
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    ForEach(0..<ProfileStore.maxFreezes, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(i < n ? FlameStyle.ice.opacity(0.25) : Color.white.opacity(0.05))
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(i < n ? FlameStyle.ice : Color.white.opacity(0.15),
                                              style: StrokeStyle(lineWidth: 1.5, dash: i < n ? [] : [4, 3]))
                            Image(systemName: i < n ? "snowflake" : "plus")
                                .font(.system(size: i < n ? 20 : 13, weight: .black))
                                .foregroundColor(i < n ? .white : Theme.textMuted)
                        }
                        .frame(width: 44, height: 50)
                        .scaleEffect(bought && i == n - 1 ? 1.15 : 1)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Flammenschutz {0}/{1}", n, ProfileStore.maxFreezes))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(L("Verpasst du einen Tag, friert ein Schutz deine Flamme automatisch ein – die Serie bleibt."))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                if store.buyFreeze() {
                    Haptics.shared.play(.chestReveal)
                    SoundPlayer.shared.play(.reward)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { bought = true }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        withAnimation(.spring()) { bought = false }
                    }
                } else {
                    Haptics.shared.play(.invalid)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                    Text(full ? L("Vorrat voll") : L("Flammenschutz kaufen"))
                    if !full {
                        Spacer(minLength: 4)
                        ShardPrice(amount: ProfileStore.freezePrice, affordable: store.profile.shards >= ProfileStore.freezePrice, dark: true)
                    }
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(ChunkyButtonStyle(color: full ? Theme.panelHighlight : FlameStyle.ice, shadow: full ? Theme.panel : FlameStyle.iceDark, height: 46))
            .disabled(full)
            Text(L("Gratis bei 7, 30, 100 und 365 Tagen in Folge."))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textMuted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(FlameStyle.ice.opacity(0.35), lineWidth: 1))
    }

    // MARK: Kalender

    private var monthStart: Date {
        let cal = Calendar.current
        let now = cal.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        return cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
    }

    private var calendar: some View {
        let cal = Calendar.current
        let start = monthStart
        let days = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let weekday = cal.component(.weekday, from: start)   // 1 = So
        let lead = (weekday + 5) % 7                          // Montag zuerst
        let fmt: DateFormatter = {
            let f = DateFormatter()
            f.locale = Localizer.shared.language.locale
            f.dateFormat = "LLLL yyyy"
            return f
        }()
        let todayKey = ProfileStore.dayKey()
        return VStack(spacing: 10) {
            HStack {
                Button { withAnimation { monthOffset -= 1 } } label: {
                    Image(systemName: "chevron.left").frame(width: 36, height: 32)
                }
                .disabled(monthOffset <= -12)
                Spacer()
                Text(fmt.string(from: start))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Button { withAnimation { monthOffset += 1 } } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 32)
                }
                .disabled(monthOffset >= 0)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Theme.textSecondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach([L("Mo"), L("Di"), L("Mi"), L("Do"), L("Fr"), L("Sa"), L("So")], id: \.self) { d in
                    Text(d).font(.system(size: 10, weight: .bold)).foregroundColor(Theme.textMuted)
                }
                ForEach(0..<(lead + days), id: \.self) { i in
                    if i < lead {
                        Color.clear.frame(height: 34)
                    } else {
                        let date = cal.date(byAdding: .day, value: i - lead, to: start) ?? start
                        dayCell(date, number: i - lead + 1, isToday: ProfileStore.dayKey(date) == todayKey)
                    }
                }
            }
            HStack(spacing: 14) {
                legend("flame.fill", FlameStyle.lit, L("Entzündet"))
                legend("snowflake", FlameStyle.ice, L("Eingefroren"))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.panelRaised))
    }

    private func dayCell(_ date: Date, number: Int, isToday: Bool) -> some View {
        let active = store.wasActive(on: date)
        let frozen = store.wasFrozen(on: date)
        return ZStack {
            Circle().fill(active ? FlameStyle.lit.opacity(0.25) : (frozen ? FlameStyle.ice.opacity(0.25) : Color.clear))
            if active {
                Image(systemName: "flame.fill").font(.system(size: 14, weight: .bold)).foregroundColor(FlameStyle.lit)
            } else if frozen {
                Image(systemName: "snowflake").font(.system(size: 13, weight: .bold)).foregroundColor(FlameStyle.ice)
            } else {
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(date > Date() ? Theme.textMuted.opacity(0.5) : Theme.textSecondary)
            }
            if isToday { Circle().strokeBorder(Theme.cream, lineWidth: 1.5) }
        }
        .frame(height: 34)
    }

    private func legend(_ icon: String, _ tint: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundColor(tint)
            Text(text).font(.system(size: 10, weight: .semibold)).foregroundColor(Theme.textMuted)
        }
    }

    // MARK: Meilensteine

    private var milestones: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Meilensteine"))
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(Theme.textPrimary)
            ForEach(ProfileStore.streakMilestones) { m in
                let reached = store.profile.streakMilestones.contains(m.days)
                let isNext = store.nextStreakMilestone?.days == m.days
                VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(reached ? FlameStyle.lit : Theme.panel)
                        Text("\(m.days)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(reached ? .white : Theme.textSecondary)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("{0} Tage in Folge", m.days))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(reached ? Theme.textSecondary : Theme.textPrimary)
                        Text(m.rewardText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(reached ? Theme.textMuted : Theme.gold)
                    }
                    Spacer()
                    if let chest = m.chest, !reached {
                        ChestView(rarity: chest, size: 34)
                    }
                    Image(systemName: reached ? "checkmark.circle.fill" : "lock.fill")
                        .font(.system(size: reached ? 18 : 12, weight: .bold))
                        .foregroundColor(reached ? Theme.green : Theme.textMuted)
                }
                // Fortschritt zum nächsten Meilenstein: eigene Zeile unter dem Text, so breit wie die Karte (ohne Überstand).
                if isNext {
                    ProgressPill(fraction: min(1, Double(store.currentStreak) / Double(m.days)),
                                 text: "\(min(store.currentStreak, m.days))/\(m.days)")
                        .padding(.leading, 48)
                }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(isNext ? FlameStyle.lit.opacity(0.1) : Theme.panelRaised))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isNext ? FlameStyle.lit.opacity(0.5) : .clear, lineWidth: 1))
            }
        }
    }
}

/// Splitter-Preis mit Symbol – rot gedimmt, wenn es nicht reicht.
struct ShardPrice: View {
    let amount: Int
    var affordable = true
    var dark = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "diamond.fill").font(.system(size: 10, weight: .black))
            Text("\(amount)").font(.system(size: 14, weight: .heavy, design: .rounded).monospacedDigit())
        }
        .foregroundColor(affordable ? (dark ? .white : ShardStyle.color) : Theme.redLight)
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(Capsule().fill(Color.black.opacity(dark ? 0.25 : 0.3)))
    }
}

/// Hinweis beim Öffnen der App: Ein Flammenschutz hat die Serie gerettet.
struct FreezeNoticeOverlay: View {
    let days: Int
    let streak: Int
    let onClose: () -> Void
    @State var appear = false
    @State var crack = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
                .onTapGesture { onClose() }
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [FlameStyle.ice.opacity(0.5), .clear], center: .center, startRadius: 4, endRadius: 90))
                        .frame(width: 180, height: 180)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color.white, FlameStyle.ice], startPoint: .top, endPoint: .bottom))
                        .shadow(color: FlameStyle.ice.opacity(0.8), radius: 16)
                    Image(systemName: "snowflake")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(appear ? 180 : 0))
                        .offset(x: 38, y: -40)
                }
                .scaleEffect(appear ? 1 : 0.4)
                Text(L("Flamme eingefroren!"))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(days == 1
                     ? L("Du hast gestern ausgesetzt – dein Flammenschutz hat deine Serie von {0} Tagen gerettet.", streak)
                     : L("Du hast {0} Tage ausgesetzt – deine Flammenschutze haben deine Serie von {1} Tagen gerettet.", days, streak))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Text(L("Entzünde heute deine Flamme, damit sie weiterbrennt."))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FlameStyle.glow)
                    .multilineTextAlignment(.center)
                Button(L("Weiter so!"), action: onClose)
                    .buttonStyle(ChunkyButtonStyle(color: FlameStyle.ice, shadow: FlameStyle.iceDark, height: 52))
                    .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(FlameStyle.ice.opacity(0.5), lineWidth: 1.5))
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
            Haptics.shared.play(.frost)
            SoundPlayer.shared.play(.frost)
        }
    }
}

/// Einmal auf dem Menü, nachdem eine Partie oder ein Puzzle die Tagesflamme entzündet hat.
struct FlameIgnitionOverlay: View {
    let streak: Int
    let onDone: () -> Void

    @State private var spark = false
    @State private var burst = false
    @State private var number = false
    @State private var ring = false
    @State private var finished = false

    var body: some View {
        ZStack {
            Color.black.opacity(burst ? 0.62 : 0.2).ignoresSafeArea()
            RadialGradient(colors: [FlameStyle.glow.opacity(burst ? 0.55 : 0), .clear],
                           center: .center, startRadius: 10, endRadius: burst ? 420 : 40)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(FlameStyle.glow.opacity(ring ? 0 : 0.85), lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .scaleEffect(ring ? 4.2 + CGFloat(i) * 0.6 : 0.2)
                    .animation(.easeOut(duration: 0.9).delay(0.35 + Double(i) * 0.12), value: ring)
            }

            VStack(spacing: 18) {
                ZStack {
                    if spark && !burst {
                        Image(systemName: "sparkle")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(FlameStyle.glow)
                            .offset(y: spark ? -70 : 40)
                            .opacity(burst ? 0 : 1)
                    }
                    LivingFlame(colors: FlameTier.forStreak(streak).colors, lit: burst, embers: 16)
                        .frame(width: 180, height: 210)
                        .scaleEffect(burst ? 1 : 0.08)
                        .opacity(burst ? 1 : 0.15)
                }
                .frame(height: 220)

                VStack(spacing: 6) {
                    Text(L("Flamme entzündet!"))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: FlameStyle.lit, radius: 12)
                    Text(streak == 1 ? L("Tag 1 deiner Serie") : L("{0} Tage in Folge", streak))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(FlameStyle.glow)
                }
                .scaleEffect(number ? 1 : 0.4)
                .opacity(number ? 1 : 0)
                .rotationEffect(.degrees(number ? 0 : -8))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear(perform: play)
    }

    private func play() {
        withAnimation(.easeOut(duration: 0.28)) { spark = true }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !finished else { return }
            Haptics.shared.play(.chestBurst)
            SoundPlayer.shared.play(.chestOpen, volume: 0.85)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) { burst = true }
            ring = true
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !finished else { return }
            Haptics.shared.play(.victory)
            SoundPlayer.shared.play(.rewardBig, volume: 0.7)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) { number = true }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            dismiss()
        }
    }

    private func dismiss() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}

/// Zeile im Ergebnisfenster, wenn die Flamme gerade entzündet wurde.
struct FlameLitRow: View {
    let streak: Int
    @State var pop = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [FlameStyle.glow, FlameStyle.lit], startPoint: .top, endPoint: .bottom))
                .scaleEffect(pop ? 1 : 0.2)
                .rotationEffect(.degrees(pop ? 0 : -25))
            VStack(alignment: .leading, spacing: 1) {
                Text(L("Flamme entzündet!"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(Theme.textPrimary)
                Text(streak == 1 ? L("Tag 1 deiner Serie") : L("{0} Tage in Folge", streak))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                if streak >= ProfileStore.shared.profile.bestStreak, let m = ProfileStore.streakMilestones.first(where: { $0.days == streak }) {
                    Text(L("Meilenstein! {0}", m.rewardText))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(Theme.gold)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(FlameStyle.lit.opacity(0.18)))
        .overlay(Capsule().strokeBorder(FlameStyle.lit.opacity(0.7), lineWidth: 1))
        .onAppear {
            Haptics.shared.play(.victory)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.5)) { pop = true }
        }
    }
}

// MARK: - Flammenstufen

struct FlameTier {
    let minDays: Int
    let name: String
    /// außen, Mitte, innen
    let colors: [Color]
    let embers: Int

    static var all: [FlameTier] { [
        FlameTier(minDays: 1, name: L("Funke"), colors: [Color(hex: 0xFF7A2F), Color(hex: 0xFFB347), Color(hex: 0xFFF1A8)], embers: 6),
        FlameTier(minDays: 7, name: L("Lagerfeuer"), colors: [Color(hex: 0xF0452E), Color(hex: 0xFF9A3C), Color(hex: 0xFFE27A)], embers: 10),
        FlameTier(minDays: 30, name: L("Blaue Flamme"), colors: [Color(hex: 0x2F6FE4), Color(hex: 0x6CC8FF), Color(hex: 0xE6F7FF)], embers: 12),
        FlameTier(minDays: 100, name: L("Inferno"), colors: [Color(hex: 0x8B3FD9), Color(hex: 0xE15BD1), Color(hex: 0xFFD1F4)], embers: 14),
        FlameTier(minDays: 365, name: L("Ewige Flamme"), colors: [Color(hex: 0xE0A82E), Color(hex: 0xFFE08A), Color(hex: 0xFFFFFF)], embers: 18)
    ] }

    static func forStreak(_ streak: Int) -> FlameTier {
        all.last { streak >= $0.minDays } ?? all[0]
    }
}

/// Gezeichnete Flamme mit drei Zungen, die über die Zeit flackern, und aufsteigender Glut.
/// Alles hängt nur an der Uhrzeit – keine Endlos-Animation, die andere Ansichten mitreißen könnte.
struct LivingFlame: View {
    @Environment(\.liveAnimations) private var live
    let colors: [Color]
    var lit = true
    var embers = 8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !lit || !live)) { ctx in
            let t = lit ? ctx.date.timeIntervalSinceReferenceDate : 0
            Canvas { g, size in
                let w = size.width, h = size.height
                let base = CGPoint(x: w / 2, y: h * 0.96)
                // Schein
                let glow = Path(ellipseIn: CGRect(x: w * 0.12, y: h * 0.3, width: w * 0.76, height: h * 0.72))
                g.fill(glow, with: .radialGradient(Gradient(colors: [colors[0].opacity(lit ? 0.5 : 0.15), .clear]),
                                                  center: CGPoint(x: w / 2, y: h * 0.66), startRadius: 2, endRadius: w * 0.45))
                // Glut
                for i in 0..<embers {
                    let fi = Double(i)
                    let phase = (t * 0.45 + fi * 0.137).truncatingRemainder(dividingBy: 1)
                    let x = w / 2 + CGFloat(sin(fi * 12.9 + t * 1.7)) * w * 0.26 * CGFloat(0.4 + phase)
                    let y = base.y - CGFloat(phase) * h * 1.0
                    let r = CGFloat(2.2 + (fi.truncatingRemainder(dividingBy: 3))) * CGFloat(1 - phase * 0.6)
                    var c = g
                    c.opacity = (1 - phase) * (lit ? 0.9 : 0.4)
                    c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(colors[1]))
                }
                // Drei Zungen: außen, Mitte, innen
                let scales: [CGFloat] = [1.0, 0.74, 0.46]
                for (i, scale) in scales.enumerated() {
                    let path = LivingFlame.tongue(base: base, width: w * 0.78 * scale, height: h * 0.9 * scale, t: t * (1 + Double(i) * 0.25) + Double(i))
                    g.fill(path, with: .linearGradient(Gradient(colors: [colors[min(i + 1, 2)], colors[i]]),
                                                       startPoint: CGPoint(x: w / 2, y: base.y - h * 0.9 * scale), endPoint: base))
                }
                // Umriss nur um die äußere Zunge – wie die übrigen Grafiken der App
                let outer = LivingFlame.tongue(base: base, width: w * 0.78, height: h * 0.9, t: t)
                g.stroke(outer, with: .color(Color(hex: 0x0B1A33).opacity(0.85)), lineWidth: 5)
            }
        }
        .allowsHitTesting(false)
    }

    static func tongue(base: CGPoint, width w: CGFloat, height h: CGFloat, t: Double) -> Path {
        let cx = base.x, by = base.y
        let sway = CGFloat(sin(t * 3.1)) * w * 0.09
        let s2 = CGFloat(sin(t * 4.3 + 1.2)) * w * 0.05
        let s3 = CGFloat(cos(t * 3.7)) * w * 0.06
        let tip = CGPoint(x: cx + sway, y: by - h)
        var p = Path()
        p.move(to: CGPoint(x: cx, y: by))
        p.addCurve(to: CGPoint(x: cx - w * 0.16 + s2, y: by - h * 0.66),
                   control1: CGPoint(x: cx - w * 0.6, y: by),
                   control2: CGPoint(x: cx - w * 0.52 + s3, y: by - h * 0.42))
        p.addCurve(to: tip,
                   control1: CGPoint(x: cx - w * 0.06 + s2, y: by - h * 0.8),
                   control2: CGPoint(x: tip.x - w * 0.1, y: by - h * 0.9))
        p.addCurve(to: CGPoint(x: cx + w * 0.2 + s3, y: by - h * 0.56),
                   control1: CGPoint(x: tip.x + w * 0.12, y: by - h * 0.86),
                   control2: CGPoint(x: cx + w * 0.16 + s2, y: by - h * 0.74))
        p.addCurve(to: CGPoint(x: cx, y: by),
                   control1: CGPoint(x: cx + w * 0.6, y: by - h * 0.4),
                   control2: CGPoint(x: cx + w * 0.58, y: by))
        p.closeSubpath()
        return p
    }
}

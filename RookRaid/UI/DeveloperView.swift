import SwiftUI

#if DEBUG
/// Entwicklerbereich (nur Debug-Builds): Regeltests gegen den JavaScript-Regel-Port, aktive Regeln,
/// Gast-ID und der Fortschritts-Abzug für die spätere Konto-Übernahme.
struct DeveloperView: View {
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var rules = OnlineRules.shared
    @State private var results: [RulesSelfTest.Result] = []
    @State private var ran = false

    var body: some View {
        List {
            Section("Regeln") {
                row("Regel-Version", "v\(RulesConfig.current.version)")
                row("Online-Regeln", onlineRulesLabel)
                row("Mana", "max \(GameState.maxMana) · +\(GameState.manaPerTurn)/Zug · guter Zug +\(GameState.goodMoveBonus)")
                row("Ultimate", "\(GameState.ultimateCost) Mana (Festung \(Ultimate.fortress.cost))")
                ForEach(CardType.allCases.sorted { $0.cost < $1.cost }, id: \.self) { c in
                    row(c.name, "\(c.cost) Mana · lädt \(c.cooldown)" + (c.keepsTurn ? " · Bonus" : ""))
                }
            }
            Section {
                Button(ran ? "Regeltests erneut ausführen" : "Regeltests ausführen") {
                    results = RulesSelfTest.run()
                    ran = true
                }
                if ran {
                    let passed = results.filter(\.passed).count
                    Label("\(passed)/\(results.count) bestanden", systemImage: passed == results.count ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .foregroundColor(passed == results.count ? Theme.green : Theme.red)
                    ForEach(results) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: r.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(r.passed ? Theme.green : Theme.red)
                                Text(r.name).font(.system(size: 13, weight: .semibold))
                            }
                            if !r.detail.isEmpty {
                                Text(r.detail).font(.system(size: 11)).foregroundColor(Theme.textMuted)
                            }
                        }
                    }
                }
            } header: {
                Text("Regeltests")
            } footer: {
                Text("Dieselben Fälle wie Tools/rules-js (node check-golden.js). Weicht etwas ab, rechnen Swift und der Server-Port unterschiedlich.")
            }
            Section("Online-Vorbereitung") {
                row("Gast-ID", DeviceIdentity.current().guestId.uuidString)
                row("Online", OnlineConfig.enabled ? "an" : "aus (lokal)")
                row("Gegnersuche", "\(Int(OnlineConfig.matchmakingTimeout)) s, dann Bot")
                ShareLink(item: store.progressSnapshotJSON()) {
                    Label("Fortschritt als JSON teilen", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Entwickler")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var onlineRulesLabel: String {
        switch rules.lock {
        case .open: return "v\(RulesConfig.current.version) · offen"
        case .updateAvailable: return "Update nötig"
        case .serverBehind: return "Server hinterher"
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            Text(value)
                .font(.system(size: 12).monospacedDigit())
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.trailing)
        }
    }
}
#endif

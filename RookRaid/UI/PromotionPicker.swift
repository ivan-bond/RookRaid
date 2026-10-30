import SwiftUI

/// Auswahl bei der Bauernumwandlung: vier große Karten im Rook-Raid-Stil.
struct PromotionPicker: View {
    let color: PlayerColor
    let onChoose: (PieceType) -> Void
    let onCancel: () -> Void
    @State private var appear = false

    private let options: [(PieceType, String, String)] = [
        (.queen, L("Dame"), L("Die Stärkste")),
        (.rook, L("Turm"), L("Linien")),
        (.bishop, L("Läufer"), L("Diagonalen")),
        (.knight, L("Springer"), L("Sprünge"))
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(Theme.gold)
                    Text(L("Umwandlung"))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                }
                Text(L("Wähle die neue Figur"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                HStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                        Button {
                            Feedback.play(.summon, .summon)
                            onChoose(option.0)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LinearGradient(colors: [Theme.cream, Color(hex: 0xF3E3BE)],
                                                             startPoint: .top, endPoint: .bottom))
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Theme.gold, lineWidth: 3)
                                        .padding(3)
                                    PieceImage(type: option.0, color: color)
                                        .padding(10)
                                        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                                }
                                .frame(width: 70, height: 88)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.navy, lineWidth: 3))
                                Text(option.1)
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundColor(Theme.textPrimary)
                                Text(option.2)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .rotationEffect(.degrees(appear ? Double(i - 1) * 2 - 1 : 0))
                            .offset(y: appear ? 0 : 60)
                            .opacity(appear ? 1 : 0)
                            .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(Double(i) * 0.06), value: appear)
                        }
                        .buttonStyle(PromotionButtonStyle())
                        .accessibilityLabel(L("Umwandeln in {0}", option.1))
                    }
                }

                Button(L("Abbrechen"), action: onCancel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(minHeight: 44)
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.panelHighlight, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 24)
            .scaleEffect(appear ? 1 : 0.85)
            .padding(16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appear = true }
        }
    }
}

struct PromotionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

import SwiftUI

/// Rook Raid on social media (like web/src/socials.ts): Settings › „Folge uns“.
/// The brand marks are vector images in the asset catalog (Social*.imageset; X and TikTok from Simple Icons, CC0).
struct Social: Identifiable {
    let id: String
    let name: String
    let url: URL
    let image: String
    let color: Color

    static let all: [Social] = [
        Social(id: "instagram", name: "Instagram", url: URL(string: "https://www.instagram.com/rookraid/")!,
               image: "SocialInstagram", color: Color(hex: 0xD62976)),
        Social(id: "x", name: "X", url: URL(string: "https://x.com/rookraidchess")!,
               image: "SocialX", color: Color(hex: 0x2B2F36)),
        Social(id: "tiktok", name: "TikTok", url: URL(string: "https://www.tiktok.com/@rookraid")!,
               image: "SocialTikTok", color: Color(hex: 0xFE2C55)),
    ]
}

/// One row in Settings: brand tile, name, an arrow that says „opens outside the app“.
struct SocialRow: View {
    let social: Social

    var body: some View {
        Link(destination: social.url) {
            HStack(spacing: 12) {
                Image(social.image)
                    .resizable().renderingMode(.template).scaledToFit()
                    .frame(width: 14, height: 14)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 6).fill(social.color))
                Text(social.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(L("Folge uns"))
    }
}

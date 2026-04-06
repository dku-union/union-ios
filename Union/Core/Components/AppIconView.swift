import SwiftUI

struct AppIconView: View {
    var iconUrl: String?
    var emoji: String?
    var colorHex: String?
    var size: CGFloat = 56

    private var resolvedEmoji: String { emoji ?? "📱" }
    private var resolvedColorHex: String { colorHex ?? "8B8B8B" }

    var body: some View {
        if let iconUrl, let url = URL(string: iconUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    emojiIcon
                default:
                    emojiIcon.opacity(0.6)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            emojiIcon
        }
    }

    private var emojiIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: resolvedColorHex),
                            Color(hex: resolvedColorHex).opacity(0.8),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(resolvedEmoji)
                .font(.system(size: size * 0.45))
        }
    }
}

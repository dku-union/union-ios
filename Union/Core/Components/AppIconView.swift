import SwiftUI

struct AppIconView: View {
    let emoji: String
    let colorHex: String
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: colorHex),
                            Color(hex: colorHex).opacity(0.8),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            Text(emoji)
                .font(.system(size: size * 0.45))
        }
    }
}

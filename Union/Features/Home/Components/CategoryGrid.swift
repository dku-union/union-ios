import SwiftUI

// MARK: - Category Grid (Glass Chips)

struct CategoryGrid: View {
    let categories: [AppCategory]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UNSpacing.md) {
                ForEach(categories) { category in
                    CategoryChip(category: category)
                }
            }
            .padding(.horizontal, UNSpacing.xl)
        }
    }
}

// MARK: - Category Chip (Glassmorphism)

private struct CategoryChip: View {
    let category: AppCategory

    var body: some View {
        Button {} label: {
            VStack(spacing: UNSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex).opacity(0.15))
                        .frame(width: 52, height: 52)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 52, height: 52)
                        .opacity(0.5)

                    Text(category.emoji)
                        .font(.title2)
                }

                Text(category.name)
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textPrimary)
            }
            .frame(width: 68)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

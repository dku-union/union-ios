import SwiftUI

struct CategoryGrid: View {
    let categories: [AppCategory]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UBSpacing.md) {
                ForEach(categories) { category in
                    CategoryPill(category: category)
                }
            }
            .padding(.horizontal, UBSpacing.xl)
        }
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let category: AppCategory

    var body: some View {
        VStack(spacing: UBSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color(hex: category.colorHex).opacity(0.12))
                    .frame(width: 52, height: 52)

                Text(category.emoji)
                    .font(.title2)
            }

            Text(category.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(UBColor.textSecondary)
        }
        .frame(width: 64)
    }
}

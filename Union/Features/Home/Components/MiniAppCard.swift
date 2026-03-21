import SwiftUI

// MARK: - Vertical Card (for horizontal scroll sections)

struct MiniAppCardVertical: View {
    let app: MiniApp

    var body: some View {
        VStack(alignment: .leading, spacing: UBSpacing.md) {
            AppIconView(emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 56)

            VStack(alignment: .leading, spacing: UBSpacing.xs) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(UBColor.textPrimary)
                    .lineLimit(1)

                Text(app.publisher)
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
                    .lineLimit(1)
            }

            HStack(spacing: UBSpacing.xs) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(UBColor.amber)
                Text(String(format: "%.1f", app.rating))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(UBColor.textSecondary)
            }
        }
        .frame(width: 120)
        .padding(UBSpacing.lg)
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.lg, style: .continuous))
        .ubShadow(.subtle)
    }
}

// MARK: - Horizontal Card (for recent / list views)

struct MiniAppCardHorizontal: View {
    let app: MiniApp

    var body: some View {
        HStack(spacing: UBSpacing.lg) {
            AppIconView(emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 48)

            VStack(alignment: .leading, spacing: UBSpacing.xs) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(UBColor.textPrimary)
                    .lineLimit(1)

                Text(app.publisher)
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: UBSpacing.xs) {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(UBColor.amber)
                    Text(String(format: "%.1f", app.rating))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(UBColor.textSecondary)
                }

                if app.isNew {
                    Text("NEW")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(UBColor.coral)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(UBSpacing.lg)
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.md, style: .continuous))
        .ubShadow(.subtle)
    }
}

// MARK: - Ranked Card (for popular section with ranking number)

struct MiniAppCardRanked: View {
    let app: MiniApp
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: UBSpacing.md) {
            ZStack(alignment: .topLeading) {
                AppIconView(emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 60)

                Text("\(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(
                        rank <= 3
                            ? UBColor.brand
                            : UBColor.textTertiary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .offset(x: -4, y: -4)
            }

            VStack(alignment: .leading, spacing: UBSpacing.xs) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(UBColor.textPrimary)
                    .lineLimit(1)

                Text(app.publisher)
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
                    .lineLimit(1)
            }

            HStack(spacing: UBSpacing.xs) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(UBColor.amber)
                Text(String(format: "%.1f", app.rating))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(UBColor.textSecondary)
                Text("(\(app.ratingCount))")
                    .font(.caption2)
                    .foregroundStyle(UBColor.textTertiary)
            }
        }
        .frame(width: 130)
        .padding(UBSpacing.lg)
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.lg, style: .continuous))
        .ubShadow(.card)
    }
}

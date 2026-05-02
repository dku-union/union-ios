import SwiftUI

// MARK: - Vertical Card (Glassmorphism)

struct MiniAppCardVertical: View {
    let app: MiniApp
    var onTap: (MiniApp) -> Void = { _ in }

    var body: some View {
        NavigationLink(destination: MiniAppWebView(miniApp: app)) {
            VStack(alignment: .leading, spacing: UNSpacing.md) {
                AppIconView(iconUrl: app.iconUrl, emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 56)

                VStack(alignment: .leading, spacing: UNSpacing.xs) {
                    Text(app.name)
                        .font(UNFont.bodySmall(.semibold))
                        .foregroundStyle(UNColor.textPrimary)
                        .lineLimit(1)

                    Text(app.publisher)
                        .font(UNFont.captionSmall())
                        .foregroundStyle(UNColor.textTertiary)
                        .lineLimit(1)
                }

                ratingView
            }
            .frame(width: 120)
            .padding(UNSpacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap(app) })
    }

    private var ratingView: some View {
        HStack(spacing: UNSpacing.xs) {
            Image(systemName: "star.fill")
                .font(UNFont.captionSmall())
                .foregroundStyle(UNColor.warning)
            Text(String(format: "%.1f", app.rating))
                .font(UNFont.captionLarge(.semibold))
                .foregroundStyle(UNColor.textSecondary)
        }
    }
}

// MARK: - Horizontal Card (Glassmorphism)

struct MiniAppCardHorizontal: View {
    let app: MiniApp
    var onTap: (MiniApp) -> Void = { _ in }

    var body: some View {
        NavigationLink(destination: MiniAppWebView(miniApp: app)) {
            HStack(spacing: UNSpacing.lg) {
                AppIconView(iconUrl: app.iconUrl, emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 48)

                VStack(alignment: .leading, spacing: UNSpacing.xs) {
                    Text(app.name)
                        .font(UNFont.bodyMedium(.semibold))
                        .foregroundStyle(UNColor.textPrimary)
                        .lineLimit(1)

                    Text(app.publisher)
                        .font(UNFont.captionLarge())
                        .foregroundStyle(UNColor.textTertiary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: UNSpacing.xs) {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(UNFont.captionSmall())
                            .foregroundStyle(UNColor.warning)
                        Text(String(format: "%.1f", app.rating))
                            .font(UNFont.captionLarge(.semibold))
                            .foregroundStyle(UNColor.textSecondary)
                    }

                    if app.isNew {
                        Text("NEW")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: UNColor.gradientCoralOrange,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(UNSpacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap(app) })
    }
}

// MARK: - Ranked Card (Glassmorphism)

struct MiniAppCardRanked: View {
    let app: MiniApp
    let rank: Int
    var onTap: (MiniApp) -> Void = { _ in }

    var body: some View {
        NavigationLink(destination: MiniAppWebView(miniApp: app)) {
            VStack(alignment: .leading, spacing: UNSpacing.md) {
                ZStack(alignment: .topLeading) {
                    AppIconView(iconUrl: app.iconUrl, emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 60)

                    // Rank badge
                    Text("\(rank)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            rank <= 3
                                ? LinearGradient(colors: UNColor.gradientRedAccent, startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [UNColor.textTertiary, UNColor.textTertiary], startPoint: .top, endPoint: .bottom)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .offset(x: -6, y: -6)
                }

                VStack(alignment: .leading, spacing: UNSpacing.xs) {
                    Text(app.name)
                        .font(UNFont.bodySmall(.semibold))
                        .foregroundStyle(UNColor.textPrimary)
                        .lineLimit(1)

                    Text(app.publisher)
                        .font(UNFont.captionSmall())
                        .foregroundStyle(UNColor.textTertiary)
                        .lineLimit(1)
                }

                HStack(spacing: UNSpacing.xs) {
                    Image(systemName: "star.fill")
                        .font(UNFont.captionSmall())
                        .foregroundStyle(UNColor.warning)
                    Text(String(format: "%.1f", app.rating))
                        .font(UNFont.captionLarge(.semibold))
                        .foregroundStyle(UNColor.textSecondary)
                    if app.ratingCount > 0 {
                        Text("(\(app.ratingCount))")
                            .font(UNFont.captionSmall())
                            .foregroundStyle(UNColor.textTertiary)
                    }
                }
            }
            .frame(width: 130)
            .padding(UNSpacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap(app) })
    }
}

import SwiftUI

// MARK: - Vertical Card

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
            }
            .frame(width: 120, alignment: .leading)
            .padding(UNSpacing.lg)
            .unCardSurface()
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap(app) })
    }
}

// MARK: - Horizontal Card

struct MiniAppCardHorizontal: View {
    let app: MiniApp
    var onTap: (MiniApp) -> Void = { _ in }

    var body: some View {
        NavigationLink(destination: MiniAppWebView(miniApp: app)) {
            HStack(spacing: UNSpacing.lg) {
                AppIconView(iconUrl: app.iconUrl, emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 48)

                VStack(alignment: .leading, spacing: UNSpacing.xs) {
                    HStack(spacing: UNSpacing.xs) {
                        Text(app.name)
                            .font(UNFont.bodyMedium(.semibold))
                            .foregroundStyle(UNColor.textPrimary)
                            .lineLimit(1)

                        if app.isNew { NewBadge() }
                    }

                    Text(app.publisher)
                        .font(UNFont.captionLarge())
                        .foregroundStyle(UNColor.textTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(UNSpacing.lg)
            .unCardSurface()
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap(app) })
    }
}

// MARK: - Ranked Card

struct MiniAppCardRanked: View {
    let app: MiniApp
    let rank: Int
    var onTap: (MiniApp) -> Void = { _ in }

    var body: some View {
        NavigationLink(destination: MiniAppWebView(miniApp: app)) {
            VStack(alignment: .leading, spacing: UNSpacing.md) {
                ZStack(alignment: .topLeading) {
                    AppIconView(iconUrl: app.iconUrl, emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 60)
                    RankBadge(rank: rank)
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
            }
            .frame(width: 130, alignment: .leading)
            .padding(UNSpacing.lg)
            .unCardSurface()
        }
        .buttonStyle(ScaleButtonStyle())
        .simultaneousGesture(TapGesture().onEnded { onTap(app) })
    }
}

// MARK: - Shared Card Elements

/// 신규 앱 뱃지. 이름 옆 인라인, 솔리드 브랜드 레드.
private struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(UNColor.interactive)
            .clipShape(Capsule())
    }
}

/// 인기 랭킹 뱃지. Top 3 는 브랜드 그라디언트, 그 외는 솔리드 차콜. 흰 링으로 아이콘과 분리.
private struct RankBadge: View {
    let rank: Int

    var body: some View {
        Text("\(rank)")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background {
                if rank <= 3 {
                    LinearGradient(colors: UNColor.gradientRedAccent, startPoint: .topLeading, endPoint: .bottomTrailing)
                } else {
                    UNColor.charcoal400
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white, lineWidth: 1.5)
            )
    }
}

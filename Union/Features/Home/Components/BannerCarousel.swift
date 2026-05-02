import SwiftUI

// MARK: - Banner Carousel (Glassmorphism)

struct BannerCarousel: View {
    let banners: [Banner]
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: UNSpacing.md) {
            TabView(selection: $currentPage) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    BannerCard(banner: banner)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 170)

            // Glass page indicator
            HStack(spacing: 6) {
                ForEach(0..<banners.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? UNColor.interactive : UNColor.textTertiary.opacity(0.3))
                        .frame(width: index == currentPage ? 24 : 6, height: 6)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                }
            }
            .padding(.vertical, UNSpacing.xs)
            .padding(.horizontal, UNSpacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Banner Card

private struct BannerCard: View {
    let banner: Banner

    var body: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: UNRadius.xxl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: banner.gradientStartHex),
                            Color(hex: banner.gradientEndHex),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Glassmorphism decorative shapes
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.15))
                    .blur(radius: 20)
                    .frame(width: 160, height: 160)
                    .offset(x: geo.size.width * 0.55, y: -40)

                Circle()
                    .fill(.white.opacity(0.10))
                    .blur(radius: 15)
                    .frame(width: 100, height: 100)
                    .offset(x: geo.size.width * 0.7, y: 70)

                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.08))
                    .blur(radius: 10)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(45))
                    .offset(x: geo.size.width * 0.4, y: 10)
            }
            .clipped()

            // Content
            HStack {
                VStack(alignment: .leading, spacing: UNSpacing.sm) {
                    Text(banner.title)
                        .font(UNFont.headingLarge(.bold))
                        .foregroundStyle(.white)

                    Text(banner.subtitle)
                        .font(UNFont.bodySmall())
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()

                Text(banner.emoji)
                    .font(.system(size: 56))
                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            }
            .padding(UNSpacing.xxl)
        }
        .padding(.horizontal, UNSpacing.xl)
    }
}

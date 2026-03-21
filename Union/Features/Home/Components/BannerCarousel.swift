import SwiftUI

struct BannerCarousel: View {
    let banners: [Banner]
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: UBSpacing.md) {
            TabView(selection: $currentPage) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    BannerCard(banner: banner)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 160)

            // Custom page indicator
            HStack(spacing: 6) {
                ForEach(0..<banners.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? UBColor.brand : UBColor.border)
                        .frame(width: index == currentPage ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.35), value: currentPage)
                }
            }
        }
    }
}

// MARK: - Banner Card

private struct BannerCard: View {
    let banner: Banner

    var body: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: UBRadius.xl, style: .continuous)
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

            // Decorative circles
            GeometryReader { geo in
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .offset(x: geo.size.width * 0.6, y: -30)

                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .offset(x: geo.size.width * 0.75, y: 60)
            }
            .clipped()

            // Content
            HStack {
                VStack(alignment: .leading, spacing: UBSpacing.sm) {
                    Text(banner.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(banner.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()

                Text(banner.emoji)
                    .font(.system(size: 52))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(UBSpacing.xxl)
        }
        .padding(.horizontal, UBSpacing.xl)
        .ubShadow(.elevated)
    }
}

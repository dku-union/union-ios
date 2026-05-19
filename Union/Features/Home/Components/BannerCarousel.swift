import SwiftUI

// MARK: - Banner Carousel

struct BannerCarousel: View {
    let banners: [Banner]
    var onTap: (Banner) -> Void = { _ in }
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: UNSpacing.md) {
            TabView(selection: $currentPage) {
                ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                    Button {
                        onTap(banner)
                    } label: {
                        BannerCard(banner: banner)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 170)

            // Glass page indicator
            if banners.count > 1 {
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
}

// MARK: - Banner Card

private struct BannerCard: View {
    let banner: Banner

    var body: some View {
        Group {
            if let imageUrl = banner.imageUrl, let url = URL(string: imageUrl) {
                imageCard(url: url)
            } else {
                gradientCard
            }
        }
        .padding(.horizontal, UNSpacing.xl)
    }

    // MARK: 이미지 카드 — imageUrl 우선

    private func imageCard(url: URL) -> some View {
        ZStack {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    gradientPlaceholder
                case .failure:
                    gradientCard  // 로딩 실패 시 폴백 카드
                @unknown default:
                    gradientPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // 이미지 자체에 텍스트 포함 정책 — DB title/subtitle 가 있을 때만 오버레이.
            if let title = banner.title, !title.isEmpty {
                overlayText(title: title, subtitle: banner.subtitle)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.xxl, style: .continuous))
    }

    private func overlayText(title: String, subtitle: String?) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: UNSpacing.sm) {
                    Text(title)
                        .font(UNFont.headingLarge(.bold))
                        .foregroundStyle(.white)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(UNFont.bodySmall())
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                .padding(UNSpacing.xxl)
                Spacer()
            }
            Spacer()
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.35), .black.opacity(0)],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: 그라데이션 카드 — imageUrl 없을 때 폴백

    private var gradientCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UNRadius.xxl, style: .continuous)
                .fill(gradientFill)

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

            HStack {
                VStack(alignment: .leading, spacing: UNSpacing.sm) {
                    if let title = banner.title, !title.isEmpty {
                        Text(title)
                            .font(UNFont.headingLarge(.bold))
                            .foregroundStyle(.white)
                    }
                    if let subtitle = banner.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(UNFont.bodySmall())
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                }
                Spacer()
                if let emoji = banner.emoji, !emoji.isEmpty {
                    Text(emoji)
                        .font(.system(size: 56))
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                }
            }
            .padding(UNSpacing.xxl)
        }
    }

    private var gradientPlaceholder: some View {
        RoundedRectangle(cornerRadius: UNRadius.xxl, style: .continuous)
            .fill(gradientFill)
            .overlay(ProgressView().tint(.white))
    }

    private var gradientFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: banner.gradientStartHex ?? "FF6060"),
                Color(hex: banner.gradientEndHex ?? "FF9A5C"),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

import SwiftUI

// MARK: - Home Skeleton View
// HomeView 의 레이아웃을 그대로 미러링하는 스켈레톤.
// isLoading 상태이고 아직 데이터가 없을 때 표시됩니다.

struct HomeSkeletonView: View {
    /// 최근 사용 섹션 스켈레톤을 보여줄지 여부 (한 번이라도 앱을 실행한 적 있을 때만 true)
    let showRecentSection: Bool

    var body: some View {
        VStack(spacing: UNSpacing.xxl) {
            bannerSkeleton
            categorySkeleton
            if showRecentSection {
                horizontalSectionSkeleton(cardCount: 4, cardWidth: 120, cardHeight: 162)
            }
            horizontalSectionSkeleton(cardCount: 5, cardWidth: 130, cardHeight: 172, ranked: true)
            horizontalSectionSkeleton(cardCount: 4, cardWidth: 120, cardHeight: 162)
            recommendedSkeleton
        }
    }

    // MARK: - Banner

    private var bannerSkeleton: some View {
        VStack(spacing: UNSpacing.md) {
            SkeletonRect(cornerRadius: UNRadius.xxl)
                .frame(height: 170)
                .padding(.horizontal, UNSpacing.xl)

            // page indicator
            Capsule()
                .fill(UNColor.border)
                .frame(width: 60, height: 6)
                .shimmer()
        }
    }

    // MARK: - Categories

    private var categorySkeleton: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            sectionHeaderSkeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UNSpacing.md) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: UNSpacing.sm) {
                            SkeletonRect(cornerRadius: UNRadius.full)
                                .frame(width: 52, height: 52)
                            SkeletonRect(cornerRadius: UNRadius.sm)
                                .frame(width: 44, height: 10)
                        }
                        .frame(width: 68)
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }
        }
    }

    // MARK: - Horizontal Cards

    private func horizontalSectionSkeleton(
        cardCount: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        ranked: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            sectionHeaderSkeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UNSpacing.md) {
                    ForEach(0..<cardCount, id: \.self) { _ in
                        verticalCardSkeleton(
                            width: cardWidth,
                            height: cardHeight,
                            ranked: ranked
                        )
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }
        }
    }

    private func verticalCardSkeleton(width: CGFloat, height: CGFloat, ranked: Bool) -> some View {
        VStack(alignment: .leading, spacing: UNSpacing.md) {
            ZStack(alignment: .topLeading) {
                SkeletonRect(cornerRadius: UNRadius.md)
                    .frame(width: ranked ? 60 : 56, height: ranked ? 60 : 56)

                if ranked {
                    SkeletonRect(cornerRadius: 7)
                        .frame(width: 22, height: 22)
                        .offset(x: -6, y: -6)
                }
            }
            SkeletonRect(cornerRadius: UNRadius.sm)
                .frame(width: width * 0.75, height: 12)
            SkeletonRect(cornerRadius: UNRadius.sm)
                .frame(width: width * 0.5, height: 10)
            SkeletonRect(cornerRadius: UNRadius.sm)
                .frame(width: 40, height: 10)
        }
        .frame(width: width)
        .padding(UNSpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Recommended (vertical list)

    private var recommendedSkeleton: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            sectionHeaderSkeleton
            VStack(spacing: UNSpacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    horizontalCardSkeleton
                }
            }
            .padding(.horizontal, UNSpacing.xl)
        }
    }

    private var horizontalCardSkeleton: some View {
        HStack(spacing: UNSpacing.lg) {
            SkeletonRect(cornerRadius: UNRadius.md)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                SkeletonRect(cornerRadius: UNRadius.sm)
                    .frame(width: 120, height: 13)
                SkeletonRect(cornerRadius: UNRadius.sm)
                    .frame(width: 80, height: 11)
            }

            Spacer()

            SkeletonRect(cornerRadius: UNRadius.sm)
                .frame(width: 36, height: 11)
        }
        .padding(UNSpacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Section Header Skeleton

    private var sectionHeaderSkeleton: some View {
        HStack {
            SkeletonRect(cornerRadius: UNRadius.sm)
                .frame(width: 100, height: 16)
            Spacer()
            SkeletonRect(cornerRadius: UNRadius.sm)
                .frame(width: 48, height: 12)
        }
        .padding(.horizontal, UNSpacing.xl)
    }
}

import SwiftUI

// MARK: - Home Skeleton View
// 모든 요소를 미러링하면 오히려 어수선하므로, 히어로 배너 + 핵심 카드 몇 개만
// 크게 보여주는 미니멀 스켈레톤. 짧은 로딩 동안의 시각적 힌트 역할만 한다.

struct HomeSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: UNSpacing.xxl) {
            // 배너 (풀블리드 — 실제 배너와 동일하게 가장자리까지)
            SkeletonRect(cornerRadius: 0)
                .frame(height: 170)

            // 핵심 섹션 하나: 섹션 타이틀 + 큰 카드 한 줄
            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                SkeletonRect()
                    .frame(width: 120, height: 18)

                HStack(spacing: UNSpacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        cardSkeleton
                    }
                }
            }
            .padding(.horizontal, UNSpacing.xl)
        }
    }

    private var cardSkeleton: some View {
        VStack(alignment: .leading, spacing: UNSpacing.md) {
            SkeletonRect(cornerRadius: UNRadius.md)
                .frame(width: 56, height: 56)
            SkeletonRect()
                .frame(width: 90, height: 14)
            SkeletonRect()
                .frame(width: 60, height: 11)
        }
        .frame(width: 140, alignment: .leading)
        .padding(UNSpacing.lg)
        .unCardSurface()
    }
}

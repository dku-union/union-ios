import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let highlightWidth = geo.size.width * 0.65
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.55), location: 0.5),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: highlightWidth)
                    .offset(x: -highlightWidth + phase * (geo.size.width + highlightWidth))
                    .blendMode(.screen)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shape

/// 기본 스켈레톤 블록. 색상 + shimmer 포함.
struct SkeletonRect: View {
    var cornerRadius: CGFloat = UNRadius.sm
    var color: Color = UNColor.border

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .shimmer()
    }
}

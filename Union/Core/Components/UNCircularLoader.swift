import SwiftUI

// MARK: - Circular Arc Loader
// 기본 회전 액티비티 인디케이터(점 스포크) 대신 사용하는 원형 링 스피너.
// 옅은 트랙(전체 원) 위로 호(arc) 하나가 연속 회전한다.

struct UNCircularLoader: View {
    var size: CGFloat = 44
    var lineWidth: CGFloat = 3
    var color: Color = UNColor.interactive
    /// 회전하는 호의 길이 (0~1). 0.3 = 원 둘레의 30%.
    var arcFraction: CGFloat = 0.3

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: arcFraction)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 0.85).repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .frame(width: size, height: size)
        .onAppear { isAnimating = true }
    }
}

#Preview {
    UNCircularLoader()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UNColor.bgSecondary)
}

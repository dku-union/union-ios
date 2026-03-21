import SwiftUI

struct SectionHeader: View {
    let title: String
    var showMore: Bool = true
    var onMoreTapped: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(UBColor.textPrimary)

            Spacer()

            if showMore {
                Button {
                    onMoreTapped?()
                } label: {
                    HStack(spacing: UBSpacing.xs) {
                        Text("더보기")
                            .font(.subheadline)
                            .foregroundStyle(UBColor.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(UBColor.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, UBSpacing.xl)
    }
}

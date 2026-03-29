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
                .foregroundStyle(UNColor.textPrimary)

            Spacer()

            if showMore {
                Button {
                    onMoreTapped?()
                } label: {
                    HStack(spacing: UNSpacing.xs) {
                        Text("더보기")
                            .font(.subheadline)
                            .foregroundStyle(UNColor.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(UNColor.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, UNSpacing.xl)
    }
}

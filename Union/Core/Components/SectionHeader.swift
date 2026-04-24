import SwiftUI

struct SectionHeader: View {
    let title: String
    var showMore: Bool = true
    var onMoreTapped: (() -> Void)?

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(UNFont.headingLarge())
                .foregroundStyle(UNColor.textPrimary)

            Spacer()

            if showMore {
                Button {
                    onMoreTapped?()
                } label: {
                    HStack(spacing: UNSpacing.xs) {
                        Text("더보기")
                            .font(UNFont.bodyMedium())
                            .foregroundStyle(UNColor.textTertiary)
                        Image(systemName: "chevron.right")
                            .font(UNFont.captionLarge())
                            .foregroundStyle(UNColor.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, UNSpacing.xl)
    }
}

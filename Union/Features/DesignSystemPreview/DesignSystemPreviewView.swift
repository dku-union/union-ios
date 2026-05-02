import SwiftUI

// MARK: - Design System Preview

struct DesignSystemPreviewView: View {
    @State private var sampleText = ""
    @State private var selectedTag = "축제"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UNSpacing.xxxl) {
                    colorsSection
                    typographySection
                    buttonsSection
                    badgesSection
                    tagsSection
                    textFieldSection
                    chipsSection
                    cardSection
                    spacingSection
                    radiusSection
                    shadowSection
                }
                .padding(UNSpacing.xl)
            }
            .background(UNColor.bgPrimary)
            .navigationTitle("Design System")
        }
    }

    // MARK: - Colors

    private var colorsSection: some View {
        sectionContainer("Colors") {
            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                colorGroup("Ice Scale", colors: [
                    ("ice50", UNColor.ice50),
                    ("ice100", UNColor.ice100),
                    ("ice200", UNColor.ice200),
                    ("ice300", UNColor.ice300),
                ])

                colorGroup("Charcoal Scale", colors: [
                    ("900", UNColor.charcoal900),
                    ("800", UNColor.charcoal800),
                    ("700", UNColor.charcoal700),
                    ("600", UNColor.charcoal600),
                    ("500", UNColor.charcoal500),
                    ("400", UNColor.charcoal400),
                ])

                colorGroup("Red Scale", colors: [
                    ("red600", UNColor.red600),
                    ("red500", UNColor.red500),
                    ("red400", UNColor.red400),
                    ("red300", UNColor.red300),
                    ("red200", UNColor.red200),
                    ("red100", UNColor.red100),
                ])

                colorGroup("Semantic", colors: [
                    ("interactive", UNColor.interactive),
                    ("bgAccent", UNColor.bgAccent),
                    ("bgPrimary", UNColor.bgPrimary),
                    ("bgPressed", UNColor.bgPressed),
                ])

                colorGroup("Status", colors: [
                    ("success", UNColor.success),
                    ("warning", UNColor.warning),
                    ("error", UNColor.error),
                    ("violet", UNColor.violet),
                ])

                colorGroup("Text", colors: [
                    ("primary", UNColor.textPrimary),
                    ("secondary", UNColor.textSecondary),
                    ("tertiary", UNColor.textTertiary),
                ])

                Text("Gradients")
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textSecondary)

                HStack(spacing: UNSpacing.sm) {
                    gradientSwatch(UNColor.gradientRedAccent)
                    gradientSwatch(UNColor.gradientDeepRed)
                    gradientSwatch(UNColor.gradientCoralOrange)
                    gradientSwatch(UNColor.gradientMintTeal)
                    gradientSwatch(UNColor.gradientAmberYellow)
                }
            }
        }
    }

    // MARK: - Typography

    private var typographySection: some View {
        sectionContainer("Typography") {
            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                typoRow("Display L", UNFont.displayLarge())
                typoRow("Display M", UNFont.displayMedium())
                typoRow("Display S", UNFont.displaySmall())

                UNDivider()

                typoRow("Heading L", UNFont.headingLarge())
                typoRow("Heading M", UNFont.headingMedium())
                typoRow("Heading S", UNFont.headingSmall())

                UNDivider()

                typoRow("Body L", UNFont.bodyLarge())
                typoRow("Body M", UNFont.bodyMedium())
                typoRow("Body S", UNFont.bodySmall())

                UNDivider()

                typoRow("Caption L", UNFont.captionLarge())
                typoRow("Caption S", UNFont.captionSmall())

                UNDivider()

                typoRow("Label L", UNFont.labelLarge())
                typoRow("Label M", UNFont.labelMedium())
                typoRow("Label S", UNFont.labelSmall())
            }
        }
    }

    // MARK: - Buttons

    private var buttonsSection: some View {
        sectionContainer("Buttons") {
            VStack(alignment: .leading, spacing: UNSpacing.xl) {
                Text("Primary")
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textSecondary)

                HStack(spacing: UNSpacing.md) {
                    Button("Large") {}
                        .unPrimaryButton(.large)
                    Button("Medium") {}
                        .unPrimaryButton(.medium)
                    Button("Small") {}
                        .unPrimaryButton(.small)
                }

                Button("Full Width Primary") {}
                    .unPrimaryButton(.large, fullWidth: true)

                Text("Secondary")
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textSecondary)

                HStack(spacing: UNSpacing.md) {
                    Button("Large") {}
                        .unSecondaryButton(.large)
                    Button("Medium") {}
                        .unSecondaryButton(.medium)
                    Button("Small") {}
                        .unSecondaryButton(.small)
                }

                Text("Ghost")
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textSecondary)

                HStack(spacing: UNSpacing.md) {
                    Button("Ghost L") {}
                        .unGhostButton(.large)
                    Button("Ghost M") {}
                        .unGhostButton(.medium)
                    Button("Ghost S") {}
                        .unGhostButton(.small)
                }

                Text("Danger")
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textSecondary)

                Button("Delete Account") {}
                    .unDangerButton(.medium, fullWidth: true)

                Text("Disabled")
                    .font(UNFont.captionLarge(.semibold))
                    .foregroundStyle(UNColor.textSecondary)

                Button("Disabled") {}
                    .unPrimaryButton(.medium, fullWidth: true)
                    .disabled(true)
            }
        }
    }

    // MARK: - Badges

    private var badgesSection: some View {
        sectionContainer("Badges") {
            HStack(spacing: UNSpacing.sm) {
                UNBadge(text: "NEW", style: .brand)
                UNBadge(text: "HOT", style: .coral)
                UNBadge(text: "인증됨", style: .mint)
                UNBadge(text: "업데이트", style: .amber)
                UNBadge(text: "추천", style: .violet)
                UNBadge(text: "일반", style: .subtle)
            }
        }
    }

    // MARK: - Tags

    private var tagsSection: some View {
        sectionContainer("Tags") {
            let tags = ["축제", "스터디", "학식", "거래", "소통"]
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UNSpacing.sm) {
                    ForEach(tags, id: \.self) { tag in
                        UNTag(text: "#\(tag)", isSelected: tag == selectedTag) {
                            selectedTag = tag
                        }
                    }
                }
            }
        }
    }

    // MARK: - TextField

    private var textFieldSection: some View {
        sectionContainer("Text Field") {
            VStack(spacing: UNSpacing.md) {
                UNTextField(placeholder: "미니앱 검색", text: $sampleText, icon: "magnifyingglass")
                UNTextField(placeholder: "이메일 입력", text: $sampleText, icon: "envelope")
                UNTextField(placeholder: "아이콘 없는 필드", text: $sampleText)
            }
        }
    }

    // MARK: - Chips

    private var chipsSection: some View {
        sectionContainer("Chips") {
            HStack(spacing: UNSpacing.sm) {
                UNChip(icon: "star.fill", label: "4.7", color: UNColor.warning)
                UNChip(icon: "person.2.fill", label: "342명", color: UNColor.interactive)
                UNChip(icon: "checkmark.seal.fill", label: "인증됨", color: UNColor.success)
                UNChip(icon: "exclamationmark.triangle.fill", label: "신고", color: UNColor.error)
            }
        }
    }

    // MARK: - Card

    private var cardSection: some View {
        sectionContainer("Cards") {
            VStack(spacing: UNSpacing.lg) {
                UNCard(shadow: .subtle) {
                    HStack(spacing: UNSpacing.md) {
                        AppIconView(emoji: "🎪", colorHex: "FF6060", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shadow: subtle")
                                .font(UNFont.bodyMedium(.semibold))
                            Text("가벼운 그림자")
                                .font(UNFont.captionLarge())
                                .foregroundStyle(UNColor.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(UNSpacing.lg)
                }

                UNCard(shadow: .card) {
                    HStack(spacing: UNSpacing.md) {
                        AppIconView(emoji: "📚", colorHex: "E83A33", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shadow: card")
                                .font(UNFont.bodyMedium(.semibold))
                            Text("카드 기본 그림자")
                                .font(UNFont.captionLarge())
                                .foregroundStyle(UNColor.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(UNSpacing.lg)
                }

                UNCard(shadow: .elevated) {
                    HStack(spacing: UNSpacing.md) {
                        AppIconView(emoji: "🚀", colorHex: "8B5CF6", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shadow: elevated")
                                .font(UNFont.bodyMedium(.semibold))
                            Text("강한 그림자 (모달, 팝업)")
                                .font(UNFont.captionLarge())
                                .foregroundStyle(UNColor.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(UNSpacing.lg)
                }

                UNCard(shadow: .strong) {
                    HStack(spacing: UNSpacing.md) {
                        AppIconView(emoji: "💪", colorHex: "262725", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shadow: strong")
                                .font(UNFont.bodyMedium(.semibold))
                            Text("플로팅 버튼, 바텀 시트")
                                .font(UNFont.captionLarge())
                                .foregroundStyle(UNColor.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(UNSpacing.lg)
                }
            }
        }
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        sectionContainer("Spacing") {
            VStack(alignment: .leading, spacing: UNSpacing.sm) {
                spacingRow("xs", UNSpacing.xs)
                spacingRow("sm", UNSpacing.sm)
                spacingRow("md", UNSpacing.md)
                spacingRow("lg", UNSpacing.lg)
                spacingRow("xl", UNSpacing.xl)
                spacingRow("xxl", UNSpacing.xxl)
                spacingRow("xxxl", UNSpacing.xxxl)
                spacingRow("xxxxl", UNSpacing.xxxxl)
                spacingRow("jumbo", UNSpacing.jumbo)
                spacingRow("mega", UNSpacing.mega)
            }
        }
    }

    // MARK: - Radius

    private var radiusSection: some View {
        sectionContainer("Radius") {
            HStack(spacing: UNSpacing.md) {
                radiusSwatch("sm", UNRadius.sm)
                radiusSwatch("md", UNRadius.md)
                radiusSwatch("lg", UNRadius.lg)
                radiusSwatch("xl", UNRadius.xl)
                radiusSwatch("full", UNRadius.full)
            }
        }
    }

    // MARK: - Shadow

    private var shadowSection: some View {
        sectionContainer("Shadows") {
            HStack(spacing: UNSpacing.xl) {
                shadowSwatch("subtle", .subtle)
                shadowSwatch("card", .card)
                shadowSwatch("elevated", .elevated)
                shadowSwatch("strong", .strong)
            }
            .padding(.vertical, UNSpacing.lg)
        }
    }

    // ===================================================
    // MARK: - Helper Views
    // ===================================================

    private func sectionContainer<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            Text(title)
                .font(UNFont.headingLarge())
                .foregroundStyle(UNColor.textPrimary)
            content()
        }
    }

    private func colorGroup(_ label: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: UNSpacing.sm) {
            Text(label)
                .font(UNFont.captionLarge(.semibold))
                .foregroundStyle(UNColor.textSecondary)
            HStack(spacing: UNSpacing.sm) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: UNRadius.sm, style: .continuous)
                            .fill(color)
                            .frame(width: 52, height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: UNRadius.sm, style: .continuous)
                                    .stroke(UNColor.border, lineWidth: 0.5)
                            )
                        Text(name)
                            .font(UNFont.captionSmall())
                            .foregroundStyle(UNColor.textTertiary)
                    }
                }
            }
        }
    }

    private func gradientSwatch(_ colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: UNRadius.sm, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 52, height: 40)
    }

    private func typoRow(_ label: String, _ font: Font) -> some View {
        HStack {
            Text(label)
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textTertiary)
                .frame(width: 90, alignment: .leading)
            Text("Union 유니온 123")
                .font(font)
                .foregroundStyle(UNColor.textPrimary)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: UNSpacing.md) {
            Text("\(name) (\(Int(value)))")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textTertiary)
                .frame(width: 80, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(UNColor.interactive)
                .frame(width: value * 3, height: 16)
        }
    }

    private func radiusSwatch(_ name: String, _ radius: CGFloat) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(UNColor.interactive)
                .frame(width: 48, height: 48)
            Text(name)
                .font(UNFont.captionSmall())
                .foregroundStyle(UNColor.textTertiary)
        }
    }

    private func shadowSwatch(_ name: String, _ style: UNShadow.Style) -> some View {
        VStack(spacing: UNSpacing.sm) {
            RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                .fill(UNColor.surface)
                .frame(width: 80, height: 60)
                .unShadow(style)
            Text(name)
                .font(UNFont.captionSmall())
                .foregroundStyle(UNColor.textTertiary)
        }
    }
}

// MARK: - Preview

#Preview {
    DesignSystemPreviewView()
}

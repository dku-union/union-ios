import SwiftUI

// MARK: - Badge

struct UNBadge: View {
    let text: String
    let style: Style

    enum Style {
        case brand, coral, mint, amber, violet, subtle

        var foreground: Color {
            switch self {
            case .brand: UNColor.interactive
            case .coral: UNColor.error
            case .mint: UNColor.success
            case .amber: UNColor.warning
            case .violet: UNColor.violet
            case .subtle: UNColor.textSecondary
            }
        }

        var background: Color {
            switch self {
            case .brand: UNColor.bgAccent
            case .coral: UNColor.red100
            case .mint: Color(hex: "EDFBF5")
            case .amber: Color(hex: "FFF8EB")
            case .violet: UNColor.violetLight
            case .subtle: UNColor.bgPressed
            }
        }
    }

    var body: some View {
        Text(text)
            .font(UNFont.captionSmall(.semibold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, UNSpacing.sm)
            .padding(.vertical, UNSpacing.xs)
            .background(style.background)
            .clipShape(Capsule())
    }
}

// MARK: - Tag (tappable)

struct UNTag: View {
    let text: String
    let isSelected: Bool
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            Text(text)
                .font(UNFont.labelSmall())
                .foregroundStyle(isSelected ? UNColor.textInverse : UNColor.interactive)
                .padding(.horizontal, UNSpacing.lg)
                .padding(.vertical, UNSpacing.sm)
                .background(
                    Capsule().fill(isSelected ? UNColor.interactive : UNColor.bgAccent)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text Field

struct UNTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?

    var body: some View {
        HStack(spacing: UNSpacing.md) {
            if let icon {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(UNColor.textTertiary)
            }
            TextField(placeholder, text: $text)
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textPrimary)
        }
        .padding(.horizontal, UNSpacing.lg)
        .frame(height: 48)
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                .stroke(UNColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Divider

struct UNDivider: View {
    var body: some View {
        Rectangle()
            .fill(UNColor.divider)
            .frame(height: 1)
    }
}

// MARK: - Chip (icon + label)

struct UNChip: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: UNSpacing.xs) {
            Image(systemName: icon)
                .font(UNFont.captionSmall())
            Text(label)
                .font(UNFont.captionLarge(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, UNSpacing.md)
        .padding(.vertical, UNSpacing.sm)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Card Container

struct UNCard<Content: View>: View {
    let shadow: UNShadow.Style
    @ViewBuilder let content: () -> Content

    init(shadow: UNShadow.Style = .card, @ViewBuilder content: @escaping () -> Content) {
        self.shadow = shadow
        self.content = content
    }

    var body: some View {
        content()
            .background(UNColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
            .unShadow(shadow)
    }
}

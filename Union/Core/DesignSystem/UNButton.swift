import SwiftUI

// MARK: - Button Style

enum UNButtonSize {
    case large, medium, small

    var height: CGFloat {
        switch self {
        case .large: 52
        case .medium: 44
        case .small: 34
        }
    }

    var font: Font {
        switch self {
        case .large: UNFont.labelLarge()
        case .medium: UNFont.labelMedium()
        case .small: UNFont.labelSmall()
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .large: UNSpacing.xxl
        case .medium: UNSpacing.xl
        case .small: UNSpacing.lg
        }
    }

    var radius: CGFloat {
        switch self {
        case .large: UNRadius.md
        case .medium: UNRadius.sm
        case .small: UNRadius.sm
        }
    }
}

// MARK: - Primary Button

struct UNPrimaryButtonStyle: ButtonStyle {
    let size: UNButtonSize
    let isFullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(UNColor.textInverse)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .fill(isEnabled ? UNColor.interactive : UNColor.textTertiary)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button (Outlined)

struct UNSecondaryButtonStyle: ButtonStyle {
    let size: UNButtonSize
    let isFullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(isEnabled ? UNColor.interactive : UNColor.textTertiary)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .stroke(isEnabled ? UNColor.interactive : UNColor.textTertiary, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button (Text only)

struct UNGhostButtonStyle: ButtonStyle {
    let size: UNButtonSize
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(isEnabled ? UNColor.textSecondary : UNColor.textTertiary)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .fill(configuration.isPressed ? UNColor.bgPressed : Color.clear)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Danger Button

struct UNDangerButtonStyle: ButtonStyle {
    let size: UNButtonSize
    let isFullWidth: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(UNColor.textInverse)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: size.height)
            .padding(.horizontal, size.horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                    .fill(UNColor.error)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions

extension View {
    func unPrimaryButton(_ size: UNButtonSize = .medium, fullWidth: Bool = false) -> some View {
        self.buttonStyle(UNPrimaryButtonStyle(size: size, isFullWidth: fullWidth))
    }

    func unSecondaryButton(_ size: UNButtonSize = .medium, fullWidth: Bool = false) -> some View {
        self.buttonStyle(UNSecondaryButtonStyle(size: size, isFullWidth: fullWidth))
    }

    func unGhostButton(_ size: UNButtonSize = .medium) -> some View {
        self.buttonStyle(UNGhostButtonStyle(size: size))
    }

    func unDangerButton(_ size: UNButtonSize = .medium, fullWidth: Bool = false) -> some View {
        self.buttonStyle(UNDangerButtonStyle(size: size, isFullWidth: fullWidth))
    }
}

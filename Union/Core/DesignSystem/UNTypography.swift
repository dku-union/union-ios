import SwiftUI

// MARK: - Typography Tokens

enum UNFont {

    // MARK: - Display

    static func displayLarge(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 32, weight: weight, design: .rounded)
    }

    static func displayMedium(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 28, weight: weight, design: .rounded)
    }

    static func displaySmall(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 24, weight: weight, design: .rounded)
    }

    // MARK: - Heading

    static func headingLarge(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 20, weight: weight)
    }

    static func headingMedium(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 18, weight: weight)
    }

    static func headingSmall(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 16, weight: weight)
    }

    // MARK: - Body

    static func bodyLarge(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 16, weight: weight)
    }

    static func bodyMedium(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 14, weight: weight)
    }

    static func bodySmall(_ weight: Font.Weight = .regular) -> Font {
        .system(size: 13, weight: weight)
    }

    // MARK: - Caption

    static func captionLarge(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 12, weight: weight)
    }

    static func captionSmall(_ weight: Font.Weight = .medium) -> Font {
        .system(size: 11, weight: weight)
    }

    // MARK: - Label (Buttons, Tags)

    static func labelLarge(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 16, weight: weight)
    }

    static func labelMedium(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 14, weight: weight)
    }

    static func labelSmall(_ weight: Font.Weight = .semibold) -> Font {
        .system(size: 12, weight: weight)
    }
}

// MARK: - Typography View Modifier

struct UNTextStyle: ViewModifier {
    let font: Font
    let color: Color
    let lineSpacing: CGFloat

    init(font: Font, color: Color = UNColor.textPrimary, lineSpacing: CGFloat = 2) {
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
    }
}

extension View {
    func unTextStyle(_ font: Font, color: Color = UNColor.textPrimary) -> some View {
        modifier(UNTextStyle(font: font, color: color))
    }
}

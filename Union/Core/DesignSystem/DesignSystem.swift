import SwiftUI

// MARK: - Color Tokens

enum UNColor {
    // Brand
    static let brand = Color(hex: "3B5BFF")
    static let brandDark = Color(hex: "2A45D9")
    static let brandLight = Color(hex: "EEF1FF")

    // Semantic
    static let coral = Color(hex: "FF6060")
    static let coralLight = Color(hex: "FFF0F0")
    static let mint = Color(hex: "22C993")
    static let mintLight = Color(hex: "EDFBF5")
    static let amber = Color(hex: "FFB547")
    static let amberLight = Color(hex: "FFF8EB")
    static let violet = Color(hex: "8B5CF6")
    static let violetLight = Color(hex: "F3EDFF")

    // Surface
    static let bgPrimary = Color(hex: "F4F5F9")
    static let bgSecondary = Color.white
    static let surface = Color.white
    static let surfacePressed = Color(hex: "F0F1F5")

    // Text
    static let textPrimary = Color(hex: "151924")
    static let textSecondary = Color(hex: "6E7591")
    static let textTertiary = Color(hex: "B0B7CE")
    static let textInverse = Color.white

    // Border & Divider
    static let border = Color(hex: "E8EBF2")
    static let divider = Color(hex: "F0F2F7")

    // Gradients
    static let gradientBluePurple = [Color(hex: "3B5BFF"), Color(hex: "8B5CF6")]
    static let gradientCoralOrange = [Color(hex: "FF6060"), Color(hex: "FF9A5C")]
    static let gradientMintTeal = [Color(hex: "22C993"), Color(hex: "36D1C4")]
    static let gradientAmberYellow = [Color(hex: "FFB547"), Color(hex: "FFD97A")]
    static let gradientDeepBlue = [Color(hex: "1B2CC1"), Color(hex: "3B5BFF")]
}

// MARK: - Spacing Tokens

enum UNSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let xxxxl: CGFloat = 40
}

// MARK: - Radius Tokens

enum UNRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let full: CGFloat = 100
}

// MARK: - Shadow

struct UNShadow: ViewModifier {
    enum Style {
        case card, elevated, subtle
    }

    let style: Style

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content.shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        case .elevated:
            content.shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 8)
        case .subtle:
            content.shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}

extension View {
    func unShadow(_ style: UNShadow.Style = .card) -> some View {
        modifier(UNShadow(style: style))
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

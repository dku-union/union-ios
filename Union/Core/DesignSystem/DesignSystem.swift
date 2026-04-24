import SwiftUI

// MARK: - Color Tokens

enum UNColor {

    // MARK: - Ice Scale (Background family)

    static let ice50  = Color(hex: "F7F9FD")
    static let ice100 = Color(hex: "EDF2FA")  // Base Background
    static let ice200 = Color(hex: "DCE4F2")
    static let ice300 = Color(hex: "C5D1E8")

    // MARK: - Charcoal Scale (Dark family)

    static let charcoal900 = Color(hex: "262725")  // Base Dark
    static let charcoal800 = Color(hex: "363836")
    static let charcoal700 = Color(hex: "4A4C4A")
    static let charcoal600 = Color(hex: "6B6D6B")
    static let charcoal500 = Color(hex: "8E908E")
    static let charcoal400 = Color(hex: "B0B2B0")

    // MARK: - Red Scale (Accent family)

    static let red600 = Color(hex: "C42E29")
    static let red500 = Color(hex: "E83A33")  // Base Accent
    static let red400 = Color(hex: "EF6560")
    static let red300 = Color(hex: "F4908C")
    static let red200 = Color(hex: "FACCCB")
    static let red100 = Color(hex: "FDE8E7")

    // MARK: - Background

    static let bgPrimary   = ice100
    static let bgSecondary = Color.white
    static let bgDark      = charcoal900
    static let bgAccent    = red100
    static let bgPressed   = ice200

    // MARK: - Text

    static let textPrimary   = charcoal900
    static let textSecondary = charcoal600
    static let textTertiary  = charcoal500
    static let textInverse   = Color.white
    static let textOnDark    = ice100
    static let textAccent    = red500

    // MARK: - Interactive

    static let interactive      = red500
    static let interactiveHover = red600

    // MARK: - Border & Divider

    static let border       = ice200
    static let borderStrong = charcoal400
    static let divider      = ice200

    // MARK: - Status

    static let success = Color(hex: "2D8A4E")
    static let warning = Color(hex: "D4860A")
    static let error   = Color(hex: "DC2626")

    // MARK: - Gradients

    static let gradientAccent = LinearGradient(
        colors: [red500, red400],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientRedAccent = [red500, red400]
    static let gradientDeepRed   = [red600, red500]
    static let gradientCoralOrange = [Color(hex: "FF6060"), Color(hex: "FF9A5C")]
    static let gradientMintTeal    = [Color(hex: "22C993"), Color(hex: "36D1C4")]
    static let gradientAmberYellow = [Color(hex: "FFB547"), Color(hex: "FFD97A")]

    // MARK: - Decorative (non-brand)

    static let violet      = Color(hex: "8B5CF6")
    static let violetLight = Color(hex: "F3EDFF")

    // MARK: - Surface Compat

    static let surface = Color.white

    // MARK: - Deprecated (마이그레이션 후 제거)

    @available(*, deprecated, renamed: "interactive")
    static let brand = red500
    @available(*, deprecated, renamed: "interactiveHover")
    static let brandDark = red600
    @available(*, deprecated, renamed: "bgAccent")
    static let brandLight = red100

    @available(*, deprecated, renamed: "error")
    static let coral = Color(hex: "FF6060")
    @available(*, deprecated, renamed: "bgAccent")
    static let coralLight = Color(hex: "FFF0F0")
    @available(*, deprecated, renamed: "success")
    static let mint = Color(hex: "22C993")
    @available(*, deprecated, renamed: "success")
    static let mintLight = Color(hex: "EDFBF5")
    @available(*, deprecated, renamed: "warning")
    static let amber = Color(hex: "FFB547")
    @available(*, deprecated, renamed: "warning")
    static let amberLight = Color(hex: "FFF8EB")

    @available(*, deprecated, renamed: "bgPressed")
    static let surfacePressed = ice200

    @available(*, deprecated, renamed: "gradientRedAccent")
    static let gradientBluePurple = gradientRedAccent
    @available(*, deprecated, renamed: "gradientDeepRed")
    static let gradientDeepBlue = gradientDeepRed
}

// MARK: - Spacing Tokens

enum UNSpacing {
    static let none:   CGFloat = 0
    static let xs:     CGFloat = 4
    static let sm:     CGFloat = 8
    static let md:     CGFloat = 12
    static let lg:     CGFloat = 16
    static let xl:     CGFloat = 20
    static let xxl:    CGFloat = 24
    static let xxxl:   CGFloat = 32
    static let xxxxl:  CGFloat = 40
    static let jumbo:  CGFloat = 48
    static let mega:   CGFloat = 64
}

// MARK: - Radius Tokens

enum UNRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let full: CGFloat = 100
}

// MARK: - Shadow

struct UNShadow: ViewModifier {
    enum Style {
        case card, elevated, subtle, strong
    }

    let style: Style

    func body(content: Content) -> some View {
        let base = Color(hex: "262725")
        switch style {
        case .card:
            content.shadow(color: base.opacity(0.06), radius: 12, x: 0, y: 4)
        case .elevated:
            content.shadow(color: base.opacity(0.10), radius: 20, x: 0, y: 8)
        case .subtle:
            content.shadow(color: base.opacity(0.04), radius: 6, x: 0, y: 2)
        case .strong:
            content.shadow(color: base.opacity(0.12), radius: 32, x: 0, y: 8)
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

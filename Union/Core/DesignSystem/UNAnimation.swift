import SwiftUI

// MARK: - Entry Animations

struct FadeUpModifier: ViewModifier {
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 16))
            .animation(
                reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.5),
                value: isVisible
            )
    }
}

struct ScaleInModifier: ViewModifier {
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(reduceMotion ? 1 : (isVisible ? 1 : 0.96))
            .animation(
                reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.3),
                value: isVisible
            )
    }
}

struct SlideInModifier: ViewModifier {
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: reduceMotion ? 0 : (isVisible ? 0 : -12))
            .animation(
                reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.4),
                value: isVisible
            )
    }
}

// MARK: - Stagger Animation

struct StaggerModifier: ViewModifier {
    let isVisible: Bool
    let index: Int
    let maxItems: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let clampedIndex = min(index, maxItems)
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : 12))
            .animation(
                reduceMotion
                    ? .linear(duration: 0)
                    : .easeOut(duration: 0.4).delay(Double(clampedIndex) * 0.05),
                value: isVisible
            )
    }
}

// MARK: - Press Effect

struct PressEffectModifier: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPressed ? 0.85 : 1.0)
            .animation(
                reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.15),
                value: isPressed
            )
    }
}

// MARK: - View Extensions

extension View {
    func fadeUp(isVisible: Bool) -> some View {
        modifier(FadeUpModifier(isVisible: isVisible))
    }

    func scaleIn(isVisible: Bool) -> some View {
        modifier(ScaleInModifier(isVisible: isVisible))
    }

    func slideIn(isVisible: Bool) -> some View {
        modifier(SlideInModifier(isVisible: isVisible))
    }

    func stagger(isVisible: Bool, index: Int, maxItems: Int = 8) -> some View {
        modifier(StaggerModifier(isVisible: isVisible, index: index, maxItems: maxItems))
    }

    func pressEffect(isPressed: Bool) -> some View {
        modifier(PressEffectModifier(isPressed: isPressed))
    }
}

// MARK: - Transition Presets

extension AnyTransition {
    static var fadeUp: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity
        )
    }

    static var scaleIn: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96))
    }
}

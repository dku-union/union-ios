import SwiftUI

// MARK: - Form Text Field (with label, error, focus state)

struct UNFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var icon: String?
    var error: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .never

    @FocusState private var isFocused: Bool

    private var borderColor: Color {
        if error != nil { return UNColor.coral }
        if isFocused { return UNColor.brand }
        return UNColor.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UNSpacing.sm) {
            Text(label)
                .font(UNFont.captionLarge(.semibold))
                .foregroundStyle(UNColor.textSecondary)

            HStack(spacing: UNSpacing.md) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(isFocused ? UNColor.brand : UNColor.textTertiary)
                }
                TextField(placeholder, text: $text)
                    .font(UNFont.bodyLarge())
                    .foregroundStyle(UNColor.textPrimary)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .focused($isFocused)

                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(UNColor.textTertiary)
                    }
                }
            }
            .padding(.horizontal, UNSpacing.lg)
            .frame(height: 52)
            .background(UNColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused || error != nil ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: error)

            if let error {
                HStack(spacing: UNSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(UNFont.captionSmall())
                    Text(error)
                        .font(UNFont.captionSmall())
                }
                .foregroundStyle(UNColor.coral)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Secure Form Field (password)

struct UNSecureFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var error: String?

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    private var borderColor: Color {
        if error != nil { return UNColor.coral }
        if isFocused { return UNColor.brand }
        return UNColor.border
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UNSpacing.sm) {
            Text(label)
                .font(UNFont.captionLarge(.semibold))
                .foregroundStyle(UNColor.textSecondary)

            HStack(spacing: UNSpacing.md) {
                Image(systemName: "lock")
                    .font(.body)
                    .foregroundStyle(isFocused ? UNColor.brand : UNColor.textTertiary)

                Group {
                    if isRevealed {
                        TextField(placeholder, text: $text)
                    } else {
                        SecureField(placeholder, text: $text)
                    }
                }
                .font(UNFont.bodyLarge())
                .foregroundStyle(UNColor.textPrimary)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .focused($isFocused)

                Button { isRevealed.toggle() } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.body)
                        .foregroundStyle(UNColor.textTertiary)
                }
            }
            .padding(.horizontal, UNSpacing.lg)
            .frame(height: 52)
            .background(UNColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused || error != nil ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)

            if let error {
                HStack(spacing: UNSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(UNFont.captionSmall())
                    Text(error)
                        .font(UNFont.captionSmall())
                }
                .foregroundStyle(UNColor.coral)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Verification Code Field (6-digit)

struct UNCodeField: View {
    @Binding var code: String
    let length: Int
    var error: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: UNSpacing.lg) {
            ZStack {
                // Hidden text field to capture keyboard input
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isFocused)
                    .opacity(0)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.prefix(length).filter(\.isNumber))
                    }

                // Visual digit boxes
                HStack(spacing: UNSpacing.md) {
                    ForEach(0..<length, id: \.self) { index in
                        let char = index < code.count
                            ? String(code[code.index(code.startIndex, offsetBy: index)])
                            : ""
                        let isActive = index == code.count && isFocused

                        Text(char)
                            .font(UNFont.displaySmall(.bold))
                            .foregroundStyle(UNColor.textPrimary)
                            .frame(width: 48, height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                                    .fill(char.isEmpty ? UNColor.bgPrimary : UNColor.brandLight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                                    .stroke(
                                        isActive ? UNColor.brand :
                                            error != nil ? UNColor.coral :
                                            char.isEmpty ? UNColor.border : UNColor.brand.opacity(0.4),
                                        lineWidth: isActive ? 2 : 1
                                    )
                            )
                            .scaleEffect(isActive ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            }

            if let error {
                HStack(spacing: UNSpacing.xs) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(UNFont.captionSmall())
                    Text(error)
                        .font(UNFont.captionSmall())
                }
                .foregroundStyle(UNColor.coral)
            }
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Step Indicator

struct UNStepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: UNSpacing.sm) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? UNColor.brand : UNColor.border)
                    .frame(height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
        }
    }
}

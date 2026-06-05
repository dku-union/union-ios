import SwiftUI

// MARK: - MiniAppConsentModal

/// 미니앱 최초 접속 시 요청 권한에 동의를 받는 커스텀 모달(앱-동의 계층).
///
/// 네이티브 얼럿이 아닌 DESIGN.md 기반 디자인 시스템 컴포넌트로 구성한다.
/// 스코프별 토글을 제공하며(기본 허용/opt-out), "허용"은 토글 상태대로 저장하고
/// "나중에 할게요"·바깥 탭은 저장하지 않고 닫는다(다음 접속 시 재프롬프트).
struct MiniAppConsentModal: View {
    let appName: String
    let scopes: [PermissionScope]
    /// "허용" — 토글 상태대로 결정 저장.
    let onAllow: ([PermissionScope: Bool]) -> Void
    /// "나중에 할게요" / 바깥 탭 — 저장하지 않고 진행(다음 접속 시 재프롬프트).
    let onPostpone: () -> Void

    @State private var granted: [PermissionScope: Bool]
    @State private var isVisible = false

    init(
        appName: String,
        scopes: [PermissionScope],
        onAllow: @escaping ([PermissionScope: Bool]) -> Void,
        onPostpone: @escaping () -> Void
    ) {
        self.appName = appName
        self.scopes = scopes
        self.onAllow = onAllow
        self.onPostpone = onPostpone
        // 기본값: 요청된 스코프 모두 허용(opt-out). 사용자가 원치 않는 항목만 끈다.
        _granted = State(initialValue: Dictionary(uniqueKeysWithValues: scopes.map { ($0, true) }))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onPostpone() }
                .accessibilityHidden(true)

            card
                .scaleIn(isVisible: isVisible)
                .padding(.horizontal, UNSpacing.xxl)
        }
        .onAppear {
            isVisible = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: UNSpacing.xl) {
            header
            scopeList
            buttons
        }
        .padding(UNSpacing.xxl)
        .background(UNColor.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.xl, style: .continuous))
        .unShadow(.elevated)
        .frame(maxWidth: 360)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: UNSpacing.xs) {
            Text("권한 요청")
                .font(UNFont.captionLarge(.semibold))
                .foregroundStyle(UNColor.textAccent)
            Text("‘\(appName)’이 아래 권한을 요청해요")
                .font(UNFont.headingMedium())
                .foregroundStyle(UNColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("필요한 권한만 켜고 허용할 수 있어요. 거부해도 앱은 이용할 수 있어요.")
                .font(UNFont.bodySmall())
                .foregroundStyle(UNColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scopeList: some View {
        VStack(spacing: UNSpacing.md) {
            ForEach(scopes, id: \.self) { scope in
                scopeRow(scope)
            }
        }
    }

    private func scopeRow(_ scope: PermissionScope) -> some View {
        HStack(spacing: UNSpacing.md) {
            Image(systemName: scope.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(UNColor.interactive)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(scope.title)
                    .font(UNFont.bodyMedium(.semibold))
                    .foregroundStyle(UNColor.textPrimary)
                Text(scope.permissionDescription)
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: UNSpacing.sm)

            Toggle("", isOn: Binding(
                get: { granted[scope] ?? true },
                set: { granted[scope] = $0 }
            ))
            .labelsHidden()
            .tint(UNColor.interactive)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scope.title) 권한")
        .accessibilityValue((granted[scope] ?? true) ? "허용" : "거부")
        .accessibilityHint(scope.permissionDescription)
    }

    private var buttons: some View {
        VStack(spacing: UNSpacing.sm) {
            Button {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onAllow(granted)
            } label: {
                Text("허용").frame(maxWidth: .infinity)
            }
            .unPrimaryButton(.large, fullWidth: true)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onPostpone()
            } label: {
                Text("나중에 할게요").frame(maxWidth: .infinity)
            }
            .unGhostButton(.large)
        }
    }
}

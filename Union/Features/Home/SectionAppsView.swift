import SwiftUI

// MARK: - Section "더보기" List

/// 홈 섹션의 "더보기" 화면 — 해당 섹션 미니앱 전체를 세로 리스트로 보여준다.
/// Home 의 NavigationStack 안에서 push 되며, 각 카드 내부의 `NavigationLink` 가
/// `MiniAppWebView` 로 미니앱을 실행한다(홈 카드와 동일 동작).
struct SectionAppsView: View {
    let title: String
    let apps: [MiniApp]
    var onTap: (MiniApp) -> Void = { _ in }

    var body: some View {
        ScrollView {
            if apps.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: UNSpacing.md) {
                    ForEach(apps) { app in
                        MiniAppCardHorizontal(app: app, onTap: onTap)
                    }
                }
                .padding(UNSpacing.xl)
            }
        }
        .background(UNColor.bgPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 36))
                .foregroundStyle(UNColor.textTertiary)
            Text("표시할 미니앱이 없습니다")
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

import SwiftUI
import ComposableArchitecture

@main
struct UnionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let appStore = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(store: appStore)
                .onOpenURL { url in
                    appStore.send(.openURL(url))
                }
                // 앱은 밝은 색(ice/charcoal)만 하드코딩 — 다크모드 미대응(DESIGN.md "향후").
                // 라이트 고정으로 시스템 요소(네비 타이틀 등)가 다크모드에서 흰색으로 뒤집히는 문제 차단.
                .preferredColorScheme(.light)
        }
    }
}

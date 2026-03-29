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
        }
    }
}

import Foundation
@preconcurrency import WebKit

// MARK: - Session Cleaner

/// 로그아웃 시 사용자에 묶인 영속 데이터를 일괄 삭제한다.
///
/// `KeychainStore.clearAll()` 은 토큰만 비우므로, 미니앱 WebView 가
/// 남긴 쿠키/로컬스토리지/IndexedDB 등은 별도로 정리해야 한다.
enum SessionCleaner {

    /// 미니앱 WebView 들이 사용한 모든 영속 데이터(쿠키·LocalStorage·
    /// SessionStorage·IndexedDB·캐시 등)를 삭제한다.
    ///
    /// `WKWebsiteDataStore.default()` 는 앱 내 모든 `WKWebView` 가 공유하는
    /// 기본 저장소이며, 미니앱이 자체적으로 발급/저장한 세션 토큰이 여기에
    /// 남아 다음 로그인 사용자에게 노출될 수 있다.
    @MainActor
    static func purgeWebViewData() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        await WKWebsiteDataStore.default().removeData(
            ofTypes: types,
            modifiedSince: .distantPast
        )
    }
}

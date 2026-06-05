import ComposableArchitecture
import Foundation

// MARK: - App Persistence Keys
//
// @Shared 에서 사용하는 영속성 키를 이 파일에서 중앙 관리합니다.
// 새로운 로컬 데이터가 필요할 때 아래에 extension 을 추가하세요.
//
// 사용 예시:
//   @Shared(.launchedAppIds) var launchedAppIds: [Int] = []

// MARK: - 실행 기록

extension SharedKey where Self == FileStorageKey<[Int]> {
    /// 미니앱 실행 기록 (최근 실행 순, appId 기준).
    /// 앱 실행 시 자동 저장되며 최대 100개까지 유지됩니다.
    static var launchedAppIds: Self {
        .fileStorage(
            URL.documentsDirectory.appendingPathComponent("union.launchedApps.json")
        )
    }
}

// MARK: - 미니앱 권한 결정

extension SharedKey where Self == FileStorageKey<[String: [String: Bool]]> {
    /// 미니앱별 권한 결정 로컬 캐시.
    /// 외부 키 = `String(miniApp.id)`, 내부 = scope rawValue → granted.
    /// 오프라인/세션 간 권한 집행의 진실원이며, 백엔드는 동기화 소스다.
    static var localPermissionDecisions: Self {
        .fileStorage(
            URL.documentsDirectory.appendingPathComponent("union.miniAppPermissions.json")
        )
    }
}

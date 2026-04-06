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

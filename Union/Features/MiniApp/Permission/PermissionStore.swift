import ComposableArchitecture
import Foundation

// MARK: - PermissionStore

/// 미니앱별 권한 결정의 동기 접근 게이트.
///
/// 로컬 `@Shared` 캐시(`union.miniAppPermissions.json`)를 진실원으로 삼아, `BridgeHandler` 가
/// 브릿지 호출 직전 **동기적으로** 허용 여부를 조회한다. 백엔드는 동기화 소스이며,
/// 동의 모달 / 권한 관리 화면이 `setDecisions` 로 캐시를 갱신한다.
///
/// 2계층 모델에서 이 store 는 **앱-동의 계층**만 담당한다. 실제 OS 권한 다이얼로그(위치/카메라/알림)는
/// 동의가 허용된 뒤 해당 기능을 처음 사용할 때 각 브릿지 모듈이 별도로 띄운다.
@MainActor
final class PermissionStore {
    static let shared = PermissionStore()

    @Shared(.localPermissionDecisions) private var persisted: [String: [String: Bool]] = [:]

    private init() {}

    /// 동기 집행 판정.
    /// - 해당 앱의 결정이 캐시에 **없으면** fail-open(`true`) — 권한 시스템이 확립되지 않은 앱이나
    ///   오프라인 최초 실행에서 기존 동작을 깨지 않기 위함.
    /// - 캐시에 있으면 해당 스코프의 결정을 따르며, 결정이 없는 스코프(미선언 등)는 거부(`false`).
    func isAllowed(appId: Int, scope: PermissionScope) -> Bool {
        guard let appMap = persisted[String(appId)] else { return true }
        return appMap[scope.rawValue] ?? false
    }

    /// 해당 앱의 결정이 로컬 캐시에 존재하는지.
    /// = 동의(모달 "허용")를 했거나, 타 기기/이전 결정을 하이드레이트한 적이 있음.
    /// 동의 모달을 다시 띄울지(재프롬프트 skip) 판정하는 fast-path 로 쓰인다.
    func isKnown(appId: Int) -> Bool {
        persisted[String(appId)] != nil
    }

    /// 특정 앱의 모든 결정을 닫힌(scope→granted) 맵으로 반환(권한 관리 화면용).
    func decisions(appId: Int) -> [PermissionScope: Bool] {
        guard let appMap = persisted[String(appId)] else { return [:] }
        return Dictionary(uniqueKeysWithValues: appMap.compactMap { key, value in
            PermissionScope(rawValue: key).map { ($0, value) }
        })
    }

    /// 특정 스코프의 결정값(없으면 nil).
    func decision(appId: Int, scope: PermissionScope) -> Bool? {
        persisted[String(appId)]?[scope.rawValue]
    }

    /// 결정 일괄 저장(동의 모달 / 권한 관리 토글). 로컬 캐시에 영속되어 이후 세션·오프라인에서도 집행된다.
    func setDecisions(appId: Int, _ decisions: [PermissionScope: Bool]) {
        $persisted.withLock { store in
            var appMap = store[String(appId)] ?? [:]
            for (scope, granted) in decisions {
                appMap[scope.rawValue] = granted
            }
            store[String(appId)] = appMap
        }
    }

    /// 전체 권한 결정 캐시 초기화. 로그아웃 시 호출해 다음 사용자에게 권한 결정이 누수되지 않게 한다.
    func reset() {
        $persisted.withLock { $0 = [:] }
    }
}

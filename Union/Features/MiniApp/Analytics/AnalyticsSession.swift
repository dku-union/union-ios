import Foundation

// MARK: - Analytics Session

/// 미니앱 단위 Analytics 세션.
///
/// 미니앱 실행(open) 시 생성되고, 종료(close) 시 파괴된다.
/// `sequenceNumber` 는 세션 내 이벤트 순서를 보장하여 이벤트 유실 감지에 사용된다.
final class AnalyticsSession: @unchecked Sendable {

    // MARK: - Properties

    /// 미니앱 단위 세션 UUID. 미니앱 실행마다 새로 발급.
    let sessionId: String

    /// 미니앱 식별자 (e.g. "com.union.soccer")
    let appId: String

    /// 세션 시작 시각. `app_close` 이벤트의 `session_duration_ms` 계산에 사용.
    let openedAt: Date

    // 세션 내 이벤트 순서 번호 (원자적 증가)
    private var _sequenceNumber: Int = 0
    private let lock = NSLock()

    // MARK: - Init

    init(appId: String) {
        self.sessionId = UUID().uuidString
        self.appId = appId
        self.openedAt = Date()
    }

    // MARK: - Sequence Number

    /// 다음 시퀀스 번호를 반환하고 내부 카운터를 원자적으로 증가.
    func nextSequenceNumber() -> Int {
        lock.withLock {
            let current = _sequenceNumber
            _sequenceNumber += 1
            return current
        }
    }

    /// 세션이 열려있던 시간 (ms)
    var durationMs: Int {
        Int(Date().timeIntervalSince(openedAt) * 1000)
    }
}

// MARK: - Superapp Session

/// 슈퍼앱 전체 세션 관리.
/// 여러 미니앱에 걸쳐 연속된 세션을 추적한다.
/// 앱 포그라운드 복귀 시 백그라운드 체류 시간이 기준값 이상이면 새 세션으로 갱신.
final class SuperappSession {

    static let shared = SuperappSession()

    /// 슈퍼앱 세션 UUID. 앱 실행 시 생성, 장시간 백그라운드 후 갱신.
    private(set) var sessionId: String

    /// 백그라운드 진입 시각
    private var backgroundedAt: Date?

    /// 이 시간(초) 이상 백그라운드에 있었으면 새 세션 발급
    private let sessionTimeoutInterval: TimeInterval = 1800 // 30분

    private init() {
        self.sessionId = UUID().uuidString
    }

    // MARK: - Lifecycle

    func applicationDidEnterBackground() {
        backgroundedAt = Date()
    }

    func applicationWillEnterForeground() {
        guard let bg = backgroundedAt else { return }
        let bgDuration = Date().timeIntervalSince(bg)
        if bgDuration >= sessionTimeoutInterval {
            sessionId = UUID().uuidString
        }
        backgroundedAt = nil
    }
}

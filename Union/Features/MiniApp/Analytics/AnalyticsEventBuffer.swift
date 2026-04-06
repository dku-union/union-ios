import Foundation

// MARK: - Analytics Event Buffer

/// Analytics 이벤트 인메모리 버퍼 (Actor).
///
/// 이벤트를 메모리에 누적하다가 조건 충족 시 배치로 플러시한다.
///
/// ### Flush 조건 (OR)
/// - 이벤트 수 ≥ `flushThreshold` (기본 20개)
/// - 외부에서 `flush()` 명시적 호출
///
/// ### 오버플로우 처리
/// - 버퍼가 `maxSize`(100) 에 도달하면 가장 오래된 이벤트 삭제 (FIFO drop)
actor AnalyticsEventBuffer {

    // MARK: - Configuration

    private let flushThreshold: Int
    private let maxSize: Int

    // MARK: - State

    private var events: [AnalyticsEventModel] = []

    /// 자동 플러시 콜백 (임계값 도달 시 호출됨).
    /// actor 외부에서 직접 대입하면 "Actor-isolated property can not be mutated on a nonisolated
    /// actor instance" 컴파일 에러가 발생하므로, `setFlushCallback(_:)` 메서드를 통해서만 설정한다.
    private var onAutoFlush: (([AnalyticsEventModel]) async -> Void)?

    // MARK: - Init

    init(flushThreshold: Int = 20, maxSize: Int = 100) {
        self.flushThreshold = flushThreshold
        self.maxSize = maxSize
    }

    /// 자동 플러시 콜백을 등록한다.
    /// actor 격리 컨텍스트 내부에서 `onAutoFlush` 를 수정하기 위해 메서드로 노출.
    func setFlushCallback(_ callback: @escaping ([AnalyticsEventModel]) async -> Void) {
        onAutoFlush = callback
    }

    // MARK: - API

    /// 이벤트를 버퍼에 추가.
    /// 임계값 도달 시 `onAutoFlush` 콜백으로 배치를 전달하고 버퍼를 비운다.
    func append(_ event: AnalyticsEventModel) async {
        // 오버플로우 시 FIFO drop
        if events.count >= maxSize {
            events.removeFirst()
        }

        events.append(event)

        if events.count >= flushThreshold {
            let batch = drain()
            await onAutoFlush?(batch)
        }
    }

    /// 현재 버퍼의 모든 이벤트를 반환하고 버퍼를 비운다.
    func drain() -> [AnalyticsEventModel] {
        let batch = events
        events = []
        return batch
    }

    /// 버퍼에 이벤트가 있는지 확인
    var isEmpty: Bool { events.isEmpty }

    /// 현재 버퍼 크기
    var count: Int { events.count }
}

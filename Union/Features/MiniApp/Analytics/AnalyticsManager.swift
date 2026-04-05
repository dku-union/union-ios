import Foundation
import UIKit
import os.log

// MARK: - Analytics Manager

/// Analytics 시스템의 중앙 코디네이터 Actor.
///
/// ### 역할
/// - 미니앱 세션 생명주기 관리
/// - 이벤트 수신 → PII 필터 → 보강(Enrichment) → 버퍼 적재
/// - 버퍼 플러시 → 배치 전송 또는 Disk Queue 보관
/// - 앱 라이프사이클 이벤트(pause/resume) 자동 처리
/// - 오프라인 큐 재전송 (네트워크 복귀 시)
///
/// ### 사용 예시
/// ```swift
/// // 미니앱 열릴 때
/// let session = await AnalyticsManager.shared.openSession(appId: "com.union.soccer")
///
/// // 미니앱 닫힐 때
/// await AnalyticsManager.shared.closeSession()
///
/// // Bridge에서 이벤트 수신 시
/// await AnalyticsManager.shared.track(payload: trackPayload)
/// ```
actor AnalyticsManager {

    // MARK: - Singleton

    static let shared = AnalyticsManager()

    // MARK: - Dependencies

    private let buffer: AnalyticsEventBuffer
    private let diskQueue: AnalyticsDiskQueue
    private let sender: AnalyticsBatchSender
    private let piiFilter: AnalyticsPIIFilter

    // MARK: - State

    /// 현재 열려있는 미니앱 세션 (nil 이면 미니앱 미실행)
    private var currentSession: AnalyticsSession?

    /// 세션 단위 사용자 속성 (setUserProperty 로 설정, 모든 이벤트에 첨부됨)
    private var userProperties: [String: AnalyticsValue] = [:]

    /// 30초 주기 플러시 Task
    private var periodicFlushTask: Task<Void, Never>?

    private let logger = Logger(subsystem: "app.union", category: "analytics")

    // MARK: - Init

    private init() {
        self.buffer = AnalyticsEventBuffer()
        self.diskQueue = AnalyticsDiskQueue()
        self.sender = AnalyticsBatchSender()
        self.piiFilter = AnalyticsPIIFilter()

        // buffer 자동 플러시 콜백 연결
        Task { [weak self] in
            await self?.connectBufferCallback()
        }

        // 앱 라이프사이클 구독
        Task { @MainActor [weak self] in
            self?.observeAppLifecycle()
        }
    }

    // MARK: - Session Lifecycle

    /// 미니앱 세션 시작.
    /// 이 메서드는 `BridgeHandler.init` 에서 호출된다.
    ///
    /// **멱등성 보장**: 동일한 appId 로 이미 세션이 열려있으면 기존 세션을 반환한다.
    /// 같은 미니앱 내 여러 페이지의 BridgeHandler 가 각각 이 메서드를 호출하더라도
    /// 하나의 세션만 유지된다.
    ///
    /// - Parameter appId: 미니앱 식별자 (e.g. "com.union.soccer")
    /// - Returns: 현재 세션 (기존 또는 신규)
    @discardableResult
    func openSession(appId: String) -> AnalyticsSession {
        // 같은 appId 로 세션이 이미 열려있으면 재사용
        if let existing = currentSession, existing.appId == appId {
            return existing
        }

        let session = AnalyticsSession(appId: appId)
        currentSession = session
        userProperties = [:]

        // 30초 주기 플러시 시작
        startPeriodicFlush()

        logger.info("[Analytics] Session opened: \(session.sessionId) appId=\(appId)")
        return session
    }

    /// 미니앱 세션 종료.
    /// 이 메서드는 `onClose` 콜백에서 호출된다.
    func closeSession() {
        guard let session = currentSession else { return }

        // app_close 라이프사이클 이벤트 (세션 종료 전 전송)
        let duration = session.durationMs
        Task {
            await trackLifecycle(
                eventName: "app_close",
                params: ["session_duration_ms": .int(duration)]
            )
            // 세션 종료 시 즉시 플러시
            await flushAndSend()
        }

        currentSession = nil
        userProperties = [:]
        stopPeriodicFlush()

        logger.info("[Analytics] Session closed: \(session.sessionId) duration=\(duration)ms")
    }

    // MARK: - Event Tracking (Bridge → Manager)

    /// SDK `analytics.track` 액션 처리.
    func track(payload: TrackPayload) async {
        guard let session = currentSession else {
            logger.debug("[Analytics] Dropped event (no active session): \(payload.eventName)")
            return
        }

        let enriched = await enrich(payload: payload, session: session)
        await buffer.append(enriched)
    }

    /// SDK `analytics.setUserProperty` 액션 처리.
    func setUserProperty(key: String, value: AnalyticsValue) {
        userProperties[key] = value
        logger.debug("[Analytics] userProperty set: \(key)=\(String(describing: value.rawValue))")
    }

    // MARK: - Lifecycle Events (Native-originated)

    /// 네이티브 발생 라이프사이클 이벤트 추적.
    /// app_open, app_close, app_pause, app_resume 에 사용.
    func trackLifecycle(eventName: String, params: [String: AnalyticsValue] = [:]) async {
        let payload = TrackPayload(
            eventType: AnalyticsEventType.lifecycle,
            eventName: eventName,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            params: params.isEmpty ? nil : params
        )
        await track(payload: payload)
    }

    // MARK: - Flush

    /// 버퍼를 즉시 비우고 전송한다.
    /// `app:pause`, `app_close`, 명시적 호출 시 사용.
    func flushAndSend() async {
        let events = await buffer.drain()
        guard !events.isEmpty else { return }

        guard let appId = currentSession?.appId ?? events.first?.appId else { return }

        await performSend(events: events, appId: appId)
    }

    // MARK: - Disk Queue Retry

    /// Disk Queue 에 저장된 미전송 배치를 재전송.
    /// 네트워크 복귀 시 또는 앱 재시작 시 호출.
    func retryDiskQueue() async {
        let pending = await diskQueue.loadAll()
        for batch in pending {
            do {
                try await sender.send(events: batch.events, appId: batch.appId)
                await diskQueue.remove(batchId: batch.id)
                logger.info("[Analytics] DiskQueue retry success: batchId=\(batch.id)")
            } catch {
                await diskQueue.incrementRetry(batchId: batch.id)
                logger.warning("[Analytics] DiskQueue retry failed: batchId=\(batch.id) error=\(error.localizedDescription)")
                break // 네트워크 문제이면 이후 배치도 실패할 것이므로 중단
            }
        }
    }

    // MARK: - Private — Enrichment

    /// 이벤트 보강: sessionId, hashedUserId, deviceInfo 등을 추가하여 최종 이벤트 생성.
    private func enrich(payload: TrackPayload, session: AnalyticsSession) async -> AnalyticsEventModel {
        // PII 필터 적용
        let filteredParams = payload.params.map { piiFilter.filter($0) }
        let filteredUserProps = userProperties.isEmpty ? nil : piiFilter.filter(userProperties)

        // JWT → hashedUserId (메인 스레드 불필요, Keychain 접근은 thread-safe)
        let hashedUserId = AnalyticsHasher.hashedUserIdFromCurrentToken(appId: session.appId)

        return AnalyticsEventModel(
            eventType: payload.eventType,
            eventName: payload.eventName,
            clientTimestamp: payload.timestamp,
            sessionId: session.sessionId,
            superappSessionId: SuperappSession.shared.sessionId,
            hashedUserId: hashedUserId,
            appId: session.appId,
            appVersion: appVersion,
            sdkVersion: "1.0.0",
            platform: "ios",
            osVersion: osVersion,
            deviceModel: deviceModelIdentifier(),
            sequenceNumber: session.nextSequenceNumber(),
            params: filteredParams,
            userProperties: filteredUserProps
        )
    }

    // MARK: - Private — Send & Disk Queue

    private func performSend(events: [AnalyticsEventModel], appId: String) async {
        do {
            try await sender.send(events: events, appId: appId)
            logger.info("[Analytics] Batch sent: count=\(events.count) appId=\(appId)")
        } catch let sendError as AnalyticsSendError where sendError.shouldSaveToDiskQueue {
            logger.warning("[Analytics] Send failed → DiskQueue: \(sendError.localizedDescription)")
            await diskQueue.enqueue(events: events, appId: appId)
        } catch {
            logger.error("[Analytics] Send failed (drop): \(error.localizedDescription)")
        }
    }

    // MARK: - Private — Periodic Flush

    private func connectBufferCallback() async {
        await buffer.onAutoFlush = { [weak self] events in
            guard let self, let appId = await self.currentSession?.appId ?? events.first?.appId else { return }
            await self.performSend(events: events, appId: appId)
        }
    }

    private func startPeriodicFlush() {
        stopPeriodicFlush()
        periodicFlushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30초
                guard !Task.isCancelled else { break }
                await self?.flushAndSend()
            }
        }
    }

    private func stopPeriodicFlush() {
        periodicFlushTask?.cancel()
        periodicFlushTask = nil
    }

    // MARK: - Private — App Lifecycle

    @MainActor
    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleAppPause()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleAppResume()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            SuperappSession.shared.applicationDidEnterBackground()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            SuperappSession.shared.applicationWillEnterForeground()
        }
    }

    private func handleAppPause() async {
        await trackLifecycle(eventName: "app_pause")
        // 백그라운드 진입 전 즉시 플러시 (iOS 백그라운드 실행 시간 제한 대응)
        await flushAndSend()
        logger.info("[Analytics] App paused — buffer flushed")
    }

    private func handleAppResume() async {
        await trackLifecycle(eventName: "app_resume")
        // 복귀 시 Disk Queue 재전송 시도
        await retryDiskQueue()
    }

    // MARK: - Private — Device Info

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var osVersion: String {
        UIDevice.current.systemVersion
    }

    private func deviceModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { bytes in
            bytes
                .compactMap { $0 != 0 ? String(UnicodeScalar($0)) : nil }
                .joined()
        }
    }
}

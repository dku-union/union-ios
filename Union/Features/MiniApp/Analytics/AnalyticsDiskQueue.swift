import Foundation

// MARK: - Analytics Disk Queue

/// 오프라인 Analytics 이벤트 큐 (Actor).
///
/// 네트워크 전송 실패 시 이벤트 배치를 디스크에 보존한다.
/// 네트워크 복귀 또는 다음 앱 실행 시 재전송한다.
///
/// ### 저장 구조
/// ```
/// Library/Caches/union-analytics-queue/
///   {UUID}.json   ← PendingBatch (Codable)
///   {UUID}.json
///   ...
/// ```
///
/// ### 제한
/// - 최대 50개 배치 파일
/// - 파일당 최대 1MB
/// - 7일 초과 배치 자동 삭제
actor AnalyticsDiskQueue {

    // MARK: - Configuration

    private let maxBatchCount: Int      = 50
    private let maxBatchAgeDays: Double = 7
    private let maxFileSizeBytes: Int   = 1_048_576   // 1MB

    // MARK: - State

    private let queueDirectory: URL

    // MARK: - Init

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        queueDirectory = caches.appendingPathComponent("union-analytics-queue", isDirectory: true)
        try? FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Pending Batch

    struct PendingBatch: Codable {
        let id: String
        let appId: String
        let events: [AnalyticsEventModel]
        let createdAt: Date
        var retryCount: Int
    }

    // MARK: - API

    /// 배치를 디스크에 저장.
    func enqueue(events: [AnalyticsEventModel], appId: String) {
        guard !events.isEmpty else { return }

        // 오버플로우 시 가장 오래된 배치 제거
        pruneIfNeeded()

        let batch = PendingBatch(
            id: UUID().uuidString,
            appId: appId,
            events: events,
            createdAt: Date(),
            retryCount: 0
        )

        guard let data = try? JSONEncoder().encode(batch),
              data.count <= maxFileSizeBytes else { return }

        let fileURL = queueDirectory.appendingPathComponent("\(batch.id).json")
        try? data.write(to: fileURL, options: .atomic)
    }

    /// 저장된 모든 배치를 로드하여 반환.
    /// 만료된 배치(7일 초과)와 손상된 파일은 자동 삭제.
    func loadAll() -> [PendingBatch] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []

        let cutoff = Date().addingTimeInterval(-maxBatchAgeDays * 86_400)

        var batches: [PendingBatch] = []
        for file in files {
            guard file.pathExtension == "json" else { continue }

            // 만료 파일 삭제
            if let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate,
               created < cutoff {
                try? FileManager.default.removeItem(at: file)
                continue
            }

            guard let data = try? Data(contentsOf: file),
                  let batch = try? JSONDecoder().decode(PendingBatch.self, from: data) else {
                // 손상된 파일 삭제
                try? FileManager.default.removeItem(at: file)
                continue
            }

            batches.append(batch)
        }

        // 생성일 오름차순 정렬 (오래된 것 먼저 재전송)
        return batches.sorted { $0.createdAt < $1.createdAt }
    }

    /// 전송 성공 후 배치 파일 삭제.
    func remove(batchId: String) {
        let fileURL = queueDirectory.appendingPathComponent("\(batchId).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 재시도 횟수 업데이트 (3회 초과 시 자동 삭제).
    func incrementRetry(batchId: String) {
        let fileURL = queueDirectory.appendingPathComponent("\(batchId).json")
        guard let data = try? Data(contentsOf: fileURL),
              var batch = try? JSONDecoder().decode(PendingBatch.self, from: data) else { return }

        batch.retryCount += 1

        if batch.retryCount >= 3 {
            // 최대 재시도 초과 → 폐기
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        if let updated = try? JSONEncoder().encode(batch) {
            try? updated.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Maintenance

    private func pruneIfNeeded() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ))?.filter { $0.pathExtension == "json" } ?? []

        guard files.count >= maxBatchCount else { return }

        // 가장 오래된 파일 삭제
        let sorted = files.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            let d1 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            return d0 < d1
        }
        let toDelete = sorted.prefix(files.count - maxBatchCount + 1)
        toDelete.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}

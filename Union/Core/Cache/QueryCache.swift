import Foundation

// MARK: - Query Cache (Stale-While-Revalidate)

final class QueryCache: Sendable {
    private let disk: DiskCache
    private let memory = MemoryCache()

    init(disk: DiskCache = DiskCache(name: "query")) {
        self.disk = disk
    }

    /// Stale-While-Revalidate:
    /// 1. fresh cache -> return immediately
    /// 2. no cache or stale -> fetch from network, fallback to stale on failure
    func query<T: Codable & Sendable>(
        key: String,
        staleTime: TimeInterval = 60,
        fetcher: @Sendable () async throws -> T
    ) async throws -> T {
        // Memory cache (fresh)
        if let cached: T = memory.get(key: key, staleTime: staleTime) {
            return cached
        }

        // Stale data for fallback
        let staleData: T? = await disk.load(T.self, key: key)

        // Network fetch
        do {
            let fresh = try await fetcher()
            memory.set(key: key, value: fresh)
            await disk.save(fresh, key: key)
            return fresh
        } catch {
            if let staleData { return staleData }
            throw error
        }
    }

    func invalidate(key: String) {
        memory.remove(key: key)
    }

    func invalidateAll() {
        memory.removeAll()
    }
}

// MARK: - Thread-Safe Memory Cache

private final class MemoryCache: @unchecked Sendable {
    private struct Entry {
        let data: Any
        let fetchedAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let lock = NSLock()

    func get<T>(key: String, staleTime: TimeInterval) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = storage[key],
              let data = entry.data as? T,
              Date().timeIntervalSince(entry.fetchedAt) < staleTime
        else { return nil }
        return data
    }

    func set(key: String, value: Any) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = Entry(data: value, fetchedAt: Date())
    }

    func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAll()
    }
}

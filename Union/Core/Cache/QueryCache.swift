import Foundation

// MARK: - Query Cache (Stale-While-Revalidate)

actor QueryCache {
    struct Entry {
        let data: Any
        let fetchedAt: Date
    }

    private var memory: [String: Entry] = [:]
    private let disk: DiskCache

    init(disk: DiskCache = DiskCache(name: "query")) {
        self.disk = disk
    }

    /// Stale-While-Revalidate:
    /// 1. fresh cache -> return immediately
    /// 2. no cache or stale -> fetch from network, fallback to stale on failure
    func query<T: Codable>(
        key: String,
        staleTime: TimeInterval = 60,
        fetcher: @Sendable () async throws -> T
    ) async throws -> T {
        // Memory cache (fresh)
        if let entry = memory[key],
           let data = entry.data as? T,
           Date().timeIntervalSince(entry.fetchedAt) < staleTime {
            return data
        }

        // Stale data for fallback
        let staleData: T? = await disk.load(T.self, key: key)

        // Network fetch
        do {
            let fresh = try await fetcher()
            memory[key] = Entry(data: fresh, fetchedAt: Date())
            await disk.save(fresh, key: key)
            return fresh
        } catch {
            if let staleData { return staleData }
            throw error
        }
    }

    func invalidate(key: String) {
        memory.removeValue(forKey: key)
    }

    func invalidateAll() {
        memory.removeAll()
    }
}

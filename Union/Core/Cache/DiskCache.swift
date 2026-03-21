import Foundation

// MARK: - Disk Cache

actor DiskCache {
    private let directory: URL
    private let ttl: TimeInterval

    init(name: String, ttl: TimeInterval = 3600) {
        self.directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("union_cache")
            .appendingPathComponent(name)
        self.ttl = ttl
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        let file = fileURL(for: key)
        guard let attr = try? FileManager.default.attributesOfItem(atPath: file.path),
              let modified = attr[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < ttl,
              let data = try? Data(contentsOf: file)
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save<T: Codable>(_ value: T, key: String) {
        let file = fileURL(for: key)
        if let data = try? JSONEncoder().encode(value) {
            try? data.write(to: file)
        }
    }

    func remove(key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }
}

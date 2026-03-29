import Foundation

// MARK: - API Configuration

enum APIConfig {
    #if DEBUG
    static let baseURL = URL(string: "http://192.168.35.119:8080")!
    #else
    static let baseURL = URL(string: "https://api.union.app")!
    #endif

    static var authURL: URL { baseURL.appendingPathComponent("/api/v1/auth") }
    static var emailURL: URL { baseURL.appendingPathComponent("/auth/email") }
    static var apiV1URL: URL { baseURL.appendingPathComponent("/api/v1") }
}

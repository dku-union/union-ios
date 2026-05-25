import Foundation

// MARK: - API Configuration

enum APIConfig {
    #if DEBUG
    static let baseURL = URL(string: "https://union-api-183092809276.asia-northeast3.run.app")!
    #else
    static let baseURL = URL(string: "https://api.union.app")!
    #endif

    static var authURL: URL { baseURL.appendingPathComponent("/api/v1/auth") }
    static var emailURL: URL { baseURL.appendingPathComponent("/auth/email") }
    static var apiV1URL: URL { baseURL.appendingPathComponent("/api/v1") }
}

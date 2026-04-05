import Foundation

// MARK: - API Endpoint

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let body: Data?
    let headers: [String: String]

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.headers = headers
    }

    func urlRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - Predefined Endpoints

extension APIEndpoint {
    static func apps(sort: String? = nil, category: String? = nil) -> Self {
        var items: [URLQueryItem] = []
        if let sort { items.append(.init(name: "sort", value: sort)) }
        if let category { items.append(.init(name: "category", value: category)) }
        return .init(path: "/apps", queryItems: items.isEmpty ? nil : items)
    }

    static var popularApps: Self { .apps(sort: "popular") }
    static var newApps: Self { .apps(sort: "new") }
    static var recommendedApps: Self { .init(path: "/apps/recommended") }

    static func appDetail(id: UUID) -> Self {
        .init(path: "/apps/\(id.uuidString)")
    }

    static func searchApps(query: String) -> Self {
        .init(path: "/apps/search", queryItems: [.init(name: "q", value: query)])
    }

    static var categories: Self { .init(path: "/categories") }
    static var banners: Self { .init(path: "/banners") }
    static var discovery: Self { .init(path: "/mini-apps/discovery") }

    /// 미니앱 실행 → 사용 기록 저장 + CDN 번들 URL 반환
    /// POST /mini-apps/{id}/launch → { "bundleUrl": "https://cdn.union.app/..." }
    static func launchApp(id: Int) -> Self {
        .init(path: "/mini-apps/\(id)/launch", method: .post)
    }
}

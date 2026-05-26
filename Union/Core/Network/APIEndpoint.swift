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

    /// 미니앱 검색 (full search) — Redis 인기 검색어 집계 포함.
    /// 사용자가 명시적으로 검색을 제출(키보드 Enter)했을 때만 호출.
    /// GET /mini-apps/search?keyword={keyword}&page=&size=
    static func miniAppSearch(keyword: String, page: Int = 0, size: Int = 20) -> Self {
        .init(path: "/mini-apps/search", queryItems: [
            .init(name: "keyword", value: keyword),
            .init(name: "page", value: String(page)),
            .init(name: "size", value: String(size)),
        ])
    }

    /// 미니앱 실시간 미리보기 — 자음/모음 단위 매칭, 인기 검색어 집계 안 함.
    /// 타이핑 중 디바운스된 입력으로 호출하여 자동완성 UX 제공.
    /// GET /mini-apps/search/preview?keyword={keyword}&page=&size=
    static func miniAppSearchPreview(keyword: String, page: Int = 0, size: Int = 10) -> Self {
        .init(path: "/mini-apps/search/preview", queryItems: [
            .init(name: "keyword", value: keyword),
            .init(name: "page", value: String(page)),
            .init(name: "size", value: String(size)),
        ])
    }

    /// 검색 결과 클릭 이벤트 — 사용자 의도(keyword)와 결과 인기도(appName)를 모두 인기 검색어 점수에 반영.
    /// POST /mini-apps/search/click?keyword={keyword}&appName={appName}
    static func recordSearchClick(keyword: String?, appName: String) -> Self {
        var items: [URLQueryItem] = [.init(name: "appName", value: appName)]
        if let keyword, !keyword.isEmpty {
            items.append(.init(name: "keyword", value: keyword))
        }
        return .init(path: "/mini-apps/search/click", method: .post, queryItems: items)
    }

    static var categories: Self { .init(path: "/categories") }
    static var banners: Self { .init(path: "/banners") }
    static var discovery: Self { .init(path: "/mini-apps/discovery") }
    static var me: Self { .init(path: "/api/v1/users/me") }

    /// 미니앱 실행 → 사용 기록 저장 + CDN 번들 URL 반환
    /// POST /mini-apps/{id}/launch → { "bundleUrl": "https://cdn.union.app/..." }
    static func launchApp(id: Int) -> Self {
        .init(path: "/mini-apps/\(id)/launch", method: .post)
    }

    // MARK: - Notifications

    /// APNs/FCM 토큰 등록 (upsert)
    static func registerFcmToken(body: Data) -> Self {
        .init(path: "/notifications/token", method: .put, body: body)
    }

    /// 알림 인박스 조회 (커서 기반)
    static func notificationInbox(cursor: Int64?, limit: Int) -> Self {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let cursor { items.append(.init(name: "cursor", value: String(cursor))) }
        return .init(path: "/notifications/inbox", queryItems: items)
    }

    static func markNotificationRead(id: Int64) -> Self {
        .init(path: "/notifications/inbox/\(id)/read", method: .post)
    }

    static var markAllNotificationsRead: Self {
        .init(path: "/notifications/inbox/read-all", method: .post)
    }

    static var notificationUnreadCount: Self {
        .init(path: "/notifications/unread-count")
    }

    // MARK: - MiniApp Subscriptions

    static func subscribeMiniApp(appId: String) -> Self {
        .init(path: "/api/v1/users/me/miniapps/\(appId)/subscription", method: .post)
    }

    static func updateMiniAppSubscription(appId: String, body: Data) -> Self {
        .init(path: "/api/v1/users/me/miniapps/\(appId)/subscription", method: .patch, body: body)
    }

    static func unsubscribeMiniApp(appId: String) -> Self {
        .init(path: "/api/v1/users/me/miniapps/\(appId)/subscription", method: .delete)
    }

    static var mySubscriptions: Self {
        .init(path: "/api/v1/users/me/subscriptions")
    }
}

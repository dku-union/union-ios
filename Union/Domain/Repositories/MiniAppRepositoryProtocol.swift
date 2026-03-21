import Foundation

// MARK: - MiniApp Repository Protocol

protocol MiniAppRepositoryProtocol: Sendable {
    func fetchPopularApps() async throws -> [MiniApp]
    func fetchNewApps() async throws -> [MiniApp]
    func fetchRecommendedApps() async throws -> [MiniApp]
    func fetchRecentApps() async throws -> [MiniApp]
    func fetchCategories() async throws -> [AppCategory]
    func fetchBanners() async throws -> [Banner]
    func searchApps(query: String) async throws -> [MiniApp]
    func fetchAppDetail(id: UUID) async throws -> MiniApp
}

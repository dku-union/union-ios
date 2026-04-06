import Foundation

// MARK: - MiniApp Repository Protocol

protocol MiniAppRepositoryProtocol: Sendable {
    func fetchDiscovery() async throws -> DiscoveryData
    func fetchBanners() async throws -> [Banner]
    func searchApps(query: String) async throws -> [MiniApp]
    func fetchAppDetail(id: Int) async throws -> MiniApp
}

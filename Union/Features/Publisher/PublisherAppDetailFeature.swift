import Foundation
import ComposableArchitecture

// MARK: - Publisher App Detail Feature

/// 특정 미니앱의 버전 리스트 + 버전 클릭 시 테스트 실행 흐름.
///
/// 테스트 실행 순서:
/// 1. `POST /app-versions/{id}/test-session` → testLink (`union-app://test-app?token=<uuid>`)
/// 2. token 추출 → `GET /app-versions/test-bundle?token=...` → bundleUrl (CDN signed)
/// 3. bundleUrl 을 `webUrl` 로 갖는 합성 `MiniApp` 생성 → `MiniAppWebView` 가
///    `.unionapp` 패키지로 인식하고 `MiniAppLoader` 경로를 그대로 탄다.
@Reducer
struct PublisherAppDetailFeature {

    @ObservableState
    struct State: Equatable {
        let miniApp: PublisherMiniApp
        var versions: [AppVersionInfo] = []
        var isLoading = false
        var error: String?

        /// 테스트 실행 시 만들어지는 합성 MiniApp. nil 이 아니면 sheet/destination 으로 WebView 표시.
        var runningTest: TestRun?
        /// 어떤 버전이 현재 테스트 준비 중인지 (스피너 표시용).
        var preparingVersionId: UUID?
        /// 테스트 준비 실패 시 사용자에게 보여줄 에러 메시지.
        var testError: String?
    }

    struct TestRun: Equatable {
        let miniApp: MiniApp
        let versionNumber: String
    }

    enum Action {
        case onAppear
        case refresh
        case versionsLoaded([AppVersionInfo])
        case loadFailed(String)
        case versionTapped(AppVersionInfo)
        case testReady(versionId: UUID, bundle: TestBundleInfo)
        case testFailed(versionId: UUID, message: String)
        case dismissTest
        case dismissTestError
    }

    @Dependency(\.publisherAppsClient) var client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refresh:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.error = nil
                let miniAppId = state.miniApp.id
                return .run { send in
                    do {
                        let versions = try await client.listVersions(miniAppId: miniAppId)
                        await send(.versionsLoaded(versions))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .versionsLoaded(let versions):
                state.isLoading = false
                state.versions = versions
                return .none

            case .loadFailed(let message):
                state.isLoading = false
                state.error = message
                return .none

            case .versionTapped(let version):
                guard version.status.isTestable else { return .none }
                guard state.preparingVersionId == nil else { return .none }
                state.preparingVersionId = version.id
                state.testError = nil

                return .run { send in
                    do {
                        let testLink = try await client.createTestSession(versionId: version.id)
                        let token = Self.extractToken(from: testLink)
                        guard let token else {
                            throw PublisherAppsError.invalidTestLink
                        }
                        let bundle = try await client.redeemTestBundle(token: token)
                        await send(.testReady(versionId: version.id, bundle: bundle))
                    } catch {
                        await send(.testFailed(
                            versionId: version.id,
                            message: error.localizedDescription
                        ))
                    }
                }

            case .testReady(_, let bundle):
                state.preparingVersionId = nil
                let synthetic = MiniApp(
                    id: bundle.miniAppId,
                    name: bundle.miniAppName,
                    description: state.miniApp.description,
                    publisher: "테스트 빌드",
                    category: "test",
                    iconUrl: state.miniApp.iconUrl,
                    iconEmoji: nil,
                    iconColorHex: nil,
                    rating: 0,
                    ratingCount: 0,
                    isNew: false,
                    isPopular: false,
                    createdAt: Date(),
                    webUrl: bundle.bundleUrl,
                    appId: nil
                )
                state.runningTest = TestRun(miniApp: synthetic, versionNumber: bundle.versionNumber)
                return .none

            case .testFailed(_, let message):
                state.preparingVersionId = nil
                state.testError = message
                return .none

            case .dismissTest:
                state.runningTest = nil
                return .none

            case .dismissTestError:
                state.testError = nil
                return .none
            }
        }
    }

    // MARK: - Helpers

    /// `union-app://test-app?token=<uuid>` 또는 그 외 형태의 URL에서 `token` 쿼리값을 뽑는다.
    ///
    /// `URLComponents`는 커스텀 스킴 + 빈 path 조합에서 가끔 `queryItems`를 nil 로 반환하므로
    /// raw string 파싱을 fallback 으로 둔다.
    private static func extractToken(from url: URL) -> String? {
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let value = items.first(where: { $0.name == "token" })?.value {
            return value
        }
        return extractToken(fromRaw: url.absoluteString)
    }

    private static func extractToken(fromRaw raw: String) -> String? {
        guard let queryStart = raw.firstIndex(of: "?") else { return nil }
        let query = raw[raw.index(after: queryStart)...]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, parts[0] == "token" else { continue }
            return parts[1]
                .removingPercentEncoding
                ?? String(parts[1])
        }
        return nil
    }
}

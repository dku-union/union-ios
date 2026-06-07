import Foundation
import ZIPFoundation

/// .unionapp 로드 결과
struct MiniAppLoadResult {
    let appId: String
    let baseDirectory: URL
}

/// .unionapp (zip) 파일을 다운로드하고 압축 해제
enum MiniAppLoader {

    enum LoadError: LocalizedError {
        case downloadFailed(String)
        case unzipFailed(String)
        case noIndexHtml

        var errorDescription: String? {
            switch self {
            case .downloadFailed(let msg): "다운로드 실패: \(msg)"
            case .unzipFailed(let msg): "압축 해제 실패: \(msg)"
            case .noIndexHtml: "앱 패키지에 index.html이 없습니다"
            }
        }
    }

    /// CDN URL에서 .unionapp을 다운로드하고 로컬 디렉토리 정보를 반환
    static func load(from remoteURL: URL, appId: String) async throws -> MiniAppLoadResult {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appDir = cacheDir.appendingPathComponent("miniapps/\(appId)")
        let indexFile = appDir.appendingPathComponent("index.html")
        let versionMarker = appDir.appendingPathComponent(".bundle-version")

        // 버전 캐시 키: 서명 CDN URL 의 쿼리(Expires/Signature)는 매번 달라지므로 제외하고,
        // 버전마다 고유한 번들 경로(.../versions/{versionId}/...)만으로 키를 만든다.
        let cacheKey = bundleCacheKey(for: remoteURL)

        // 압축 해제된 캐시가 있고 "버전 키가 일치"할 때만 재사용한다.
        // (이전엔 index.html 존재만 봤기에, 퍼블리셔가 새 버전을 올려도 구버전을 계속 서빙했다.)
        if FileManager.default.fileExists(atPath: indexFile.path),
           let cachedKey = try? String(contentsOf: versionMarker, encoding: .utf8),
           cachedKey == cacheKey {
            return MiniAppLoadResult(appId: appId, baseDirectory: appDir)
        }

        // 다운로드 (캐시가 없거나, 버전이 바뀌어 키가 불일치)
        let (tempFileURL, response) = try await URLSession.shared.download(from: remoteURL)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LoadError.downloadFailed("HTTP \(http.statusCode)")
        }

        // 스테이징 디렉토리에 풀고, 검증까지 끝낸 뒤 통째로 교체한다.
        // (appDir 에 직접 풀면 압축 해제 도중 실패 시 깨진 캐시가 남고, 동시 로드가 서로의 파일을
        //  덮어쓸 수 있다. 완성된 번들만 원자적으로 들여놓아 부분 추출 상태가 노출되지 않게 한다.)
        let parentDir = appDir.deletingLastPathComponent()
        let stagingDir = parentDir.appendingPathComponent(".staging-\(appId)-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: stagingDir) }

        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        // ZIPFoundation으로 압축 해제
        do {
            try FileManager.default.unzipItem(at: tempFileURL, to: stagingDir)
        } catch {
            throw LoadError.unzipFailed(error.localizedDescription)
        }

        // index.html 존재 확인 (스테이징 기준)
        guard FileManager.default.fileExists(atPath: stagingDir.appendingPathComponent("index.html").path) else {
            throw LoadError.noIndexHtml
        }

        // 이번 버전 키 기록 — 교체 전 스테이징 내부에 기록해 함께 들여놓는다.
        try? cacheKey.write(to: stagingDir.appendingPathComponent(".bundle-version"),
                            atomically: true, encoding: .utf8)

        // 원자적 교체: 완성된 스테이징을 appDir 자리로 이동. (최초 로드면 appDir 부재 — 무시)
        try? FileManager.default.removeItem(at: appDir)
        do {
            try FileManager.default.moveItem(at: stagingDir, to: appDir)
        } catch {
            throw LoadError.unzipFailed("캐시 교체 실패: \(error.localizedDescription)")
        }

        // index.html 최종 확인
        guard FileManager.default.fileExists(atPath: indexFile.path) else {
            throw LoadError.noIndexHtml
        }

        return MiniAppLoadResult(appId: appId, baseDirectory: appDir)
    }

    /// 서명 CDN URL 에서 버전 고유 캐시 키를 만든다.
    /// 쿼리스트링(서명/만료 파라미터)은 같은 버전이라도 매 요청마다 달라지므로 제외하고,
    /// 버전마다 고유한 경로(`.../versions/{versionId}/...`)만 사용한다.
    private static func bundleCacheKey(for url: URL) -> String {
        let path = url.path
        return path.isEmpty ? url.absoluteString : path
    }

    /// 캐시 삭제
    static func clearCache(appId: String) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appDir = cacheDir.appendingPathComponent("miniapps/\(appId)")
        try? FileManager.default.removeItem(at: appDir)
    }
}

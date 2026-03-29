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

        // 이미 압축 해제된 캐시가 있으면 바로 반환
        if FileManager.default.fileExists(atPath: indexFile.path) {
            return MiniAppLoadResult(appId: appId, baseDirectory: appDir)
        }

        // 다운로드
        let (tempFileURL, response) = try await URLSession.shared.download(from: remoteURL)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LoadError.downloadFailed("HTTP \(http.statusCode)")
        }

        // 기존 디렉토리 정리 후 생성
        try? FileManager.default.removeItem(at: appDir)
        try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        // ZIPFoundation으로 압축 해제
        do {
            try FileManager.default.unzipItem(at: tempFileURL, to: appDir)
        } catch {
            throw LoadError.unzipFailed(error.localizedDescription)
        }

        // index.html 존재 확인
        guard FileManager.default.fileExists(atPath: indexFile.path) else {
            throw LoadError.noIndexHtml
        }

        return MiniAppLoadResult(appId: appId, baseDirectory: appDir)
    }

    /// 캐시 삭제
    static func clearCache(appId: String) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appDir = cacheDir.appendingPathComponent("miniapps/\(appId)")
        try? FileManager.default.removeItem(at: appDir)
    }
}

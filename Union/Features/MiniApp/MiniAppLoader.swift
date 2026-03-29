import Foundation
import ZIPFoundation

/// .unionapp (zip) 파일을 다운로드하고 압축 해제하여 로컬 index.html URL을 반환
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

    /// CDN URL에서 .unionapp을 다운로드하고 로컬 index.html file URL을 반환
    static func load(from remoteURL: URL, appId: String) async throws -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appDir = cacheDir.appendingPathComponent("miniapps/\(appId)")
        let indexFile = appDir.appendingPathComponent("index.html")

        // 이미 압축 해제된 캐시가 있으면 바로 반환
        if FileManager.default.fileExists(atPath: indexFile.path) {
            return indexFile
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

        // 절대경로(/assets/...)를 상대경로(./assets/...)로 패치
        patchAbsolutePaths(in: indexFile)

        return indexFile
    }

    /// file:// CORS 문제 회피: 외부 JS/CSS를 inline으로 삽입
    private static func patchAbsolutePaths(in file: URL) {
        guard var html = try? String(contentsOf: file, encoding: .utf8) else { return }
        let baseDir = file.deletingLastPathComponent()

        // <script type="module" crossorigin src="..."> → <script>내용</script>
        let scriptPattern = #/<script[^>]*\ssrc="\.?\/?([^"]+)"[^>]*><\/script>/#
        for match in html.matches(of: scriptPattern) {
            let srcPath = String(match.output.1)
            let jsFile = baseDir.appendingPathComponent(srcPath)
            if let jsContent = try? String(contentsOf: jsFile, encoding: .utf8) {
                html = html.replacingOccurrences(of: String(match.output.0), with: "<script>\(jsContent)</script>")
            }
        }

        // <link rel="stylesheet" crossorigin href="..."> → <style>내용</style>
        let linkPattern = #/<link[^>]*\shref="\.?\/?([^"]+)"[^>]*>/#
        for match in html.matches(of: linkPattern) {
            let hrefPath = String(match.output.1)
            guard hrefPath.hasSuffix(".css") else { continue }
            let cssFile = baseDir.appendingPathComponent(hrefPath)
            if let cssContent = try? String(contentsOf: cssFile, encoding: .utf8) {
                html = html.replacingOccurrences(of: String(match.output.0), with: "<style>\(cssContent)</style>")
            }
        }

        try? html.write(to: file, atomically: true, encoding: .utf8)
    }

    /// 캐시 삭제
    static func clearCache(appId: String) {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let appDir = cacheDir.appendingPathComponent("miniapps/\(appId)")
        try? FileManager.default.removeItem(at: appDir)
    }
}

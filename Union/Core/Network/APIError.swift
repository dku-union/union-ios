import Foundation

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case networkUnavailable
    /// 토큰 갱신 실패 — 재로그인 필요
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            "잘못된 URL: \(path)"
        case .invalidResponse:
            "서버 응답을 처리할 수 없습니다"
        case .httpError(let code, _):
            "서버 오류 (\(code))"
        case .decodingFailed(let error):
            "데이터 파싱 실패: \(error.localizedDescription)"
        case .networkUnavailable:
            "네트워크에 연결할 수 없습니다"
        case .sessionExpired:
            "세션이 만료되었습니다. 다시 로그인해주세요"
        }
    }
}

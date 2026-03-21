import Foundation

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, data: Data)
    case decodingFailed(Error)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            return "Invalid URL: \(path)"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code, _):
            return "Server error (\(code))"
        case .decodingFailed(let error):
            return "Data parsing failed: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

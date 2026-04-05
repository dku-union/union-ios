import Foundation

// MARK: - JWT Decoder

/// JWT 페이로드 디코딩 유틸리티
/// - 클라이언트 측에서 accessToken의 만료 시간(exp)을 확인하는 용도
/// - 서명 검증은 서버 책임이며, 클라이언트는 exp 클레임만 참조
enum JWTDecoder {

    struct Payload {
        let expiresAt: Date
        let issuedAt: Date?
        let subject: String?

        /// 토큰이 이미 만료되었는지 확인
        var isExpired: Bool {
            expiresAt <= Date()
        }

        /// 지정된 시간(초) 이내에 만료 예정인지 확인
        func isExpiring(within interval: TimeInterval) -> Bool {
            expiresAt.timeIntervalSinceNow < interval
        }
    }

    // MARK: - Public

    /// JWT 문자열에서 페이로드를 디코딩
    /// - Parameter token: "header.payload.signature" 형식의 JWT 문자열
    /// - Returns: 디코딩된 Payload. 형식이 올바르지 않으면 nil
    static func decode(_ token: String) -> Payload? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        guard let data = base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval
        else { return nil }

        return Payload(
            expiresAt: Date(timeIntervalSince1970: exp),
            issuedAt: (json["iat"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            subject: json["sub"] as? String
        )
    }

    // MARK: - Private

    /// Base64URL → 표준 Base64 변환 후 디코딩
    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }
}

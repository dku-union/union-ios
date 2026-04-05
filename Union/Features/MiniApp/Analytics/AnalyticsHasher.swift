import Foundation
import CryptoKit

// MARK: - Analytics Hasher

/// Analytics 전용 SHA-256 해시 유틸리티.
///
/// 원본 userId 를 절대 네트워크로 전송하지 않는다.
/// 대신 `SHA-256(userId + ":" + appId)` 를 계산하여
/// 앱별로 고유하면서도 원본 복원이 불가능한 식별자를 생성한다.
///
/// 백엔드 `AnalyticsHasher.java` 와 동일한 알고리즘 사용.
enum AnalyticsHasher {

    /// SHA-256(userId + ":" + appId) 를 64자 소문자 hex 문자열로 반환.
    ///
    /// - Parameters:
    ///   - userId: JWT `sub` 클레임 (UUID 문자열)
    ///   - appId:  미니앱 식별자 (e.g. "com.union.soccer")
    /// - Returns: 64자 소문자 hex 해시
    static func hash(userId: String, appId: String) -> String {
        let input = "\(userId):\(appId)"
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 현재 Keychain accessToken 에서 sub 클레임을 추출하여 hashedUserId 계산.
    /// 토큰이 없거나 sub 클레임이 없으면 nil 반환.
    static func hashedUserIdFromCurrentToken(appId: String) -> String? {
        guard
            let token = KeychainStore.load(.accessToken),
            let payload = JWTDecoder.decode(token),
            let sub = payload.subject,
            !sub.isEmpty
        else { return nil }

        return hash(userId: sub, appId: appId)
    }
}

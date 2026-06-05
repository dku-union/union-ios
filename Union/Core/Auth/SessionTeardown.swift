import Foundation

// MARK: - Session Teardown

/// 로그아웃/탈퇴 시 서버측 세션 흔적을 best-effort 로 정리한다.
///
/// keychain 을 비우기 **전에** 스냅샷해 둔 access token 으로 호출해야 한다(Bearer 필요).
/// 토큰 자동 갱신(`TokenProvider`)을 의도적으로 쓰지 않는다 — 로그아웃 도중 401→refresh 로
/// 새 세션이 발급되어 방금 무효화한 세션이 되살아나는 race 를 피하기 위함.
/// 모든 호출은 실패해도 무시한다(네트워크 오류가 로컬 로그아웃을 막아선 안 된다).
enum SessionTeardown {

    /// 1) 현재 기기 FCM 토큰 해제(DELETE /notifications/token)
    /// 2) 서버 세션 로그아웃(POST /api/v1/auth/logout — 이 기기의 refresh 토큰만 무효화)
    static func purgeServerSession(accessToken: String?, refreshToken: String?, fcmToken: String?, deviceId: String) async {
        guard let accessToken else { return }

        // 로그아웃은 keychain 을 먼저 비운다. 이 시점에 access token 이 다시 존재한다면 재로그인이
        // 일어난 것. FCM 등록 토큰은 로그인 상태와 무관하게 기기마다 안정적이라 재로그인 시 같은 값으로
        // 재등록되므로, 늦게 도착한 DELETE 가 그 토큰을 지우지 않도록 FCM 삭제만 건너뛴다.
        // (서버 로그아웃은 이 세션의 refresh 토큰만 무효화하므로 재로그인 세션에 무해 → 항상 수행)
        let reLoggedIn = KeychainStore.load(.accessToken) != nil

        await withTaskGroup(of: Void.self) { group in
            if let fcmToken, !reLoggedIn {
                group.addTask {
                    let body = try? JSONSerialization.data(
                        withJSONObject: ["token": fcmToken, "deviceId": deviceId]
                    )
                    await send(method: "DELETE", path: "/notifications/token", accessToken: accessToken, body: body)
                }
            }
            group.addTask {
                let body: Data? = refreshToken.flatMap {
                    try? JSONSerialization.data(withJSONObject: ["refreshToken": $0])
                }
                await send(method: "POST", path: "/api/v1/auth/logout", accessToken: accessToken, body: body)
            }
        }
    }

    private static func send(method: String, path: String, accessToken: String, body: Data?) async {
        let url = APIConfig.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 5
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        _ = try? await URLSession.shared.data(for: request)
    }
}

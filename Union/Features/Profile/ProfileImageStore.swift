import UIKit

// MARK: - Profile Image Store

/// 방금 업로드한 프로필 이미지를 URL 기준으로 메모리에 잠깐 보관한다.
/// 업로드 직후에는 새 GCS URL 의 이미지를 다시 내려받기까지 지연이 생겨
/// `AsyncImage` 가 이모지 폴백으로 잠깐 깜빡이는데, 이 캐시를 먼저 조회하면
/// 업로드한 이미지가 즉시 반영된다(네트워크 왕복 없음).
///
/// `NSCache` 라 스레드 안전하며 메모리 압박 시 자동 비워진다. 앱 재시작 시에는
/// 비어 있고, 그때는 정상적으로 URL 에서 내려받는다.
final class ProfileImageStore {
    static let shared = ProfileImageStore()
    private let cache = NSCache<NSString, UIImage>()
    private init() {}

    func set(_ image: UIImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }

    func image(for url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }
}

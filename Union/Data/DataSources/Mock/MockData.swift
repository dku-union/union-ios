import Foundation

// MARK: - Mock Data

enum MockData {

    // MARK: - Category IDs

    static let catFestival = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let catFood = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let catStudy = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let catTrade = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let catSocial = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let catLife = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let catClub = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!
    static let catAcademic = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!

    // MARK: - Categories

    static let categories: [AppCategory] = [
        AppCategory(id: catFestival, name: "축제", emoji: "🎪", colorHex: "FF6060"),
        AppCategory(id: catFood, name: "학식", emoji: "🍚", colorHex: "FFB547"),
        AppCategory(id: catStudy, name: "스터디", emoji: "📚", colorHex: "3B5BFF"),
        AppCategory(id: catTrade, name: "거래", emoji: "🛍️", colorHex: "22C993"),
        AppCategory(id: catSocial, name: "소통", emoji: "💬", colorHex: "8B5CF6"),
        AppCategory(id: catLife, name: "생활", emoji: "🏠", colorHex: "FF9A5C"),
        AppCategory(id: catClub, name: "동아리", emoji: "🎭", colorHex: "36D1C4"),
        AppCategory(id: catAcademic, name: "학사", emoji: "🎓", colorHex: "5B7FFF"),
    ]

    // MARK: - Banners

    static let banners: [Banner] = [
        Banner(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "2026 단국대 대동제 D-7",
            subtitle: "축제 일정부터 주점 웨이팅까지 한번에",
            gradientStartHex: "3B5BFF", gradientEndHex: "8B5CF6", emoji: "🎆"
        ),
        Banner(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            title: "스터디 모집 시즌 오픈",
            subtitle: "기말고사 대비 스터디를 지금 만들어보세요",
            gradientStartHex: "22C993", gradientEndHex: "36D1C4", emoji: "✏️"
        ),
        Banner(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            title: "새로운 미니앱이 도착했어요",
            subtitle: "이번 주 인기 신규 앱을 확인해보세요",
            gradientStartHex: "FF6060", gradientEndHex: "FF9A5C", emoji: "🚀"
        ),
    ]

    // MARK: - Mini Apps

    /// 개발 테스트용: sample-app을 union dev로 실행 중일 때 사용
    static let devBaseURL = "http://localhost:3000"

    static let allApps: [MiniApp] = [
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                name: "Sample App (CDN)", description: "CDN에서 서빙되는 샘플 미니앱 테스트",
                publisher: "Union Dev", categoryId: catFestival,
                iconEmoji: "🚀", iconColorHex: "3B5BFF", rating: 5.0, ratingCount: 1,
                isNew: true, isPopular: true, createdAt: date(daysAgo: 0),
                webUrl: "http://34.110.138.90/mini-apps/66d1bf78-29b5-45d8-bba7-f08f88bffa23/com.union.sample-app-1.0.0.unionapp"),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                name: "주점 웨이팅", description: "축제 주점 대기열 실시간 관리. 순서가 오면 푸시 알림!",
                publisher: "총학생회", categoryId: catFestival,
                iconEmoji: "🍻", iconColorHex: "FFB547", rating: 4.5, ratingCount: 189,
                isNew: false, isPopular: true, createdAt: date(daysAgo: 14),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                name: "스터디 모집", description: "같은 과목 스터디 그룹을 찾고 만들어보세요. 시간표 기반 매칭",
                publisher: "dev.김민수", categoryId: catStudy,
                iconEmoji: "📖", iconColorHex: "3B5BFF", rating: 4.3, ratingCount: 156,
                isNew: false, isPopular: true, createdAt: date(daysAgo: 30),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000004")!,
                name: "오늘의 학식", description: "단국대 학생식당 메뉴를 한눈에. 영양 정보와 리뷰까지",
                publisher: "dev.이서연", categoryId: catFood,
                iconEmoji: "🍱", iconColorHex: "FF9A5C", rating: 4.6, ratingCount: 278,
                isNew: false, isPopular: true, createdAt: date(daysAgo: 45),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000005")!,
                name: "강의실 예약", description: "빈 강의실 조회 및 예약. 팀 프로젝트 공간을 손쉽게 확보",
                publisher: "총학생회", categoryId: catAcademic,
                iconEmoji: "🏫", iconColorHex: "5B7FFF", rating: 4.1, ratingCount: 97,
                isNew: true, isPopular: false, createdAt: date(daysAgo: 3),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000006")!,
                name: "캠퍼스 중고거래", description: "교내 중고 물품 거래. 같은 캠퍼스라 직거래가 편해요",
                publisher: "dev.박준혁", categoryId: catTrade,
                iconEmoji: "🛒", iconColorHex: "22C993", rating: 4.4, ratingCount: 213,
                isNew: false, isPopular: true, createdAt: date(daysAgo: 60),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000007")!,
                name: "단국 소개팅", description: "단국대 재학생 인증 기반 소개팅 매칭. 안전한 만남",
                publisher: "dev.최유진", categoryId: catSocial,
                iconEmoji: "💘", iconColorHex: "FF6090", rating: 4.2, ratingCount: 445,
                isNew: false, isPopular: true, createdAt: date(daysAgo: 90),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000008")!,
                name: "동아리 박람회", description: "전체 동아리 소개 및 가입 신청. 활동 후기와 일정 확인",
                publisher: "총학생회", categoryId: catClub,
                iconEmoji: "🎯", iconColorHex: "36D1C4", rating: 4.0, ratingCount: 88,
                isNew: true, isPopular: false, createdAt: date(daysAgo: 5),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000009")!,
                name: "야식 행사", description: "학생회 야식 이벤트 신청. 선착순 마감 실시간 알림",
                publisher: "총학생회", categoryId: catFestival,
                iconEmoji: "🌙", iconColorHex: "8B5CF6", rating: 4.8, ratingCount: 521,
                isNew: false, isPopular: true, createdAt: date(daysAgo: 7),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000010")!,
                name: "택시 팟", description: "같은 방향 택시 합승 메이트를 찾아보세요. 교통비 절약!",
                publisher: "dev.한소희", categoryId: catLife,
                iconEmoji: "🚕", iconColorHex: "FFD97A", rating: 4.3, ratingCount: 167,
                isNew: true, isPopular: false, createdAt: date(daysAgo: 2),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000011")!,
                name: "과제 알리미", description: "e-class 과제 마감일을 한 눈에 확인. 리마인더 푸시 알림",
                publisher: "dev.정도윤", categoryId: catAcademic,
                iconEmoji: "📋", iconColorHex: "5B7FFF", rating: 4.5, ratingCount: 312,
                isNew: true, isPopular: false, createdAt: date(daysAgo: 1),
                webUrl: devBaseURL),
        MiniApp(id: UUID(uuidString: "20000000-0000-0000-0000-000000000012")!,
                name: "캠퍼스 맛집", description: "단국대 주변 맛집 큐레이션. 학생 할인 정보와 리뷰",
                publisher: "dev.이서연", categoryId: catFood,
                iconEmoji: "🍕", iconColorHex: "FF9A5C", rating: 4.6, ratingCount: 198,
                isNew: false, isPopular: false, createdAt: date(daysAgo: 20),
                webUrl: devBaseURL),
    ]

    static var popularApps: [MiniApp] {
        allApps.filter(\.isPopular).sorted { $0.ratingCount > $1.ratingCount }
    }

    static var newApps: [MiniApp] {
        allApps.filter(\.isNew).sorted { $0.createdAt > $1.createdAt }
    }

    static var recommendedApps: [MiniApp] {
        Array(allApps.shuffled().prefix(6))
    }

    static var recentApps: [MiniApp] {
        [allApps[0], allApps[3], allApps[6], allApps[8]]
    }

    // MARK: - Notifications

    static let notifications: [AppNotification] = [
        AppNotification(id: UUID(), title: "'단국대 축제 2026' 업데이트",
                        body: "타임테이블이 업데이트되었습니다. 새로운 일정을 확인해보세요.",
                        type: .update, isRead: false, createdAt: date(hoursAgo: 2)),
        AppNotification(id: UUID(), title: "새로운 추천 미니앱",
                        body: "'과제 알리미'를 사용해보세요. 과제 마감을 놓치지 않아요!",
                        type: .recommendation, isRead: false, createdAt: date(hoursAgo: 5)),
        AppNotification(id: UUID(), title: "야식 행사 오픈",
                        body: "오늘 저녁 9시 야식 행사가 시작됩니다. 선착순이니 서두르세요!",
                        type: .announcement, isRead: true, createdAt: date(hoursAgo: 24)),
    ]

    // MARK: - User

    static let currentUser = UserProfile(
        id: UUID(), nickname: "준", university: "단국대학교",
        department: "소프트웨어학과", isVerified: true, profileEmoji: "😎"
    )

    // MARK: - Helpers

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
    }

    private static func date(hoursAgo: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date()) ?? Date()
    }
}

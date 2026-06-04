import SwiftUI
import ComposableArchitecture

// MARK: - Home View

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    /// 배너 탭 시 라우팅 대상이 미니앱이면 여기에 담아 navigationDestination push.
    @State private var bannerDestinationApp: MiniApp?

    /// 첫 로드 중 (데이터가 아직 없음) 여부 → 스켈레톤 표시 조건
    private var isFirstLoading: Bool {
        store.isLoading && store.popularApps.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: UNSpacing.xxl) {
                        header
                            .padding(.top, UNSpacing.sm)

                        if isFirstLoading {
                            HomeSkeletonView()
                                .transition(.opacity)
                        } else {
                            contentSections
                                .transition(.opacity)
                        }

                        Spacer(minLength: UNSpacing.xxxxl + 20)
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: isFirstLoading)
            }
            .navigationBarHidden(true)
            .refreshable { store.send(.refresh) }
            .task { store.send(.onAppear) }
            .navigationDestination(item: $bannerDestinationApp) { app in
                MiniAppWebView(miniApp: app)
            }
        }
    }

    // MARK: - Banner Routing

    /// 배너 탭 → linkType 분기.
    /// - .none: 무반응 (단순 노출 배너)
    /// - .externalUrl: 시스템 브라우저로 open
    /// - .miniApp: 현 Home에 로드된 미니앱 풀(popular/new/recommended/recent)에서 id 매치 후 push
    private func handleBannerTap(_ banner: Banner) {
        switch banner.linkType {
        case .none:
            return
        case .externalUrl:
            guard let target = banner.linkTarget, let url = URL(string: target) else { return }
            UIApplication.shared.open(url)
        case .miniApp:
            guard let target = banner.linkTarget, let id = Int(target) else { return }
            let pool = store.popularApps + store.newApps + store.recommendedApps + store.recentApps
            if let app = pool.first(where: { $0.id == id }) {
                bannerDestinationApp = app
            }
        }
    }

    // MARK: - Content Sections

    @ViewBuilder
    private var contentSections: some View {
        BannerCarousel(banners: store.banners) { banner in
            handleBannerTap(banner)
        }

        // 카테고리 섹션은 카테고리 기능(코드↔표시명 매핑/탐색) 준비 전까지 임시 숨김.
        // categorySection

        if !store.recentApps.isEmpty {
            miniAppHorizontalSection(title: "최근 사용", apps: store.recentApps)
        }

        popularSection

        if !store.newApps.isEmpty {
            miniAppHorizontalSection(title: "새로운 미니앱", apps: store.newApps)
        }

        if !store.recommendedApps.isEmpty {
            recommendedSection
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            UNColor.bgPrimary.ignoresSafeArea()
            LinearGradient(
                colors: [
                    UNColor.interactive.opacity(0.06),
                    UNColor.red400.opacity(0.03),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Union")
                    .font(UNFont.displayMedium(.black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: UNColor.gradientRedAccent,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("단국대학교")
                    .font(UNFont.captionLarge(.medium))
                    .foregroundStyle(UNColor.textTertiary)
            }
            Spacer()
            Button {
                clearMiniAppCache()
            } label: {
                Image(systemName: "trash")
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.textTertiary)
                    .frame(width: 40, height: 40)
                    .background(UNColor.bgSecondary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(UNColor.border, lineWidth: 1))
                    .unShadow(.subtle)
            }
            Button {} label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(UNFont.headingLarge())
                        .foregroundStyle(UNColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(UNColor.bgSecondary)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(UNColor.border, lineWidth: 1))
                        .unShadow(.subtle)

                    Circle()
                        .fill(UNColor.interactive)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: -1)
                }
            }
        }
        .padding(.horizontal, UNSpacing.xl)
    }

    private func clearMiniAppCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let miniappsDir = cacheDir.appendingPathComponent("miniapps")
        try? FileManager.default.removeItem(at: miniappsDir)
        print("[Cache] Cleared miniapps cache")
    }

    // MARK: - Categories

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: "카테고리", showMore: false)
            CategoryGrid(categories: store.categories)
        }
    }

    // MARK: - Popular

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: "인기 미니앱")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UNSpacing.md) {
                    ForEach(Array(store.popularApps.enumerated()), id: \.element.id) { index, app in
                        MiniAppCardRanked(app: app, rank: index + 1) { tapped in
                            store.send(.appTapped(tapped))
                        }
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }
        }
    }

    // MARK: - Recommended

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: "추천 미니앱")
            VStack(spacing: UNSpacing.md) {
                ForEach(store.recommendedApps.prefix(4)) { app in
                    MiniAppCardHorizontal(app: app) { tapped in
                        store.send(.appTapped(tapped))
                    }
                }
            }
            .padding(.horizontal, UNSpacing.xl)
        }
    }

    // MARK: - Horizontal Scroll Section

    private func miniAppHorizontalSection(title: String, apps: [MiniApp]) -> some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UNSpacing.md) {
                    ForEach(apps) { app in
                        MiniAppCardVertical(app: app) { tapped in
                            store.send(.appTapped(tapped))
                        }
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.miniAppClient = .previewValue
        }
    )
}

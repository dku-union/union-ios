import SwiftUI
import ComposableArchitecture

// MARK: - Home View (Glassmorphism)

struct HomeView: View {
    let store: StoreOf<HomeFeature>

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
                            HomeSkeletonView(showRecentSection: store.hasEverLaunchedApp)
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
        }
    }

    // MARK: - Content Sections

    @ViewBuilder
    private var contentSections: some View {
        BannerCarousel(banners: store.banners)

        categorySection

        if !store.recentApps.isEmpty {
            miniAppHorizontalSection(title: "최근 사용", apps: store.recentApps)
        }

        popularSection

        if !store.newApps.isEmpty {
            miniAppHorizontalSection(title: "새로운 미니앱", apps: store.newApps)
        }

        recommendedSection
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
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            Button {} label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(UNFont.headingLarge())
                        .foregroundStyle(UNColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())

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

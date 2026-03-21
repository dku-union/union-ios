import SwiftUI
import ComposableArchitecture

// MARK: - Home View

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: UBSpacing.xxl) {
                header

                BannerCarousel(banners: store.banners)

                // Categories
                VStack(alignment: .leading, spacing: UBSpacing.lg) {
                    SectionHeader(title: "카테고리", showMore: false)
                    CategoryGrid(categories: store.categories)
                }

                // Recent
                if !store.recentApps.isEmpty {
                    miniAppSection(title: "최근 사용", apps: store.recentApps)
                }

                // Popular (ranked)
                popularSection

                // New
                if !store.newApps.isEmpty {
                    miniAppSection(title: "새로운 미니앱", apps: store.newApps)
                }

                // Recommended (list)
                recommendedSection

                Spacer(minLength: UBSpacing.xxxxl)
            }
            .padding(.top, UBSpacing.sm)
        }
        .background(UBColor.bgPrimary)
        .refreshable {
            store.send(.refresh)
        }
        .task {
            store.send(.onAppear)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Union")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(UBColor.brand)
                Text("단국대학교")
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
            }
            Spacer()
            Button {} label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title3)
                        .foregroundStyle(UBColor.textSecondary)
                    Circle()
                        .fill(UBColor.coral)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .padding(.horizontal, UBSpacing.xl)
    }

    // MARK: - Popular (ranked)

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: UBSpacing.lg) {
            SectionHeader(title: "인기 미니앱")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UBSpacing.md) {
                    ForEach(Array(store.popularApps.enumerated()), id: \.element.id) { index, app in
                        MiniAppCardRanked(app: app, rank: index + 1)
                    }
                }
                .padding(.horizontal, UBSpacing.xl)
            }
        }
    }

    // MARK: - Recommended (vertical list)

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: UBSpacing.lg) {
            SectionHeader(title: "추천 미니앱")
            VStack(spacing: UBSpacing.md) {
                ForEach(store.recommendedApps.prefix(4)) { app in
                    MiniAppCardHorizontal(app: app)
                }
            }
            .padding(.horizontal, UBSpacing.xl)
        }
    }

    // MARK: - Horizontal Section

    private func miniAppSection(title: String, apps: [MiniApp]) -> some View {
        VStack(alignment: .leading, spacing: UBSpacing.lg) {
            SectionHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UBSpacing.md) {
                    ForEach(apps) { app in
                        MiniAppCardVertical(app: app)
                    }
                }
                .padding(.horizontal, UBSpacing.xl)
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

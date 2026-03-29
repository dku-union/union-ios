import SwiftUI
import ComposableArchitecture

// MARK: - Home View (Glassmorphism)

struct HomeView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient gradient background
                backgroundGradient

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: UNSpacing.xxl) {
                        header
                            .padding(.top, UNSpacing.sm)

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

                        Spacer(minLength: UNSpacing.xxxxl + 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .refreshable { store.send(.refresh) }
            .task { store.send(.onAppear) }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            UNColor.bgPrimary.ignoresSafeArea()
            // Subtle brand tint at the top
            LinearGradient(
                colors: [
                    UNColor.brand.opacity(0.06),
                    UNColor.violet.opacity(0.03),
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
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: UNColor.gradientBluePurple,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("단국대학교")
                    .font(UNFont.captionLarge(.medium))
                    .foregroundStyle(UNColor.textTertiary)
            }
            Spacer()
            Button {} label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title3)
                        .foregroundStyle(UNColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())

                    Circle()
                        .fill(UNColor.coral)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 2, y: -1)
                }
            }
        }
        .padding(.horizontal, UNSpacing.xl)
    }

    // MARK: - Categories (glass chips)

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: "카테고리", showMore: false)
            CategoryGrid(categories: store.categories)
        }
    }

    // MARK: - Popular (ranked, glass cards)

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: "인기 미니앱")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: UNSpacing.md) {
                    ForEach(Array(store.popularApps.enumerated()), id: \.element.id) { index, app in
                        MiniAppCardRanked(app: app, rank: index + 1)
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }
        }
    }

    // MARK: - Recommended (vertical list, glass)

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            SectionHeader(title: "추천 미니앱")
            VStack(spacing: UNSpacing.md) {
                ForEach(store.recommendedApps.prefix(4)) { app in
                    MiniAppCardHorizontal(app: app)
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
                        MiniAppCardVertical(app: app)
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

import SwiftUI
import ComposableArchitecture

// MARK: - Search View

struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UNSpacing.xxl) {
                    if store.query.isEmpty {
                        emptyState
                    } else if !store.results.isEmpty {
                        // 결과 있음 — 재검색 중이어도 기존 결과를 유지(스피너는 overlay).
                        searchResults
                    } else if store.isSearching {
                        // 검색 중 & 결과 아직 없음 — "검색 결과 0개" 깜빡임 대신 빈 로딩 영역.
                        searchingView
                    } else {
                        noResultsView
                    }
                }
                .padding(.top, UNSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(UNColor.bgPrimary)
            .navigationTitle("검색")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $store.query, prompt: "미니앱 검색")
            .onSubmit(of: .search) {
                store.send(.submitSearch)
            }
            .overlay {
                if store.isSearching {
                    ProgressView()
                }
            }
            .task { store.send(.onAppear) }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: UNSpacing.xxxl) {
            if !store.trendingKeywords.isEmpty {
                VStack(alignment: .leading, spacing: UNSpacing.lg) {
                    Text("인기 검색어")
                        .font(UNFont.headingSmall())
                        .foregroundStyle(UNColor.textPrimary)
                        .padding(.horizontal, UNSpacing.xl)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: UNSpacing.sm) {
                            ForEach(store.trendingKeywords, id: \.self) { keyword in
                                Button {
                                    store.query = keyword
                                } label: {
                                    Text("#\(keyword)")
                                        .font(UNFont.bodyMedium(.medium))
                                        .foregroundStyle(UNColor.interactive)
                                        .padding(.horizontal, UNSpacing.lg)
                                        .padding(.vertical, UNSpacing.sm)
                                        .background(UNColor.bgAccent)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, UNSpacing.xl)
                    }
                }
            }

            if !store.categories.isEmpty {
                VStack(alignment: .leading, spacing: UNSpacing.lg) {
                    Text("카테고리별 탐색")
                        .font(UNFont.headingSmall())
                        .foregroundStyle(UNColor.textPrimary)
                        .padding(.horizontal, UNSpacing.xl)

                    CategoryGrid(categories: store.categories)
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: UNSpacing.lg) {
            Text("검색 결과 \(store.results.count)개")
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textSecondary)
                .padding(.horizontal, UNSpacing.xl)

            VStack(spacing: UNSpacing.md) {
                ForEach(store.results) { app in
                    MiniAppCardHorizontal(app: app) { tapped in
                        store.send(.resultTapped(tapped))
                    }
                }
            }
            .padding(.horizontal, UNSpacing.xl)
        }
    }

    // MARK: - Searching

    /// 검색 중이면서 결과가 아직 없을 때의 자리.
    /// 콘텐츠는 비우고 화면 중앙 overlay 의 ProgressView 만 노출 — full-width 로 잡아
    /// 좁은 폭으로 뒤 배경이 비치는 현상을 막는다.
    private var searchingView: some View {
        Color.clear
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: UNSpacing.lg) {
            Spacer().frame(height: 60)
            Text("🔍")
                .font(.system(size: 48))
            Text("검색 결과가 없어요")
                .font(UNFont.headingMedium())
                .foregroundStyle(UNColor.textPrimary)
            Text("다른 키워드로 검색해보세요")
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

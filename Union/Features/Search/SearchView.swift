import SwiftUI
import ComposableArchitecture

// MARK: - Search View

struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    private let trendingKeywords = ["축제", "웨이팅", "스터디", "학식", "중고거래", "소개팅"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UNSpacing.xxl) {
                    if store.query.isEmpty {
                        emptyState
                    } else if store.results.isEmpty && !store.isSearching {
                        noResultsView
                    } else {
                        searchResults
                    }
                }
                .padding(.top, UNSpacing.lg)
            }
            .background(UNColor.bgPrimary)
            .navigationTitle("검색")
            .searchable(text: $store.query, prompt: "미니앱 검색")
            .overlay {
                if store.isSearching {
                    ProgressView()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: UNSpacing.xxxl) {
            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                Text("인기 검색어")
                    .font(UNFont.headingSmall())
                    .foregroundStyle(UNColor.textPrimary)
                    .padding(.horizontal, UNSpacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UNSpacing.sm) {
                        ForEach(trendingKeywords, id: \.self) { keyword in
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

            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                Text("카테고리별 탐색")
                    .font(UNFont.headingSmall())
                    .foregroundStyle(UNColor.textPrimary)
                    .padding(.horizontal, UNSpacing.xl)

                CategoryGrid(categories: MockData.categories)
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
                    MiniAppCardHorizontal(app: app)
                }
            }
            .padding(.horizontal, UNSpacing.xl)
        }
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

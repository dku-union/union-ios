import SwiftUI
import ComposableArchitecture

// MARK: - Search View

struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>

    private let trendingKeywords = ["축제", "웨이팅", "스터디", "학식", "중고거래", "소개팅"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: UBSpacing.xxl) {
                    if store.query.isEmpty {
                        emptyState
                    } else if store.results.isEmpty && !store.isSearching {
                        noResultsView
                    } else {
                        searchResults
                    }
                }
                .padding(.top, UBSpacing.lg)
            }
            .background(UBColor.bgPrimary)
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
        VStack(alignment: .leading, spacing: UBSpacing.xxxl) {
            VStack(alignment: .leading, spacing: UBSpacing.lg) {
                Text("인기 검색어")
                    .font(.headline)
                    .foregroundStyle(UBColor.textPrimary)
                    .padding(.horizontal, UBSpacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: UBSpacing.sm) {
                        ForEach(trendingKeywords, id: \.self) { keyword in
                            Button {
                                store.query = keyword
                            } label: {
                                Text("#\(keyword)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(UBColor.brand)
                                    .padding(.horizontal, UBSpacing.lg)
                                    .padding(.vertical, UBSpacing.sm)
                                    .background(UBColor.brandLight)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, UBSpacing.xl)
                }
            }

            VStack(alignment: .leading, spacing: UBSpacing.lg) {
                Text("카테고리별 탐색")
                    .font(.headline)
                    .foregroundStyle(UBColor.textPrimary)
                    .padding(.horizontal, UBSpacing.xl)

                CategoryGrid(categories: MockData.categories)
            }
        }
    }

    // MARK: - Search Results

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: UBSpacing.lg) {
            Text("검색 결과 \(store.results.count)개")
                .font(.subheadline)
                .foregroundStyle(UBColor.textSecondary)
                .padding(.horizontal, UBSpacing.xl)

            VStack(spacing: UBSpacing.md) {
                ForEach(store.results) { app in
                    MiniAppCardHorizontal(app: app)
                }
            }
            .padding(.horizontal, UBSpacing.xl)
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: UBSpacing.lg) {
            Spacer().frame(height: 60)
            Text("🔍")
                .font(.system(size: 48))
            Text("검색 결과가 없어요")
                .font(.headline)
                .foregroundStyle(UBColor.textPrimary)
            Text("다른 키워드로 검색해보세요")
                .font(.subheadline)
                .foregroundStyle(UBColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

//
//  SearchView.swift
//  simalytics
//

import SwiftData
import SwiftUI

/// The Search tab. Browsing lives in Explore; this tab is for finding a title.
struct SearchView: View {
  var searchFocusTrigger = 0

  @Environment(Auth.self) private var auth
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  @Environment(\.modelContext) private var context
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage("searchResultsLayout") private var searchResultsLayout: ListLayout = .grid
  @Binding var searchText: String
  @Binding var searchCategory: SearchCategory
  @State private var isSearchPresented = false

  private let store = DiscoverStore.shared

  private var scopes: [SearchCategory] {
    SearchCategory.allCases.filter { !hideAnime || $0 != .anime }
  }

  var body: some View {
    if #available(iOS 26, *) {
      NavigationStack {
        searchContent
          .scrollDismissesKeyboard(.interactively)
          .searchable(text: $searchText, prompt: "Search Simkl")
          .searchScopes($searchCategory) {
            ForEach(scopes) { category in
              Text(category.rawValue).tag(category)
            }
          }
      }
    } else {
      NavigationStack { searchContent }
        .searchable(
          text: $searchText, isPresented: $isSearchPresented, placement: .automatic,
          prompt: "Search Simkl")
        .searchScopes($searchCategory) {
          ForEach(scopes) { category in
            Text(category.rawValue).tag(category)
          }
        }
        .onChange(of: searchFocusTrigger) {
          isSearchPresented = true
        }
    }
  }

  @ViewBuilder private var searchContent: some View {
    if auth.simklAccessToken.isEmpty {
      ContentUnavailableView {
        Label("Sign in to Simkl", systemImage: "lock.shield")
      } description: {
        Text("Sign in to Simkl to start searching.")
      }
    } else {
      Group {
        if searchText.isEmpty {
          SearchSuggestions(items: suggestions)
        } else {
          SearchResultsView(searchText: $searchText, searchCategory: $searchCategory)
        }
      }
      .navigationTitle("Search")
      .toolbar {
        if !searchText.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            LayoutToggleButton(layout: $searchResultsLayout)
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          if globalLoadingIndicator.isSyncing {
            ProgressView()
          }
        }
      }
      .task {
        // Suggestions show library badges and offer Plan to Watch too.
        DiscoverLibrary.shared.start(container: context.container)
        await store.load(hideAnime: hideAnime, todayOnly: true)
      }
    }
  }

  /// A few of today's top titles per type, so the empty field still offers a tap.
  private var suggestions: [DiscoverItem] {
    let types = ExploreFilter.all.types(hideAnime: hideAnime)
    return DiscoverRecipes.interleaved(
      types.map { type in Array((store.trending[type] ?? []).filter { !$0.isAdult }.prefix(4)) })
  }
}

private struct SearchSuggestions: View {
  let items: [DiscoverItem]

  var body: some View {
    if items.isEmpty {
      ContentUnavailableView(
        "Search Simkl", systemImage: "magnifyingglass",
        description: Text("Find movies, shows, and anime to track."))
    } else {
      List {
        Section {
          ForEach(items) { item in
            DiscoverItemLink(item: item, source: "suggestion") {
              HStack(spacing: 12) {
                CustomKFImage(
                  imageUrlString: item.posterURL, memoryCacheOnly: false, height: 60, width: 40)
                VStack(alignment: .leading, spacing: 2) {
                  Text(item.title)
                    .lineLimit(1)
                  Text([item.type.singularTitle, item.year.map(String.init)].compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
              }
              .contentShape(.rect)
            }
          }
        } header: {
          HStack(spacing: 6) {
            Text("Trending Today")
            SimklTag()
          }
          .accessibilityElement(children: .combine)
        }
      }
      .listStyle(.plain)
      .discoverLibrary(for: items)
    }
  }
}

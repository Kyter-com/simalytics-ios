//
//  SearchResults.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/1/25.
//

import Sentry
import SwiftUI

struct SearchResultsView: View {
  @Binding var searchText: String
  @Binding var searchCategory: SearchCategory
  @State private var searchResults: [SearchResultModel] = []
  @State private var debounceWorkItem: DispatchWorkItem?

  var body: some View {
    ScrollView {
      LazyVGrid(
        columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible()),
        ], spacing: 16
      ) {
        ForEach(searchResults, id: \.ids.simkl_id) { searchResult in
          NavigationLink(destination: destinationView(for: searchResult)) {
            VStack {
              if let poster = searchResult.poster {
                ZStack(alignment: .bottomLeading) {
                  CustomKFImage(
                    imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
                    memoryCacheOnly: true,
                    height: 147.62,
                    width: 100
                  )
                  if let year = searchResult.year {
                    YearOverlayTitle(year: year)
                  }
                }
              }
              ExploreTitle(title: searchResult.title)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding()
    }
    .onChange(of: searchText) { _, newValue in
      debounceSearch(newValue)
    }
    .onChange(of: searchCategory) { _, newValue in
      debounceSearch(searchText)
    }
  }

  private func destinationView(for searchResult: SearchResultModel) -> some View {
    switch searchResult.endpoint_type {
    case "tv":
      return AnyView(ShowDetailView())
    case "movies":
      return AnyView(MovieDetailView(simkl_id: searchResult.ids.simkl_id))
    case "anime":
      return AnyView(AnimeDetailView())
    default:
      return AnyView(Text("Unknown type"))
    }
  }

  private func debounceSearch(_ query: String) {
    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      Task {
        searchResults = await SearchResultsView.getSearchResults(
          searchText: query, searchType: searchCategory.rawValue.lowercased())
      }
    }

    debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
  }
}

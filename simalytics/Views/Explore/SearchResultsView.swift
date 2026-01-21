//
//  SearchResults.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/1/25.
//

import Sentry
import SwiftData
import SwiftUI

struct SearchResultsView: View {
  @Binding var searchText: String
  @Binding var searchCategory: SearchCategory
  @AppStorage("hideAnime") private var hideAnime = false
  @Environment(\.modelContext) private var context
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
        ForEach(searchResults.filter { !hideAnime || $0.endpoint_type != "anime" }, id: \.ids.simkl_id) { searchResult in
          NavigationLink(destination: {
            let type = searchResult.endpoint_type
            let id = searchResult.ids.simkl_id
            if type == "tv" {
              ShowDetailView(simkl_id: id)
            } else if type == "movies" {
              MovieDetailView(simkl_id: id)
            } else if type == "anime" {
              AnimeDetailView(simkl_id: id)
            }
          }) {
            VStack {
              if let poster = searchResult.poster {
                ZStack(alignment: .bottomLeading) {
                  CustomKFImage(
                    imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
                    memoryCacheOnly: true,
                    height: 147,
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
          .contextMenu {
            let urlType = searchResult.endpoint_type == "movies" ? "movies" : searchResult.endpoint_type
            ShareLink(
              item: URL(string: "https://simkl.com/\(urlType)/\(searchResult.ids.simkl_id)")!,
              subject: Text(searchResult.title),
              message: Text("Check out \(searchResult.title)!")
            ) {
              Label("Share", systemImage: "square.and.arrow.up")
            }
          } preview: {
            let mediaType = searchResult.endpoint_type == "movies" ? "movie" : searchResult.endpoint_type
            SmartPreviewCard(
              simklId: searchResult.ids.simkl_id,
              title: searchResult.title,
              year: searchResult.year,
              poster: searchResult.poster,
              mediaType: mediaType,
              localData: LocalDataLookup.lookup(simklId: searchResult.ids.simkl_id, mediaType: mediaType, context: context)
            )
          }
        }
      }
      .padding()
    }
    .onChange(of: searchText) { _, newValue in
      SearchResultsView.debounceSearch(
        query: newValue,
        searchCategory: searchCategory,
        debounceWorkItem: &debounceWorkItem
      ) { results in
        searchResults = results
      }
    }
    .onChange(of: searchCategory) { _, newValue in
      SearchResultsView.debounceSearch(
        query: searchText,
        searchCategory: newValue,
        debounceWorkItem: &debounceWorkItem
      ) { results in
        searchResults = results
      }
    }
  }
}

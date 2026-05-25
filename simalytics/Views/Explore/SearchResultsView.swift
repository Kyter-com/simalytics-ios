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
  @AppStorage("searchResultsLayout") private var layout: ListLayout = .grid
  @Environment(\.modelContext) private var context
  @State private var searchResults: [SearchResultModel] = []
  @State private var searchTask: Task<Void, Never>?

  private var visibleResults: [SearchResultModel] {
    searchResults.filter { !hideAnime || $0.endpoint_type != "anime" }
  }

  @ViewBuilder
  private func destinationView(for result: SearchResultModel) -> some View {
    let id = result.ids.simkl_id
    switch result.endpoint_type {
    case "tv": ShowDetailView(simkl_id: id)
    case "movies": MovieDetailView(simkl_id: id)
    case "anime": AnimeDetailView(simkl_id: id)
    default: EmptyView()
    }
  }

  @ViewBuilder
  private func contextMenu(for result: SearchResultModel) -> some View {
    let urlType = result.endpoint_type == "movies" ? "movies" : result.endpoint_type
    ShareLink(
      item: URL(string: "https://simkl.com/\(urlType)/\(result.ids.simkl_id)")!,
      subject: Text(result.title),
      message: Text("Check out \(result.title)!")
    ) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }

  @ViewBuilder
  private func previewCard(for result: SearchResultModel) -> some View {
    let mediaType = result.endpoint_type == "movies" ? "movie" : result.endpoint_type
    SmartPreviewCard(
      simklId: result.ids.simkl_id,
      title: result.title,
      year: result.year,
      poster: result.poster,
      mediaType: mediaType,
      localData: LocalDataLookup.lookup(simklId: result.ids.simkl_id, mediaType: mediaType, context: context)
    )
  }

  var body: some View {
    Group {
      if layout == .list {
        List(visibleResults, id: \.ids.simkl_id) { result in
          NavigationLink(destination: destinationView(for: result)) {
            HStack {
              CustomKFImage(
                imageUrlString: result.poster != nil
                  ? "\(SIMKL_CDN_URL)/posters/\(result.poster!)_m.jpg"
                  : nil,
                memoryCacheOnly: true,
                height: 118,
                width: 80
              )

              VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                  .font(.headline)
                  .lineLimit(2)

                if let year = result.year {
                  Text(String(year))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          .contextMenu {
            contextMenu(for: result)
          } preview: {
            previewCard(for: result)
          }
        }
        .listStyle(.inset)
      } else {
        ScrollView {
          LazyVGrid(
            columns: [
              GridItem(.flexible()),
              GridItem(.flexible()),
              GridItem(.flexible()),
            ], spacing: 16
          ) {
            ForEach(visibleResults, id: \.ids.simkl_id) { result in
              NavigationLink(destination: destinationView(for: result)) {
                VStack {
                  if let poster = result.poster {
                    ZStack(alignment: .bottomLeading) {
                      CustomKFImage(
                        imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
                        memoryCacheOnly: true,
                        height: 147,
                        width: 100
                      )
                      if let year = result.year {
                        YearOverlayTitle(year: year)
                      }
                    }
                  }
                  ExploreTitle(title: result.title)
                }
              }
              .buttonStyle(.plain)
              .contextMenu {
                contextMenu(for: result)
              } preview: {
                previewCard(for: result)
              }
            }
          }
          .padding()
        }
      }
    }
    .onChange(of: searchText) { _, newValue in
      SearchResultsView.debounceSearch(
        query: newValue,
        searchCategory: searchCategory,
        previousTask: &searchTask
      ) { results in
        searchResults = results
      }
    }
    .onChange(of: searchCategory) { _, newValue in
      SearchResultsView.debounceSearch(
        query: searchText,
        searchCategory: newValue,
        previousTask: &searchTask
      ) { results in
        searchResults = results
      }
    }
  }
}

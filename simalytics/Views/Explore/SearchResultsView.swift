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
  @State private var viewModel = SearchResultsViewModel()
  @State private var retryCount = 0
  @State private var localSnapshots = LocalMediaSnapshots()

  private var searchRequest: MediaSearchRequest {
    MediaSearchRequest(
      query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
      category: searchCategory, hideAnime: hideAnime, retry: retryCount)
  }

  private var visibleResults: [SearchResultModel] {
    viewModel.results.filter { !hideAnime || $0.endpoint_type != "anime" }
  }

  private var localSnapshotRequest: LocalMediaSnapshots.Request {
    LocalMediaSnapshots.Request(
      movieIDs: visibleResults.filter { $0.endpoint_type == "movies" }.map { $0.ids.simkl_id },
      showIDs: visibleResults.filter { $0.endpoint_type == "tv" }.map { $0.ids.simkl_id },
      animeIDs: visibleResults.filter { $0.endpoint_type == "anime" }.map { $0.ids.simkl_id }
    )
  }

  private func refreshLocalSnapshots() {
    localSnapshots = LocalMediaSnapshots.fetch(localSnapshotRequest, context: context)
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
      localData: localSnapshots.data(simklID: result.ids.simkl_id, mediaType: mediaType)
    )
  }

  /// Earlier results stay visible while a new query loads.
  private var isSearching: Bool { viewModel.completedRequest != searchRequest }

  var body: some View {
    Group {
      if isSearching && visibleResults.isEmpty {
        ProgressView("Searching…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if !isSearching, let errorMessage = viewModel.errorMessage {
        ContentUnavailableView {
          Label("Search Unavailable", systemImage: "wifi.exclamationmark")
        } description: {
          Text(errorMessage)
        } actions: {
          Button("Try Again") { retryCount += 1 }
        }
      } else if visibleResults.isEmpty {
        ContentUnavailableView.search(text: searchRequest.query)
      } else if layout == .list {
        List(visibleResults, id: \.ids.simkl_id) { result in
          MediaDetailLink(sourceID: "search-\(result.ids.simkl_id)") {
            destinationView(for: result)
          } label: {
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
          LazyVGrid(columns: posterGridColumns, spacing: 16) {
            ForEach(visibleResults, id: \.ids.simkl_id) { result in
              MediaDetailLink(sourceID: "search-\(result.ids.simkl_id)") {
                destinationView(for: result)
              } label: {
                PosterGridCell(title: result.title, poster: result.poster, year: result.year)
              }
              .buttonStyle(.plain)
              .contextMenu {
                contextMenu(for: result)
              } preview: {
                previewCard(for: result)
              }
            }
          }
          .padding(.horizontal, posterGridHorizontalPadding)
          .padding(.vertical, 8)
        }
      }
    }
    .toolbar {
      if isSearching && !visibleResults.isEmpty {
        ToolbarItem(placement: .topBarTrailing) {
          ProgressView()
            .accessibilityLabel("Searching")
        }
      }
    }
    .task(id: localSnapshotRequest) {
      refreshLocalSnapshots()
    }
    .onReceive(NotificationCenter.default.publisher(for: .localMediaSnapshotsDidChange)) { _ in
      refreshLocalSnapshots()
    }
    .task(id: searchRequest) {
      await viewModel.search(searchRequest)
    }
  }
}

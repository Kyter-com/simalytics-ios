//
//  ExploreView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import Kingfisher
import SwiftData
import SwiftUI

struct ExploreView: View {
  var searchFocusTrigger = 0

  @Environment(Auth.self) private var auth
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  @Environment(\.modelContext) private var context
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage("searchResultsLayout") private var searchResultsLayout: ListLayout = .grid
  @State private var sdTrendingShows: [V1.TrendingShows] = []
  @State private var sdTrendingMovies: [V1.TrendingMovies] = []
  @State private var sdTrendingAnimes: [V1.TrendingAnimes] = []
  @Binding var searchText: String
  @Binding var searchCategory: SearchCategory
  @State private var isSearchPresented = false
  @ScaledMetric(relativeTo: .subheadline) private var shelfTitleHeight: CGFloat = 44
  @State private var localSnapshots = LocalMediaSnapshots()

  private var localSnapshotRequest: LocalMediaSnapshots.Request {
    LocalMediaSnapshots.Request(
      movieIDs: sdTrendingMovies.map(\.simkl),
      showIDs: sdTrendingShows.map(\.simkl),
      animeIDs: hideAnime ? [] : sdTrendingAnimes.map(\.simkl)
    )
  }

  private func refreshLocalSnapshots() {
    localSnapshots = LocalMediaSnapshots.fetch(localSnapshotRequest, context: context)
  }

  private func fetchData() {
    do {
      sdTrendingMovies = try context.fetch(
        FetchDescriptor<V1.TrendingMovies>(sortBy: [
          SortDescriptor(\V1.TrendingMovies.order, order: .forward)
        ]))
      sdTrendingShows = try context.fetch(
        FetchDescriptor<V1.TrendingShows>(sortBy: [
          SortDescriptor(\V1.TrendingShows.order, order: .forward)
        ]))
      sdTrendingAnimes = try context.fetch(
        FetchDescriptor<V1.TrendingAnimes>(sortBy: [
          SortDescriptor(\V1.TrendingAnimes.order, order: .forward)
        ]))
    } catch {
      sdTrendingMovies = []
      sdTrendingShows = []
      sdTrendingAnimes = []
    }
  }

  var body: some View {
    if #available(iOS 26, *) {
      NavigationStack {
        exploreContent
          .scrollDismissesKeyboard(.interactively)
          .searchable(text: $searchText, prompt: "Search Simkl")
          .searchScopes($searchCategory) {
            ForEach(SearchCategory.allCases.filter { !hideAnime || $0 != .anime }) { category in
              Text(category.rawValue).tag(category)
            }
          }
      }
    } else {
      NavigationStack { exploreContent }
        .searchable(text: $searchText, isPresented: $isSearchPresented, placement: .automatic)
        .searchScopes($searchCategory) {
          ForEach(SearchCategory.allCases.filter { !hideAnime || $0 != .anime }) { category in
            Text(category.rawValue).tag(category)
          }
        }
        .onChange(of: searchFocusTrigger) {
          isSearchPresented = true
        }
    }
  }

  @ViewBuilder private var exploreContent: some View {
    if auth.simklAccessToken.isEmpty {
      ContentUnavailableView {
        Label("Sign in to Simkl", systemImage: "lock.shield")
      } description: {
        Text("Sign in to Simkl to start searching.")
      }
    } else {
      VStack {
        if !searchText.isEmpty {
          SearchResultsView(searchText: $searchText, searchCategory: $searchCategory)
        } else {
          ScrollView {
            LazyVStack(alignment: .leading) {
              Group {
                ExploreGroupHeader(title: "Trending Shows") {
                  TrendingListView(category: .tv)
                }
                ScrollView(.horizontal) {
                  LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(sdTrendingShows, id: \.simkl) { showItem in
                      MediaDetailLink(sourceID: "show-\(showItem.simkl)") {
                        ShowDetailView(simkl_id: showItem.simkl)
                      } label: {
                        VStack {
                          CustomKFImage(
                            imageUrlString: showItem.poster != nil
                              ? "\(SIMKL_CDN_URL)/posters/\(showItem.poster!)_m.jpg"
                              : nil,
                            memoryCacheOnly: false,
                            height: 147,
                            width: 100
                          )
                          ExploreTitle(title: showItem.title ?? "")
                        }
                      }
                      .buttonStyle(.plain)
                      .contextMenu {
                        ShareLink(
                          item: URL(string: "https://simkl.com/tv/\(showItem.simkl)")!,
                          subject: Text(showItem.title ?? ""),
                          message: Text("Check out \(showItem.title ?? "this show")!")
                        ) {
                          Label("Share", systemImage: "square.and.arrow.up")
                        }
                      } preview: {
                        SmartPreviewCard(
                          simklId: showItem.simkl,
                          title: showItem.title ?? "Unknown",
                          year: nil,
                          poster: showItem.poster,
                          mediaType: "tv",
                          localData: localSnapshots.data(simklID: showItem.simkl, mediaType: "tv")
                        )
                      }
                    }
                  }
                  .padding([.leading, .trailing, .bottom])
                }
                .frame(height: 174 + shelfTitleHeight)
              }

              Group {
                ExploreGroupHeader(title: "Trending Movies") {
                  TrendingListView(category: .movies)
                }
                ScrollView(.horizontal) {
                  LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(sdTrendingMovies, id: \.simkl) { movieItem in
                      MediaDetailLink(sourceID: "movie-\(movieItem.simkl)") {
                        MovieDetailView(simkl_id: movieItem.simkl)
                      } label: {
                        VStack {
                          CustomKFImage(
                            imageUrlString: movieItem.poster != nil
                              ? "\(SIMKL_CDN_URL)/posters/\(movieItem.poster!)_m.jpg"
                              : nil,
                            memoryCacheOnly: false,
                            height: 150,
                            width: 100
                          )
                          ExploreTitle(title: movieItem.title ?? "")
                        }
                      }
                      .buttonStyle(.plain)
                      .contextMenu {
                        ShareLink(
                          item: URL(string: "https://simkl.com/movies/\(movieItem.simkl)")!,
                          subject: Text(movieItem.title ?? ""),
                          message: Text("Check out \(movieItem.title ?? "this movie")!")
                        ) {
                          Label("Share", systemImage: "square.and.arrow.up")
                        }
                      } preview: {
                        SmartPreviewCard(
                          simklId: movieItem.simkl,
                          title: movieItem.title ?? "Unknown",
                          year: nil,
                          poster: movieItem.poster,
                          mediaType: "movie",
                          localData: localSnapshots.data(
                            simklID: movieItem.simkl, mediaType: "movie")
                        )
                      }
                    }
                  }
                  .padding([.leading, .trailing, .bottom])
                }
                .frame(height: 174 + shelfTitleHeight)
              }

              if !hideAnime {
                Group {
                  ExploreGroupHeader(title: "Trending Anime") {
                    TrendingListView(category: .anime)
                  }
                  ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 16) {
                      ForEach(sdTrendingAnimes, id: \.simkl) { animeItem in
                        MediaDetailLink(sourceID: "anime-\(animeItem.simkl)") {
                          AnimeDetailView(simkl_id: animeItem.simkl)
                        } label: {
                          VStack {
                            CustomKFImage(
                              imageUrlString: animeItem.poster != nil
                                ? "\(SIMKL_CDN_URL)/posters/\(animeItem.poster!)_m.jpg"
                                : nil,
                              memoryCacheOnly: false,
                              height: 150,
                              width: 100
                            )
                            ExploreTitle(title: animeItem.title ?? "")
                          }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                          ShareLink(
                            item: URL(string: "https://simkl.com/anime/\(animeItem.simkl)")!,
                            subject: Text(animeItem.title ?? ""),
                            message: Text("Check out \(animeItem.title ?? "this anime")!")
                          ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                          }
                        } preview: {
                          SmartPreviewCard(
                            simklId: animeItem.simkl,
                            title: animeItem.title ?? "Unknown",
                            year: nil,
                            poster: animeItem.poster,
                            mediaType: "anime",
                            localData: localSnapshots.data(
                              simklID: animeItem.simkl, mediaType: "anime")
                          )
                        }
                      }
                    }
                    .padding([.leading, .trailing, .bottom])
                  }
                  .frame(height: 174 + shelfTitleHeight)
                }
              }
            }
          }
        }
      }
      .navigationTitle("Explore")
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
        fetchData()
      }
      .task(id: localSnapshotRequest) {
        refreshLocalSnapshots()
      }
      .onReceive(NotificationCenter.default.publisher(for: .localMediaSnapshotsDidChange)) { _ in
        fetchData()
        refreshLocalSnapshots()
      }
    }
  }
}

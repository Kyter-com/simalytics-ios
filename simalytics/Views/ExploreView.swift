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
  @EnvironmentObject private var auth: Auth
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  @Environment(\.modelContext) private var context
  @AppStorage("hideAnime") private var hideAnime = false
  @State private var sdTrendingShows: [V1.TrendingShows] = []
  @State private var sdTrendingMovies: [V1.TrendingMovies] = []
  @State private var sdTrendingAnimes: [V1.TrendingAnimes] = []
  @State private var searchText: String = ""
  @State private var searchCategory: SearchCategory = .all

  private func fetchData() {
    do {
      sdTrendingMovies = try context.fetch(FetchDescriptor<V1.TrendingMovies>(sortBy: [SortDescriptor(\V1.TrendingMovies.order, order: .forward)]))
      sdTrendingShows = try context.fetch(FetchDescriptor<V1.TrendingShows>(sortBy: [SortDescriptor(\V1.TrendingShows.order, order: .forward)]))
      sdTrendingAnimes = try context.fetch(FetchDescriptor<V1.TrendingAnimes>(sortBy: [SortDescriptor(\V1.TrendingAnimes.order, order: .forward)]))
    } catch {
      sdTrendingMovies = []
      sdTrendingShows = []
      sdTrendingAnimes = []
    }
  }

  var body: some View {
    if auth.simklAccessToken.isEmpty {
      ContentUnavailableView {
        Label("Sign in to Simkl", systemImage: "lock.shield")
      } description: {
        Text("Sign in to Simkl to start searching.")
      }
    } else {
      NavigationStack {
        VStack {
          if !searchText.isEmpty {
            SearchResultsView(searchText: $searchText, searchCategory: $searchCategory)
          } else {
            ScrollView {
              VStack(alignment: .leading) {
                Group {
                  ExploreGroupTitle(title: "Trending Shows")
                  ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 16) {
                      ForEach(sdTrendingShows, id: \.simkl) { showItem in
                        NavigationLink(
                          destination: ShowDetailView(simkl_id: showItem.simkl)
                        ) {
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
                            localData: LocalDataLookup.lookup(simklId: showItem.simkl, mediaType: "tv", context: context)
                          )
                        }
                      }
                    }
                    .padding([.leading, .trailing, .bottom])
                  }
                }

                Group {
                  ExploreGroupTitle(title: "Trending Movies")
                  ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 16) {
                      ForEach(sdTrendingMovies, id: \.simkl) { movieItem in
                        NavigationLink(
                          destination: MovieDetailView(simkl_id: movieItem.simkl)
                        ) {
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
                            localData: LocalDataLookup.lookup(simklId: movieItem.simkl, mediaType: "movie", context: context)
                          )
                        }
                      }
                    }
                    .padding([.leading, .trailing, .bottom])
                  }
                }

                if !hideAnime {
                  Group {
                    ExploreGroupTitle(title: "Trending Animes")
                    ScrollView(.horizontal, showsIndicators: true) {
                      HStack(spacing: 16) {
                        ForEach(sdTrendingAnimes, id: \.simkl) { animeItem in
                          NavigationLink(
                            destination: AnimeDetailView(simkl_id: animeItem.simkl)
                          ) {
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
                              localData: LocalDataLookup.lookup(simklId: animeItem.simkl, mediaType: "anime", context: context)
                            )
                          }
                        }
                      }
                      .padding([.leading, .trailing, .bottom])
                    }
                  }
                }
                Spacer()
              }
            }
          }
        }
        .navigationTitle("Explore")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            if globalLoadingIndicator.isSyncing {
              ProgressView()
            }
          }
        }
      }
      .onAppear {
        fetchData()
      }
      .searchable(text: $searchText, placement: .automatic)
      .searchScopes($searchCategory) {
        ForEach(SearchCategory.allCases.filter { !hideAnime || $0 != .anime }) { category in
          Text(category.rawValue).tag(category)
        }
      }
    }
  }
}

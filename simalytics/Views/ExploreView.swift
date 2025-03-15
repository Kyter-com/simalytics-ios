//
//  ExploreView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import Kingfisher
import SwiftUI

struct ExploreView: View {
  @EnvironmentObject private var auth: Auth
  @State private var trendingShows: [TrendingShowModel] = []
  @State private var trendingMovies: [TrendingMovieModel] = []
  @State private var trendingAnimes: [TrendingAnimeModel] = []
  @State private var searchText: String = ""
  @State private var searchCategory: SearchCategory = .all

  var body: some View {
    NavigationView {
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
                    ForEach(trendingShows, id: \.ids.simkl_id) { showItem in
                      VStack {
                        CustomKFImage(
                          imageUrlString:
                            "\(SIMKL_CDN_URL)/posters/\(showItem.poster)_m.jpg",
                          memoryCacheOnly: true,
                          height: 147.62,
                          width: 100
                        )
                        ExploreTitle(title: showItem.title)
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
                    ForEach(trendingMovies, id: \.ids.simkl_id) { movieItem in
                      NavigationLink(
                        destination: MovieDetailView(simkl_id: movieItem.ids.simkl_id)
                      ) {
                        VStack {
                          CustomKFImage(
                            imageUrlString:
                              "\(SIMKL_CDN_URL)/posters/\(movieItem.poster)_m.jpg",
                            memoryCacheOnly: true,
                            height: 147.62,
                            width: 100
                          )
                          ExploreTitle(title: movieItem.title)
                        }
                      }
                      .buttonStyle(.plain)
                    }
                  }
                  .padding([.leading, .trailing, .bottom])
                }
              }

              Group {
                ExploreGroupTitle(title: "Trending Animes")
                ScrollView(.horizontal, showsIndicators: true) {
                  HStack(spacing: 16) {
                    ForEach(trendingAnimes, id: \.ids.simkl_id) { animeItem in
                      VStack {
                        CustomKFImage(
                          imageUrlString:
                            "\(SIMKL_CDN_URL)/posters/\(animeItem.poster)_m.jpg",
                          memoryCacheOnly: true,
                          height: 147.62,
                          width: 100
                        )
                        ExploreTitle(title: animeItem.title)
                      }
                    }
                  }
                  .padding([.leading, .trailing, .bottom])
                }
              }
              Spacer()
            }
          }
        }
      }
      .navigationTitle("Explore")
    }
    .onAppear {
      Task {
        trendingShows = await ExploreView.getTrendingShows()
        trendingMovies = await ExploreView.getTrendingMovies()
        trendingAnimes = await ExploreView.getTrendingAnimes()
      }
    }
    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    .searchScopes($searchCategory) {
      ForEach(SearchCategory.allCases) { category in
        Text(category.rawValue).tag(category)
      }
    }
  }

  //  private func getMovieSyncItems() async {
  //    do {
  //      var movieSyncURLComponents = URLComponents()
  //      movieSyncURLComponents.scheme = "https"
  //      movieSyncURLComponents.host = "api.simkl.com"
  //      movieSyncURLComponents.path = "/sync/all-items/movies"
  //
  //      var request = URLRequest(url: movieSyncURLComponents.url!)
  //      request.httpMethod = "GET"
  //      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  //      request.setValue(
  //        "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9",
  //        forHTTPHeaderField: "simkl-api-key")
  //      request.setValue("Bearer \(auth.simklAccessToken)", forHTTPHeaderField: "Authorization")
  //      let (data, response) = try await URLSession.shared.data(for: request)
  //      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
  //        movieSyncItems = []
  //        return
  //      }
  //      let decoder = JSONDecoder()
  //      let res = try decoder.decode([MovieSyncItemModel].self, from: data)
  //      if res.count > 0 {
  //        movieSyncItems = res
  //      } else {
  //        movieSyncItems = []
  //      }
  //    } catch {
  //      movieSyncItems = []
  //      return
  //    }
  //  }
}

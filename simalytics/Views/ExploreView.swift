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
                      NavigationLink(
                        destination: ShowDetailView(simkl_id: showItem.ids.simkl_id)
                      ) {
                        VStack {
                          CustomKFImage(
                            imageUrlString:
                              "\(SIMKL_CDN_URL)/posters/\(showItem.poster)_m.jpg",
                            memoryCacheOnly: true,
                            height: 147,
                            width: 100
                          )
                          ExploreTitle(title: showItem.title)
                        }
                      }
                      .buttonStyle(.plain)
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
                            imageUrlString: movieItem.poster != nil
                              ? "\(SIMKL_CDN_URL)/posters/\(movieItem.poster!)_m.jpg"
                              : NO_IMAGE_URL,
                            memoryCacheOnly: true,
                            height: 150,
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
                      NavigationLink(
                        destination: AnimeDetailView(simkl_id: animeItem.ids.simkl_id)
                      ) {
                        VStack {
                          CustomKFImage(
                            imageUrlString:
                              "\(SIMKL_CDN_URL)/posters/\(animeItem.poster)_m.jpg",
                            memoryCacheOnly: true,
                            height: 150,
                            width: 100
                          )
                          ExploreTitle(title: animeItem.title)
                        }
                      }
                      .buttonStyle(.plain)
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
}

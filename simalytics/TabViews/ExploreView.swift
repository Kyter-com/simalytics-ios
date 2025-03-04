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
  @State private var trendingShows: [TrendingShow] = []
  @State private var trendingMovies: [TrendingMovie] = []
  @State private var trendingAnimes: [TrendingAnime] = []
  @State private var searchText: String = ""
  @State private var isSearching: Bool = false
  @State private var searchCategory: SearchCategory = .all

  var body: some View {
    NavigationView {
      VStack {
        if isSearching {
          SearchResults(searchText: $searchText, searchCategory: $searchCategory)
        } else {
          ScrollView {
            VStack(alignment: .leading) {
              if trendingShows.isEmpty && trendingMovies.isEmpty && trendingAnimes.isEmpty {
                ContentUnavailableView {
                  ProgressView()
                } description: {
                  Text("Loading Trending Data")
                }
                .onAppear {
                  Task {
                    await getTrendingShows()
                    await getTrendingMovies()
                    await getTrendingAnimes()
                  }
                }
              } else {
                Group {
                  Text("Trending Shows")
                    .font(.title2)
                    .bold()
                    .padding([.top, .leading])
                  ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 16) {
                      ForEach(trendingShows, id: \.ids.simkl_id) { showItem in
                        VStack {
                          KFImage(
                            URL(
                              string:
                                "https://wsrv.nl/?url=https://simkl.in/posters/\(showItem.poster)_m.jpg"
                            )
                          )
                          .placeholder {
                            ProgressView()
                          }
                          .resizable()
                          .serialize(as: .JPEG)
                          .frame(width: 100, height: 147.62)
                          .clipShape(RoundedRectangle(cornerRadius: 8))
                          .background(
                            RoundedRectangle(cornerRadius: 8)
                              .fill(Color(UIColor.systemBackground))
                          )
                          Text(showItem.title)
                            .font(.subheadline)
                            .padding(.top, 4)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 100)
                        }
                      }
                    }
                    .padding([.leading, .trailing, .bottom])
                  }
                }

                Group {
                  Text("Trending Movies")
                    .font(.title2)
                    .bold()
                    .padding([.top, .leading])
                  ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 16) {
                      ForEach(trendingMovies, id: \.ids.simkl_id) { movieItem in
                        VStack {
                          KFImage(
                            URL(
                              string:
                                "https://wsrv.nl/?url=https://simkl.in/posters/\(movieItem.poster)_m.jpg"
                            )
                          )
                          .placeholder {
                            ProgressView()
                          }
                          .resizable()
                          .serialize(as: .JPEG)
                          .frame(width: 100, height: 147.62)
                          .clipShape(RoundedRectangle(cornerRadius: 8))
                          .background(
                            RoundedRectangle(cornerRadius: 8)
                              .fill(Color(UIColor.systemBackground))
                          )
                          Text(movieItem.title)
                            .font(.subheadline)
                            .padding(.top, 4)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 100)
                        }
                      }
                    }
                    .padding([.leading, .trailing, .bottom])
                  }
                }

                Group {
                  Text("Trending Animes")
                    .font(.title2)
                    .bold()
                    .padding([.top, .leading])
                  ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 16) {
                      ForEach(trendingAnimes, id: \.ids.simkl_id) { animeItem in
                        VStack {
                          KFImage(
                            URL(
                              string:
                                "https://wsrv.nl/?url=https://simkl.in/posters/\(animeItem.poster)_m.jpg"
                            )
                          )
                          .placeholder {
                            ProgressView()
                          }
                          .resizable()
                          .serialize(as: .JPEG)
                          .frame(width: 100, height: 147.62)
                          .clipShape(RoundedRectangle(cornerRadius: 8))
                          .background(
                            RoundedRectangle(cornerRadius: 8)
                              .fill(Color(UIColor.systemBackground))
                          )
                          Text(animeItem.title)
                            .font(.subheadline)
                            .padding(.top, 4)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(width: 100)
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
      }
      .searchable(text: $searchText, placement: .automatic)
      .searchScopes($searchCategory) {
        ForEach(SearchCategory.allCases) { category in
          Text(category.rawValue).tag(category)
        }
      }
      .onChange(of: searchText) { _oldValue, newValue in
        isSearching = !newValue.isEmpty
      }
      .onSubmit(of: .search) {
        isSearching = true
      }
      .navigationTitle("Explore")
    }
  }

  private func getTrendingShows() async {
    do {
      var TrendingShowsURLComponents = URLComponents()
      TrendingShowsURLComponents.scheme = "https"
      TrendingShowsURLComponents.host = "api.simkl.com"
      TrendingShowsURLComponents.path = "/tv/trending"
      TrendingShowsURLComponents.queryItems = [
        URLQueryItem(name: "extended", value: "overview,metadata,tmdb,genres,trailer"),
        URLQueryItem(
          name: "client_id",
          value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
      ]
      var request = URLRequest(url: TrendingShowsURLComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        trendingShows = []
        return
      }
      let decoder = JSONDecoder()
      let showsResponse = try decoder.decode([TrendingShow].self, from: data)
      if showsResponse.count > 0 {
        trendingShows = showsResponse
      } else {
        trendingShows = []
      }
    } catch {
      trendingShows = []
      return
    }
  }

  private func getTrendingMovies() async {
    do {
      var TrendingMoviesURLComponents = URLComponents()
      TrendingMoviesURLComponents.scheme = "https"
      TrendingMoviesURLComponents.host = "api.simkl.com"
      TrendingMoviesURLComponents.path = "/movies/trending"
      TrendingMoviesURLComponents.queryItems = [
        URLQueryItem(name: "extended", value: "overview,theater,metadata,tmdb,genres"),
        URLQueryItem(
          name: "client_id",
          value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
      ]
      var request = URLRequest(url: TrendingMoviesURLComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        trendingMovies = []
        return
      }
      let decoder = JSONDecoder()
      let moviesResponse = try decoder.decode([TrendingMovie].self, from: data)
      if moviesResponse.count > 0 {
        trendingMovies = moviesResponse
      } else {
        trendingMovies = []
      }
    } catch {
      trendingMovies = []
      return
    }
  }

  private func getTrendingAnimes() async {
    do {
      var TrendingAnimesURLComponents = URLComponents()
      TrendingAnimesURLComponents.scheme = "https"
      TrendingAnimesURLComponents.host = "api.simkl.com"
      TrendingAnimesURLComponents.path = "/anime/trending"
      TrendingAnimesURLComponents.queryItems = [
        URLQueryItem(name: "extended", value: "overview,metadata,tmdb,genres,trailer"),
        URLQueryItem(
          name: "client_id",
          value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
      ]
      var request = URLRequest(url: TrendingAnimesURLComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        trendingAnimes = []
        return
      }
      let decoder = JSONDecoder()
      let animesResponse = try decoder.decode([TrendingAnime].self, from: data)
      if animesResponse.count > 0 {
        trendingAnimes = animesResponse
      } else {
        trendingAnimes = []
      }
    } catch {
      print(error)
      trendingAnimes = []
      return
    }
  }
}

#Preview {
  ExploreView()
    .environmentObject(Auth())
}

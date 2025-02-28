//
//  ExploreView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct ExploreView: View {
  @EnvironmentObject private var auth: Auth
  @State private var trendingShows: [TrendingShow] = []

  var body: some View {
    NavigationView {
      VStack {
        if trendingShows.isEmpty {
          ContentUnavailableView {
            ProgressView()
          } description: {
            Text("Give us a second to load trending data!")
          }
          .onAppear {
            Task {
              await getTrendingShows()
            }
          }
        } else {
          List(trendingShows, id: \.ids.simkl_id) { show in
            Text("Show Name: \(show.title)")
          }
        }
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
}

#Preview {
  ExploreView()
    .environmentObject(Auth())
}

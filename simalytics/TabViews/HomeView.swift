//
//  HomeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import Kingfisher
import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var auth: Auth
  @State private var shows: [Show] = []

  var body: some View {
    NavigationView {
      List(shows, id: \.show.ids.simkl) { showItem in
        HStack {
          KFImage(
            URL(
              string: "https://wsrv.nl/?url=https://simkl.in/posters/\(showItem.show.poster)_c.jpg")
          )
          .placeholder {
            ProgressView()
          }
          .resizable()
          .roundCorner(
            radius: .widthFraction(0.1)
          )
          .serialize(as: .JPEG)
          .frame(width: 84, height: 124)

          VStack(alignment: .leading) {
            Text(showItem.show.title)
              .font(.headline)
              .padding(.top, 8)
            if let title = showItem.next_to_watch_info?.title {
              Text(title)
                .font(.subheadline)
            }
            Spacer()
            if let season = showItem.next_to_watch_info?.season {
              Text("Season \(season)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            if let episode = showItem.next_to_watch_info?.episode {
              Text("Episode \(episode)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
          }
        }
      }
      .task {
        do {
          if !auth.simklAccessToken.isEmpty {
            var UpNextURLComponents = URLComponents()
            UpNextURLComponents.scheme = "https"
            UpNextURLComponents.host = "api.simkl.com"
            UpNextURLComponents.path = "/sync/all-items/shows/watching"
            UpNextURLComponents.queryItems = [
              URLQueryItem(name: "episode_watched_at", value: "yes"),
              URLQueryItem(name: "memos", value: "yes"),
              URLQueryItem(name: "next_watch_info", value: "yes"),
            ]
            var request = URLRequest(url: UpNextURLComponents.url!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(
              "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9",
              forHTTPHeaderField: "simkl-api-key")
            request.setValue("Bearer \(auth.simklAccessToken)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
              shows = []
              return
            }

            let decoder = JSONDecoder()
            let showsResponse = try decoder.decode(ShowsResponse.self, from: data)
            let filteredShows = showsResponse.shows.filter {
              $0.next_to_watch_info?.title?.isEmpty == false
            }
            if filteredShows.count > 0 {
              shows = filteredShows
            } else {
              shows = []
            }
          } else {
            shows = []
          }
        } catch {
          shows = []
        }
      }
      .navigationTitle("Home")
    }
  }
}

#Preview {
  HomeView()
}

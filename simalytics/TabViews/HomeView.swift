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
  @State private var searchText: String = ""
  @State private var showErrorAlert = false

  var filteredShows: [Show] {
    if searchText.isEmpty {
      return shows
    } else {
      return shows.filter { show in
        show.show.title.localizedCaseInsensitiveContains(searchText)
          || (show.next_to_watch_info?.title?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    }
  }

  var body: some View {
    NavigationView {
      List(filteredShows, id: \.show.ids.simkl) { showItem in
        HStack {
          KFImage(
            URL(
              string: "https://wsrv.nl/?url=https://simkl.in/posters/\(showItem.show.poster)_c.jpg")
          )
          .placeholder {
            ProgressView()
          }
          .resizable()
          .serialize(as: .JPEG)
          .frame(width: 75, height: 110.71)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(UIColor.systemBackground))
          )

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
        .swipeActions(edge: .trailing) {
          Button {
            Task {
              await markAsWatched(show: showItem)
            }
          } label: {
            Label("Watched", systemImage: "checkmark.circle")
          }
          .tint(.green)
        }
      }
      .searchable(text: $searchText, placement: .automatic)
      .task {
        await fetchShows()
      }
      .navigationTitle("Up Next")
      .alert("Error Marking as Watched", isPresented: $showErrorAlert) {
        Button("OK", role: .cancel) {}
        // TODO: Save to Sentry
      } message: {
        Text("We've been alerted of the error. Please try again later.")
      }
    }
  }

  private func markAsWatched(show: Show) async {
    do {
      var MarkWatchedURLComponents = URLComponents()
      MarkWatchedURLComponents.scheme = "https"
      MarkWatchedURLComponents.host = "api.simkl.com"
      MarkWatchedURLComponents.path = "/sync/history"

      var request = URLRequest(url: MarkWatchedURLComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(
        "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9",
        forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(auth.simklAccessToken)", forHTTPHeaderField: "Authorization")

      let formatter = ISO8601DateFormatter()
      let dateString = formatter.string(from: Date())
      let body: [String: Any] = [
        "shows": [
          [
            "title": show.show.title,
            "ids": [
              "simkl": show.show.ids.simkl
            ],
            "seasons": [
              [
                "number": show.next_to_watch_info?.season ?? 0,
                "episodes": [
                  [
                    "number": show.next_to_watch_info?.episode ?? 0,
                    "watched_at": dateString,
                  ]
                ],
              ]
            ],
          ]
        ]
      ]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201
      else {
        showErrorAlert = true
        return
      }
      await fetchShows()
      return
    } catch {
      showErrorAlert = true
      return
    }
  }

  private func fetchShows() async {
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
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
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
}

#Preview {
  HomeView()
    .environmentObject(Auth())
}

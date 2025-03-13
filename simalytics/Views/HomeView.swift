//
//  HomeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import Kingfisher
import Sentry
import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var auth: Auth
  @State private var viewModel = ViewModel()
  @State private var shows: [UpNextShowModel_show] = []
  @State private var showErrorAlert = false
  @State private var isFetching = true

  var filteredShows: [UpNextShowModel_show] {
    if viewModel.searchText.isEmpty {
      return shows
    } else {
      return shows.filter { show in
        show.show.title.localizedCaseInsensitiveContains(viewModel.searchText)
          || (show.next_to_watch_info?.title?.localizedCaseInsensitiveContains(viewModel.searchText)
            ?? false)
      }
    }
  }

  var body: some View {
    NavigationView {
      if auth.simklAccessToken.isEmpty {
        ContentUnavailableView {
          Label("Not logged in to Simkl", systemImage: "person.badge.shield.exclamationmark")
        } description: {
          Text("Go to Settings to log in to Simkl!")
        }
        .navigationTitle("Up Next")
      } else {
        Group {
          if isFetching {
            ProgressView("Fetching Shows...")
          } else if filteredShows.isEmpty {
            ContentUnavailableView {
              Label("No shows to display", systemImage: "tv.slash")
            } description: {
              Text("Try refreshing or adding shows to your watchlist.")
            }
          } else {
            List(filteredShows, id: \.show.ids.simkl) { showItem in
              HStack {
                // TODO: Const image urls
                CustomKFImage(
                  imageUrlString:
                    "https://wsrv.nl/?url=https://simkl.in/posters/\(showItem.show.poster)_m.jpg",
                  memoryCacheOnly: false,
                  height: 110.71,
                  width: 75
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
          }
        }
        .searchable(text: $viewModel.searchText, placement: .automatic)
        .refreshable {
          await fetchShows()
        }
        .task {
          await fetchShows()
        }
        .navigationTitle("Up Next")
        .alert("Error Marking as Watched", isPresented: $showErrorAlert) {
          Button("OK", role: .cancel) {}
        } message: {
          Text("We've been alerted of the error. Please try again later.")
        }
      }
    }
  }

  private func markAsWatched(show: UpNextShowModel_show) async {
    do {
      var markWatchedURLComponents = URLComponents()
      markWatchedURLComponents.scheme = "https"
      markWatchedURLComponents.host = "api.simkl.com"
      markWatchedURLComponents.path = "/sync/history"

      var request = URLRequest(url: markWatchedURLComponents.url!)
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
        isFetching = true
        var upNextURLComponents = URLComponents()
        upNextURLComponents.scheme = "https"
        upNextURLComponents.host = "api.simkl.com"
        upNextURLComponents.path = "/sync/all-items/shows/watching"
        upNextURLComponents.queryItems = [
          URLQueryItem(name: "episode_watched_at", value: "yes"),
          URLQueryItem(name: "memos", value: "yes"),
          URLQueryItem(name: "next_watch_info", value: "yes"),
        ]
        var request = URLRequest(url: upNextURLComponents.url!)
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
        let showsResponse = try decoder.decode(UpNextShowModel.self, from: data)
        let filteredShows = showsResponse.shows.filter {
          $0.next_to_watch_info?.title?.isEmpty == false
        }
        if filteredShows.count > 0 {
          shows = filteredShows
          isFetching = false
        } else {
          shows = []
          isFetching = false
        }
      } else {
        shows = []
        isFetching = false
      }
    } catch {
      shows = []
      isFetching = false
    }
  }
}

#Preview {
  HomeView()
    .environmentObject(Auth())
}

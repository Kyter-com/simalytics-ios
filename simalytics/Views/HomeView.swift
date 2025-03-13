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
  @State private var shows: [UpNextShowModel_show] = []
  @State private var searchText: String = ""
  var filteredShows: [UpNextShowModel_show] {
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
          CustomKFImage(
            imageUrlString: "\(SIMKL_CDN_URL)/posters/\(showItem.show.poster)_m.jpg",
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
              await markAsWatched(show: showItem, accessToken: auth.simklAccessToken)
              await fetchShows()
            }
          } label: {
            Label("Watched", systemImage: "checkmark.circle")
          }
          .tint(.green)
        }
      }
      .listStyle(.inset)
      .searchable(text: $searchText, placement: .automatic)
      .refreshable {
        await Task.sleep(1 * 1_000_000_000)
        await fetchShows()
      }
      .task { await fetchShows() }
      .navigationTitle("Up Next")
    }
  }

  private func fetchShows() async {
    do {
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
      } else {
        shows = []
      }
    } catch {
      shows = []
    }
  }
}

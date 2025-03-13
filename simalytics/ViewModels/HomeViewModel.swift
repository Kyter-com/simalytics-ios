//
//  HomeViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/11/25.
//

import Foundation
import Sentry

extension HomeView {
  func markAsWatched(
    show: UpNextShowModel_show,
    accessToken: String
  ) async {
    do {
      let url = URL(string: "https://api.simkl.com/sync/history")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(
        "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9",
        forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

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
      _ = try await URLSession.shared.data(for: request)
    } catch {
      SentrySDK.capture(error: error)
    }
  }

  func fetchShows(accessToken: String) async -> [UpNextShowModel_show] {
    do {
      var urlComponents = URLComponents(
        string: "https://api.simkl.com/sync/all-items/shows/watching")!
      urlComponents.queryItems = [
        URLQueryItem(name: "episode_watched_at", value: "yes"),
        URLQueryItem(name: "memos", value: "yes"),
        URLQueryItem(name: "next_watch_info", value: "yes"),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(
        "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9",
        forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        return []
      }

      let showsResponse = try JSONDecoder().decode(UpNextShowModel.self, from: data)
      return showsResponse.shows.filter { $0.next_to_watch_info?.title?.isEmpty == false }
    } catch {
      SentrySDK.capture(error: error)
      return []
    }
  }
}

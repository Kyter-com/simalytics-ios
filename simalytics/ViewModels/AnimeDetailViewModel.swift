//
//  AnimeDetailViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Foundation
import Sentry

extension AnimeDetailView {
  static func getAnimeDetails(_ simkl_id: Int) async -> AnimeDetailsModel? {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/anime/\(simkl_id)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "extended", value: "full"),
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode(AnimeDetailsModel.self, from: data)
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }

  static func markEpisodeUnwatched(_ accessToken: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int, _ episodeId: Int) async {
    do {
      let url = URL(string: "https://api.simkl.com/sync/history/remove")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

      let body: [String: Any] = [
        "shows": [
          [
            "title": title,
            "ids": [
              "simkl": simklId
            ],
            "seasons": [
              [
                "number": season,
                "episodes": [
                  [
                    "number": episode
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

  static func getAnimeWatchlist(_ simkl_id: Int, _ accessToken: String) async -> AnimeWatchlistModel? {
    do {
      let urlComponents = URLComponents(string: "https://api.simkl.com/sync/watched?extended=specials")!

      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [[String: Any]] = [["simkl": simkl_id, "type": "anime"]]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode([AnimeWatchlistModel].self, from: data).first
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }

  static func addAnimeRating(_ simkl_id: Int, _ accessToken: String, _ rating: Double) async {
    do {
      let urlComponents = URLComponents(string: "https://api.simkl.com/sync/ratings")!
      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [String: Any] = [
        "shows": [
          [
            "rating": rating,
            "ids": [
              "simkl": simkl_id
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

  static func markEpisodeWatched(_ accessToken: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int, _ episodeId: Int) async {
    do {
      let url = URL(string: "https://api.simkl.com/sync/history")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

      let formatter = ISO8601DateFormatter()
      let dateString = formatter.string(from: Date())
      let body: [String: Any] = [
        "shows": [
          [
            "title": title,
            "ids": [
              "simkl": simklId
            ],
            "seasons": [
              [
                "number": season,
                "episodes": [
                  [
                    "number": episode,
                    "watched_at": dateString,
                  ]
                ],
              ]
            ],
          ]
        ]
      ]
      let specialsBody: [String: Any] = [
        "episodes": [
          [
            "watched_at": dateString,
            "ids": [
              "simkl": episodeId
            ],
          ]
        ]
      ]
      request.httpBody = try JSONSerialization.data(withJSONObject: episode != 0 ? body : specialsBody)
      _ = try await URLSession.shared.data(for: request)
    } catch {
      SentrySDK.capture(error: error)
    }
  }

  static func getAnimeEpisodes(_ simkl_id: Int) async -> [AnimeEpisodeModel] {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/anime/episodes/\(simkl_id)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
        URLQueryItem(name: "extended", value: "full"),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        return []
      }

      let episodes = try JSONDecoder().decode([AnimeEpisodeModel].self, from: data)
      // Map through the episodes and assign custom seasons
      let processedEpisodes = episodes.map { episode -> AnimeEpisodeModel in
        var modifiedEpisode = episode
        if episode.type != "special", let episodeNumber = episode.episode {
          modifiedEpisode.season = episodeNumber / 100 + 1
        } else {
          modifiedEpisode.season = 0
        }
        return modifiedEpisode
      }
      return processedEpisodes
    } catch {
      SentrySDK.capture(error: error)
      return []
    }
  }
}

extension AnimeWatchlistButton {
  static func updateAnimeList(_ simkl_id: Int, _ accessToken: String, _ list: String) async {
    do {
      if list == "nil" {
        let urlComponents = URLComponents(string: "https://api.simkl.com/sync/history/remove")!
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
          "shows": [
            [
              "ids": [
                "simkl": simkl_id
              ]
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)
      } else {
        let urlComponents = URLComponents(string: "https://api.simkl.com/sync/add-to-list")!

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
          "shows": [
            [
              "to": list,
              "ids": [
                "simkl": simkl_id
              ],
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await URLSession.shared.data(for: request)
      }
    } catch {
      SentrySDK.capture(error: error)
      return
    }
  }
}

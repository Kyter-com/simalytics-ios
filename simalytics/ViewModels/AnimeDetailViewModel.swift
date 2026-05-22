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

      if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
        return nil
      }

      return try JSONDecoder().decode(AnimeDetailsModel.self, from: data)
    } catch {
      reportError(error)
      return nil
    }
  }

  @discardableResult
  static func markEpisodeUnwatched(_ accessToken: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int) async -> String? {
    do {
      let url = URL(string: "https://api.simkl.com/sync/history/remove")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

      let body: [String: Any] = [
        "anime": [
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
      try await performSimklMutationRequest(request)
      return nil
    } catch {
      if isSimklCancellationError(error) { return nil }
      reportError(error)
      return simklMutationUserMessage(for: error)
    }
  }

  // Batched variant for callers (e.g. up-next sync) that need watched data
  // for many anime at once. Chunked to stay under Simkl's 100-item cap when
  // extended=episodes is set.
  static func getAnimeWatchlistBatch(_ simklIDs: [Int], _ accessToken: String) async -> [AnimeWatchlistModel] {
    guard !simklIDs.isEmpty else { return [] }
    let chunkSize = 100
    let chunks = stride(from: 0, to: simklIDs.count, by: chunkSize).map {
      Array(simklIDs[$0..<min($0 + chunkSize, simklIDs.count)])
    }
    var combined: [AnimeWatchlistModel] = []
    for chunk in chunks {
      do {
        let url = URL(string: "https://api.simkl.com/sync/watched?extended=episodes,specials")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body: [[String: Any]] = chunk.map { ["simkl": $0, "type": "anime"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        // A non-200 here drops watched state for up to 100 anime — surface
        // it to Sentry so rate-limit / auth issues don't fail silently.
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
          reportError(NSError(
            domain: "Simkl", code: status,
            userInfo: [NSLocalizedDescriptionKey: "Batched /sync/watched (anime) returned HTTP \(status) for \(chunk.count) ids"]
          ))
          continue
        }
        combined.append(contentsOf: try JSONDecoder().decode([AnimeWatchlistModel].self, from: data))
      } catch {
        reportError(error)
      }
    }
    return combined
  }

  static func getAnimeWatchlist(_ simkl_id: Int, _ accessToken: String) async -> AnimeWatchlistModel? {
    do {
      let urlComponents = URLComponents(string: "https://api.simkl.com/sync/watched?extended=episodes,specials")!

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
      reportError(error)
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
        "anime": [
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
      reportError(error)
    }
  }

  @discardableResult
  static func markEpisodeWatched(_ accessToken: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int) async -> String? {
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
        "anime": [
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
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      try await performSimklMutationRequest(request)
      return nil
    } catch {
      if isSimklCancellationError(error) { return nil }
      reportError(error)
      return simklMutationUserMessage(for: error)
    }
  }

  static func getAnimeEpisodes(_ simkl_id: Int, countSeasons: Bool = false) async -> [AnimeEpisodeModel] {
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

      if countSeasons {
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
      } else {
        // Count special as season 0 and everything else as season 1
        let processedEpisodes = episodes.map { episode -> AnimeEpisodeModel in
          var modifiedEpisode = episode
          if episode.type == "special" {
            modifiedEpisode.season = 0
          } else if episode.episode != nil {
            modifiedEpisode.season = 1
          } else {
            modifiedEpisode.season = nil
          }
          return modifiedEpisode
        }
        return processedEpisodes
      }
    } catch {
      reportError(error)
      return []
    }
  }
}

extension AnimeWatchlistButton {
  static func updateAnimeList(_ simkl_id: Int, _ accessToken: String, _ list: String) async -> String? {
    do {
      if list == "nil" {
        let urlComponents = URLComponents(string: "https://api.simkl.com/sync/history/remove")!
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
          "anime": [
            [
              "ids": [
                "simkl": simkl_id
              ]
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try await performSimklMutationRequest(request)
      } else {
        let urlComponents = URLComponents(string: "https://api.simkl.com/sync/add-to-list")!

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
          "anime": [
            [
              "to": list,
              "ids": [
                "simkl": simkl_id
              ],
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        try await performSimklMutationRequest(request)
      }
      return nil
    } catch {
      if isSimklCancellationError(error) {
        return nil
      }
      reportError(error)
      return simklMutationUserMessage(for: error)
    }
  }
}

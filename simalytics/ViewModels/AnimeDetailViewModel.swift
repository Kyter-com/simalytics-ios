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

      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        == "[]"
      {
        return nil
      }

      return try JSONDecoder().decode(AnimeDetailsModel.self, from: data)
    } catch {
      reportError(error)
      return nil
    }
  }

  @discardableResult
  static func markEpisodeUnwatched(
    _ accessToken: String,
    _ title: String,
    _ simklId: Int,
    _ season: Int,
    _ episode: Int
  ) async -> SimklMutationResult {
    guard simklId > 0,
      let selection = validatedSimklEpisode(season: season, episode: episode)
    else {
      let error = SimklMutationError.invalidEpisode
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }

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
                "number": selection.season,
                "episodes": [
                  [
                    "number": selection.episode
                  ]
                ],
              ]
            ],
          ]
        ]
      ]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      try await performSimklMutationRequest(request)
      return .succeeded
    } catch {
      if isSimklCancellationError(error) { return .cancelled }
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }
  }

  // Batched variant for callers (e.g. up-next sync) that need watched data
  // for many anime at once. Thin wrapper around the shared helper so the
  // call site stays clean and TV/anime behaviour can't drift apart.
  static func getAnimeWatchlistBatch(_ simklIDs: [Int], _ accessToken: String) async
    -> SimklWatchedBatch<AnimeWatchlistModel>
  {
    await simklWatchedBatch(simklIDs: simklIDs, type: "anime", accessToken: accessToken)
  }

  static func getAnimeWatchlist(_ simkl_id: Int, _ accessToken: String) async
    -> AnimeWatchlistModel?
  {
    do {
      let urlComponents = URLComponents(
        string: "https://api.simkl.com/sync/watched?extended=episodes,specials")!

      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [[String: Any]] = [["ids": ["simkl": simkl_id], "type": "anime"]]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      let decoded = try decodeSimklWatchedResponse(AnimeWatchlistModel.self, from: data)
      if decoded.malformedItemCount > 0 {
        reportSimklWatchedSchemaIssue(
          type: "anime",
          malformedItemCount: decoded.malformedItemCount,
          responseItemCount: decoded.items.count + decoded.terminalRejectionCount
            + decoded.malformedItemCount
        )
      }
      return decoded.items.first
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
      _ = try await URLSession.shared.simklData(for: request)
    } catch {
      reportError(error)
    }
  }

  @discardableResult
  static func markEpisodeWatched(
    _ accessToken: String,
    _ title: String,
    _ simklId: Int,
    _ season: Int,
    _ episode: Int
  ) async -> SimklMutationResult {
    guard simklId > 0,
      let selection = validatedSimklEpisode(season: season, episode: episode)
    else {
      let error = SimklMutationError.invalidEpisode
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }

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
                "number": selection.season,
                "episodes": [
                  [
                    "number": selection.episode,
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
      return .succeeded
    } catch {
      if isSimklCancellationError(error) { return .cancelled }
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }
  }

  static func getAnimeEpisodes(_ simkl_id: Int, countSeasons: Bool = false) async
    -> [AnimeEpisodeModel]
  {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/anime/episodes/\(simkl_id)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
        URLQueryItem(name: "extended", value: "full"),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, _) = try await performSimklRequest(request)
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

  // Nonisolated: pure logic over Sendable models, and member isolation is
  // otherwise inferred as @MainActor from the View conformance, which would
  // trap background callers (e.g. tests).
  nonisolated static func isEpisodeWatched(
    _ watchlist: AnimeWatchlistModel?,
    season targetSeason: Int,
    episode targetEpisode: Int
  ) -> Bool {
    guard let seasons = watchlist?.seasons else { return false }
    for season in seasons {
      guard let episodes = season.episodes else { continue }
      if episodes.contains(where: {
        $0.number == targetEpisode && season.number == targetSeason && $0.watched == true
      }) {
        return true
      }
    }
    return false
  }

  /// Watchlist season for an anime episode row. Anime seasons are synthetic
  /// display groups (see getAnimeEpisodes) while Simkl tracks episodes flat,
  /// so checkmarks and resume selection both resolve through here.
  nonisolated static func watchlistSeason(for episode: AnimeEpisodeModel) -> Int {
    episode.type == "special" ? 0 : 1
  }

  /// Season the episode list should open on: the first numbered season
  /// (ascending) with at least one unwatched episode, so returning viewers
  /// land where they left off instead of on season 1. Falls back to the
  /// last season when everything is watched, and to nil when there are no
  /// numbered seasons (caller shows specials instead).
  nonisolated static func defaultSeason(
    episodes: [AnimeEpisodeModel],
    watchlist: AnimeWatchlistModel?
  ) -> Int? {
    let numberedSeasons =
      episodes
      .compactMap { $0.season }
      .filter { $0 > 0 }
      .unique()
      .sorted()
    return
      numberedSeasons.first { season in
        episodes.contains {
          $0.season == season
            && !isEpisodeWatched(
              watchlist, season: watchlistSeason(for: $0), episode: $0.episode ?? -1)
        }
      } ?? numberedSeasons.last
  }
}

extension AnimeWatchlistButton {
  static func updateAnimeList(_ simkl_id: Int, _ accessToken: String, _ list: String) async
    -> String?
  {
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

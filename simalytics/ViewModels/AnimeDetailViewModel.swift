//
//  AnimeDetailViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Foundation
import Sentry

extension AnimeDetailView {
  static func getAnimeDetails(_ simklID: Int) async -> AnimeDetailsModel? {
    #if DEBUG
      if ScreenshotMode.isActive, simklID == ScreenshotEpisodeFixtures.animeID {
        return ScreenshotEpisodeFixtures.animeDetails
      }
    #endif
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/anime/\(simklID)")!
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
    _ episode: Int,
    session: URLSession = .shared
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
        "shows": [
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
      let (data, _) = try await performSimklRequest(request, session: session)
      try validateSimklRemovalResponse(data, countKey: "episodes", singleEpisode: true)
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

  static func getAnimeWatchlist(_ simklID: Int, _ accessToken: String) async
    -> AnimeWatchlistModel?
  {
    #if DEBUG
      if ScreenshotMode.isActive {
        guard simklID == ScreenshotEpisodeFixtures.animeID else { return nil }
        return AnimeWatchlistModel(
          list: ScreenshotMode.watchlistStatus ?? "watching", last_watched_at: nil, simkl: simklID,
          episodes_watched: 80, episodes_aired: nil,
          seasons: ScreenshotEpisodeFixtures.watchedSeason(1, numbers: Array(1100...1179)))
      }
    #endif
    do {
      let urlComponents = URLComponents(
        string: "https://api.simkl.com/sync/watched?extended=episodes,specials")!

      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [[String: Any]] = [["ids": ["simkl": simklID], "type": "anime"]]
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

  @discardableResult
  static func markEpisodeWatched(
    _ accessToken: String,
    _ title: String,
    _ simklId: Int,
    _ season: Int,
    _ episode: Int,
    session: URLSession = .shared
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
      let (data, _) = try await performSimklRequest(request, session: session)
      try validateSimklEpisodeHistoryResponse(data)
      return .succeeded
    } catch {
      if isSimklCancellationError(error) { return .cancelled }
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }
  }

  @concurrent
  nonisolated static func getAnimeEpisodes(
    _ simklID: Int, countSeasons: Bool = false, session: URLSession = .shared
  ) async throws -> [AnimeEpisodeModel] {
    #if DEBUG
      if ScreenshotMode.isActive, simklID == ScreenshotEpisodeFixtures.animeID {
        return ScreenshotEpisodeFixtures.animeEpisodes
      }
    #endif
    let request = URLRequest(
      url: simklAPIURL(
        path: "anime/episodes/\(simklID)",
        queryItems: [URLQueryItem(name: "extended", value: "full")]))
    let (data, _) = try await performSimklRequest(request, session: session)
    try Task.checkCancellation()
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

  /// Resume from the highest watched display group, ignoring older gaps.
  /// Progress still uses SIMKL's absolute episode numbers in watchlist season 1,
  /// rather than treating the synthetic display group as a watchlist season.
  nonisolated static func defaultSeason(
    episodes: [AnimeEpisodeModel],
    watchlist: AnimeWatchlistModel?
  ) -> Int? {
    preferredEpisodeSeason(
      in: episodes,
      season: { $0.type == "special" ? nil : $0.season },
      isWatched: {
        isEpisodeWatched(
          watchlist, season: watchlistSeason(for: $0), episode: $0.episode ?? -1)
      })
  }
}

extension AnimeWatchlistButton {
  static func updateAnimeList(
    _ simklID: Int, _ accessToken: String, _ list: String, session: URLSession = .shared
  ) async
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
          "shows": [
            [
              "ids": [
                "simkl": simklID
              ]
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await performSimklRequest(request, session: session)
        try validateSimklRemovalResponse(data, countKey: "shows")
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
                "simkl": simklID
              ],
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await performSimklRequest(request, session: session)
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

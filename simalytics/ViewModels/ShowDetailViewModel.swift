//
//  ShowDetailViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/21/25.
//

import Foundation
import Sentry

extension ShowDetailView {
  static func getShowDetails(_ simklID: Int) async -> ShowDetailsModel? {
    #if DEBUG
      if ScreenshotMode.isActive, simklID == ScreenshotEpisodeFixtures.showID {
        return ScreenshotEpisodeFixtures.showDetails
      }
    #endif
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/tv/\(simklID)")!
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

      return try JSONDecoder().decode(ShowDetailsModel.self, from: data)
    } catch {
      reportError(error)
      return nil
    }
  }

  // Batched variant for callers (e.g. up-next sync) that need watched data
  // for many shows at once. Thin wrapper around the shared helper so the
  // call site stays clean and TV/anime behaviour can't drift apart.
  static func getShowWatchlistBatch(_ simklIDs: [Int], _ accessToken: String) async
    -> SimklWatchedBatch<ShowWatchlistModel>
  {
    await simklWatchedBatch(simklIDs: simklIDs, type: "show", accessToken: accessToken)
  }

  static func getShowWatchlist(_ simklID: Int, _ accessToken: String) async -> ShowWatchlistModel? {
    #if DEBUG
      if ScreenshotMode.isActive {
        guard simklID == ScreenshotEpisodeFixtures.showID else { return nil }
        return ShowWatchlistModel(
          list: ScreenshotMode.watchlistStatus ?? "watching", last_watched_at: nil, simkl: simklID,
          episodes_watched: 2, episodes_aired: nil,
          seasons: ScreenshotEpisodeFixtures.watchedSeason(
            28, numbers: [1, 2]))
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
      let body: [[String: Any]] = [["ids": ["simkl": simklID], "type": "show"]]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      let decoded = try decodeSimklWatchedResponse(ShowWatchlistModel.self, from: data)
      if decoded.malformedItemCount > 0 {
        reportSimklWatchedSchemaIssue(
          type: "show",
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
  nonisolated static func getShowEpisodes(
    _ simklID: Int, session: URLSession = .shared
  ) async throws -> [ShowEpisodeModel] {
    #if DEBUG
      if ScreenshotMode.isActive, simklID == ScreenshotEpisodeFixtures.showID {
        return ScreenshotEpisodeFixtures.showEpisodes
      }
    #endif
    let request = URLRequest(
      url: simklAPIURL(
        path: "tv/episodes/\(simklID)", queryItems: [URLQueryItem(name: "extended", value: "full")]
      ))
    let (data, _) = try await performSimklRequest(request, session: session)
    try Task.checkCancellation()
    return try JSONDecoder().decode([ShowEpisodeModel].self, from: data)
  }

  // Nonisolated: pure logic over Sendable models, and member isolation is
  // otherwise inferred as @MainActor from the View conformance, which would
  // trap background callers (e.g. tests).
  nonisolated static func isEpisodeWatched(
    _ watchlist: ShowWatchlistModel?,
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

  /// Resume from the highest watched regular season, ignoring older gaps.
  /// Completed seasons advance to the next available season; specials do not
  /// affect progress. With no numbered seasons, the caller shows specials.
  nonisolated static func defaultSeason(
    episodes: [ShowEpisodeModel],
    watchlist: ShowWatchlistModel?
  ) -> Int? {
    preferredEpisodeSeason(
      in: episodes,
      season: { $0.type == "special" ? nil : $0.season },
      isWatched: {
        isEpisodeWatched(watchlist, season: $0.season ?? -1, episode: $0.episode ?? -1)
      })
  }
}

extension ShowWatchlistButton {
  static func updateShowList(
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
          "shows": [
            [
              "to": list,
              "ids": [
                "simkl": simklID
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

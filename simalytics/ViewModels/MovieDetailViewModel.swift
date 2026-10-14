//
//  MovieDetailViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/15/25.
//

import Foundation
import Sentry

extension MovieDetailView {
  static func getMovieDetails(_ simkl_id: Int) async -> MovieDetailsModel? {
    #if DEBUG
      if ScreenshotMode.isActive, let fixture = ScreenshotDetailFixtures.movieDetails(simkl_id) {
        return fixture
      }
    #endif
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/movies/\(simkl_id)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "extended", value: "full"),
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      if String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "[]" {
        return nil
      }

      return try JSONDecoder().decode(MovieDetailsModel.self, from: data)
    } catch {
      reportError(error)
      return nil
    }
  }

  static func getMovieWatchlist(_ simkl_id: Int, _ accessToken: String) async
    -> MovieWatchlistModel?
  {
    #if DEBUG
      if ScreenshotMode.isActive, let fixture = ScreenshotDetailFixtures.movieWatchlist(simkl_id) {
        return fixture
      }
    #endif
    do {
      let urlComponents = URLComponents(string: "https://api.simkl.com/sync/watched")!

      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [[String: Any]] = [["ids": ["simkl": simkl_id], "type": "movie"]]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode([MovieWatchlistModel].self, from: data).first
    } catch {
      reportError(error)
      return nil
    }
  }
}

extension MovieWatchlistButton {
  static func updateMovieList(
    _ simkl_id: Int, _ accessToken: String, _ list: String, session: URLSession = .shared
  ) async -> String? {
    do {
      if list == "nil" {
        let urlComponents = URLComponents(string: "https://api.simkl.com/sync/history/remove")!
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
          "movies": [
            [
              "ids": [
                "simkl": simkl_id
              ]
            ]
          ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await performSimklRequest(request, session: session)
        try validateSimklRemovalResponse(data, countKey: "movies")
      } else {
        let urlComponents = URLComponents(string: "https://api.simkl.com/sync/add-to-list")!

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
          "movies": [
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

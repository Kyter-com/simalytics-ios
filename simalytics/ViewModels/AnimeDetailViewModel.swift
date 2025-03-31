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

  static func getAnimeWatchlist(_ simkl_id: Int, _ accessToken: String) async
    -> AnimeWatchlistModel?
  {
    do {
      let urlComponents = URLComponents(string: "https://api.simkl.com/sync/watched")!

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

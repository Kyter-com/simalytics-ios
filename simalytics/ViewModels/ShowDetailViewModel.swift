//
//  ShowDetailViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/21/25.
//

import Foundation
import Sentry

extension ShowDetailView {
  static func getShowDetails(_ simkl_id: Int) async -> ShowDetailsModel? {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/tv/\(simkl_id)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "extended", value: "full"),
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode(ShowDetailsModel.self, from: data)
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }

  static func getShowWatchlist(_ simkl_id: Int, _ accessToken: String) async
    -> ShowWatchlistModel?
  {
    do {
      let urlComponents = URLComponents(string: "https://api.simkl.com/sync/watched")!

      var request = URLRequest(url: urlComponents.url!)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [[String: Any]] = [["simkl": simkl_id, "type": "tv"]]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode([ShowWatchlistModel].self, from: data).first
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }

  static func getShowEpisodes(_ simkl_id: Int) async -> [ShowEpisodeModel] {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/tv/episodes/\(simkl_id)")!
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

      return try JSONDecoder().decode([ShowEpisodeModel].self, from: data)
    } catch {
      SentrySDK.capture(error: error)
      return []
    }

  }
}

extension ShowWatchlistButton {
  static func updateShowList(_ simkl_id: Int, _ accessToken: String, _ list: String) async {
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

//
//  HomeViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/11/25.
//

//
//  ShowUtilities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/11/25.
//

import Foundation
import Sentry

func markAsWatched(
  show: UpNextShowModel_show,
  accessToken: String
) async {
  do {
    var markWatchedURLComponents = URLComponents()
    markWatchedURLComponents.scheme = "https"
    markWatchedURLComponents.host = "api.simkl.com"
    markWatchedURLComponents.path = "/sync/history"

    var request = URLRequest(url: markWatchedURLComponents.url!)
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
    let (_, response) = try await URLSession.shared.data(for: request)
  } catch {
    SentrySDK.capture(error: error)
    return
  }
}

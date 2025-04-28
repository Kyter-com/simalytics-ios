//
//  MemoViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/27/25.
//

import Foundation
import Sentry

func addMemoToMovie(accessToken: String, simkl: Int, memoText: String, isPrivate: Bool, status: String) async {
  do {
    let url = URL(string: "https://api.simkl.com/sync/history")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let body: [String: Any] = [
      "movies": [
        [
          "status": status,
          "memo": [
            "text": memoText,
            "is_private": isPrivate,
          ],
          "ids": [
            "simkl": simkl
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

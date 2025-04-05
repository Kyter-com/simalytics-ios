//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry

func fetchAndStoreLatestActivities(_ accessToken: String) async {
  do {
    let urlComponents = URLComponents(string: "https://api.simkl.com/sync/activities")!

    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(LastActivitiesModel.self, from: data)

    // Wait 10 seconds fake
    await Task.sleep(10 * 1_000_000_000)

  } catch {
    SentrySDK.capture(error: error)
  }
}

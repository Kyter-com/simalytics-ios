//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry
import SwiftData

func syncLatestActivities(_ accessToken: String) async {
  do {
    let urlComponents = URLComponents(string: "https://api.simkl.com/sync/activities")!
    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(LastActivitiesModel.self, from: data)

    await fetchAndStoreMoviesPlanToWatch(accessToken, result.movies?.plantowatch)
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesPlanToWatch(_ accessToken: String, _ lastActivity: String?) async {
  do {
    guard let lastActivityStr = lastActivity else { return }

    let lastSyncDate = try context.fetch(FetchDescriptor<SDLastSync>()).first?.movies_plantowatch

    let formatter = ISO8601DateFormatter()
    var dateFrom: String? = nil
    if let lastSyncStr = lastSyncDate,
      let lastSyncDate = formatter.date(from: lastSyncStr),
      let lastActivityDate = formatter.date(from: lastActivityStr),
      lastActivityDate > lastSyncDate
    {
      dateFrom = lastActivityStr
    }

    var urlComponents = URLComponents(
      string: "https://api.simkl.com/sync/all-items/movies/plantowatch?memos=yes")!
    if let dateFrom {
      urlComponents.queryItems = [
        URLQueryItem(name: "date_from", value: dateFrom)
      ]
    }
    print("📡", urlComponents.url!)
    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(MoviesPlanToWatchModel.self, from: data)

    for movieItem in result.movies ?? [] {
    }

  } catch {
    SentrySDK.capture(error: error)
  }
}

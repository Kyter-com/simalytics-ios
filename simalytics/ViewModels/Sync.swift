//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry
import SwiftData

func syncLatestActivities(_ accessToken: String, modelContainer: ModelContainer) async {
  do {
    let context = ModelContext(modelContainer)
    let urlComponents = URLComponents(string: "https://api.simkl.com/sync/activities")!
    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(LastActivitiesModel.self, from: data)

    await fetchAndStoreMoviesPlanToWatch(accessToken, result.movies?.plantowatch, context)
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesPlanToWatch(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    let lastSync = try context.fetch(FetchDescriptor<SDLastSync>()).first?.movies_plantowatch
    if lastActivity == lastSync { return }

    var endpoint = URLComponents(string: "https://api.simkl.com/sync/all-items/movies/plantowatch?memos=yes")!
    let lastActivityDate = formatter.date(from: lastActivity)!

    if let lastSync = lastSync {
      let lastSyncDate = formatter.date(from: lastSync) ?? Date(timeIntervalSince1970: 0)
      if lastActivityDate > lastSyncDate {
        let dateFrom = formatter.string(from: Calendar.current.date(byAdding: .minute, value: -5, to: lastActivityDate)!)
        endpoint = URLComponents(string: "https://api.simkl.com/sync/all-items/movies/plantowatch?memos=yes&date_from=\(dateFrom)")!
      }
    }

    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(MoviesPlanToWatchModel.self, from: data)

    for movieItem in result.movies ?? [] {
      context.insert(SDMoviesPlanToWatch(simkl: (movieItem.movie?.ids!.simkl)!, title: movieItem.movie?.title))
    }
    context.insert(SDLastSync(movies_plantowatch: lastActivity))
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

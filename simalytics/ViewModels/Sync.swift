//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry
import SwiftData

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

    let context = try ModelContext(.init(for: SDLastActivities.self))
    try context.delete(model: SDLastActivities.self)
    context.insert(
      SDLastActivities(
        all: result.all,
        settings_all: result.settings?.all,
        tv_shows_all: result.tv_shows?.all,
        tv_shows_rated_at: result.tv_shows?.rated_at,
        tv_shows_plantowatch: result.tv_shows?.plantowatch,
        tv_shows_watching: result.tv_shows?.watching,
        tv_shows_completed: result.tv_shows?.completed,
        tv_shows_hold: result.tv_shows?.hold,
        tv_shows_dropped: result.tv_shows?.dropped,
        tv_shows_removed_from_list: result.tv_shows?.removed_from_list,
        movies_all: result.movies?.all,
        movies_rated_at: result.movies?.rated_at,
        movies_plantowatch: result.movies?.plantowatch,
        movies_completed: result.movies?.completed,
        movies_dropped: result.movies?.dropped,
        movies_removed_from_list: result.movies?.removed_from_list,
        anime_all: result.anime?.all,
        anime_rated_at: result.anime?.rated_at,
        anime_plantowatch: result.anime?.plantowatch,
        anime_watching: result.anime?.watching,
        anime_completed: result.anime?.completed,
        anime_hold: result.anime?.hold,
        anime_dropped: result.anime?.dropped,
        anime_removed_from_list: result.anime?.removed_from_list
      )
    )
    try context.save()

    await fetchAndStoreMoviesPlanToWatch(accessToken, result.movies?.plantowatch)
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesPlanToWatch(_ accessToken: String, _ lastActivity: String?) async {
  do {
    if lastActivity == nil { return }

    let context = try ModelContext(.init(for: SDLastSync.self))
    let lastSyncDate =
      try context.fetch(FetchDescriptor<SDLastSync>()).first?.movies_plantowatch
      ?? "2025-04-09T01:03:36.832Z"

    var fetchFrom = ""
    if lastSyncDate == nil {
      fetchFrom = "all"
    } else if lastActivity! > lastSyncDate {
      fetchFrom = lastActivity!
    }
    print("📡 fetchAndStoreMoviesPlanToWatch", fetchFrom)

    var urlComponents = URLComponents(
      string: "https://api.simkl.com/sync/all-items/movies/plantowatch?memos=yes")!
    if fetchFrom != "all" {
      urlComponents.queryItems = [
        URLQueryItem(name: "date_from", value: fetchFrom)
      ]
    }
    print(urlComponents.url!)
    var request = URLRequest(url: urlComponents.url!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    let result = try JSONDecoder().decode(MoviesPlanToWatchModel.self, from: data)

  } catch {
    print(error)
    SentrySDK.capture(error: error)
  }
}

//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry
import SwiftData

private func ensureLastSyncRecord(_ container: ModelContainer) {
  let context = ModelContext(container)
  let existing = (try? context.fetch(
    FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
  ))?.first
  guard existing == nil else { return }
  context.insert(V1.SDLastSync(id: 1))
  try? context.save()
}

func syncLatestActivities(
  _ accessToken: String,
  modelContainer: ModelContainer,
  forceRefresh: Bool = false
) async {
  ensureLastSyncRecord(modelContainer)
  do {
    let urlComponents = URLComponents(string: "https://api.simkl.com/sync/activities")!
    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    let result = try JSONDecoder().decode(LastActivitiesModel.self, from: data)

    // Phase 1: every task that mutates SDLastSync(id: 1) runs sequentially.
    // Each function fetches the row, writes its own field, then saves the
    // whole row — so concurrent contexts can clobber each other's field
    // updates (last write wins on the entire row). The /sync/* endpoints
    // also need to be sequential per Simkl's documented rate-limit
    // guidance. Each call gets a fresh ModelContext so the context stays
    // confined to a single unit of work.
    //
    // The `step` helper folds the repeated `accessToken + new context`
    // boilerplate so future edits only have to touch the per-bucket list
    // below. processUpNextEpisodes is intentionally NOT in this stage —
    // it reads SDShows/SDAnimes that these tasks are writing.
    func step(_ activity: String?, _ handler: (String, String?, ModelContext) async -> Void) async {
      await handler(accessToken, activity, ModelContext(modelContainer))
    }

    await step(result.movies?.plantowatch, fetchAndStoreMoviesPlanToWatch)
    await step(result.movies?.dropped, fetchAndStoreMoviesDropped)
    await step(result.movies?.completed, fetchAndStoreMoviesCompleted)
    await step(result.movies?.removed_from_list, fetchAndStoreMoviesRemovedFromList)
    await step(result.movies?.rated_at, fetchAndStoreMoviesRatedAt)
    await step(result.tv_shows?.plantowatch, fetchAndStoreTVPlanToWatch)
    await step(result.tv_shows?.completed, fetchAndStoreTVCompleted)
    await step(result.tv_shows?.hold, fetchAndStoreTVHold)
    await step(result.tv_shows?.dropped, fetchAndStoreTVDropped)
    await step(result.tv_shows?.watching) { token, activity, ctx in
      await fetchAndStoreTVWatching(token, activity, ctx, forceRefresh: forceRefresh)
    }
    await step(result.tv_shows?.removed_from_list, fetchAndStoreTVRemovedFromList)
    await step(result.tv_shows?.rated_at, fetchAndStoreTVRatedAt)
    await step(result.anime?.plantowatch, fetchAndStoreAnimePlanToWatch)
    await step(result.anime?.dropped, fetchAndStoreAnimeDropped)
    await step(result.anime?.completed, fetchAndStoreAnimeCompleted)
    await step(result.anime?.hold, fetchAndStoreAnimeHold)
    await step(result.anime?.rated_at, fetchAndStoreAnimeRatedAt)
    await step(result.anime?.removed_from_list, fetchAndStoreAnimeRemovedFromList)
    await step(result.anime?.watching) { token, activity, ctx in
      await fetchAndStoreAnimeWatching(token, activity, ctx, forceRefresh: forceRefresh)
    }

    // Trending (CDN) and stale-data refresh (per-id detail endpoints) also
    // write to SDLastSync, so they're sequenced here for the same
    // last-write-wins reason. Their internal network work parallelizes
    // independently — only the final SDLastSync writes need ordering.
    await syncLatestTrending(accessToken, ModelContext(modelContainer))
    await refreshStaleData(accessToken, ModelContext(modelContainer))

    // Phase 2: now that SDShows/SDAnimes are populated, compute up next.
    let upNextContext = ModelContext(modelContainer)
    await processUpNextEpisodes(accessToken, upNextContext, forceRefresh: forceRefresh)

    let releaseDateContext = ModelContext(modelContainer)
    await backfillMissingPlanToWatchReleaseDates(releaseDateContext)
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesPlanToWatch(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.movies_plantowatch { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/movies/plantowatch?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.movies_plantowatch.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/movies/plantowatch?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_plantowatch = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }
    await enrichMovieReleaseDatesForPlanToWatch(movies, context, formatter)

    syncRecord!.movies_plantowatch = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesDropped(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.movies_dropped { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/movies/dropped?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.movies_dropped.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/movies/dropped?memos=yes&date_from=\(dateFrom)")!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_dropped = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }

    syncRecord!.movies_dropped = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesCompleted(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.movies_completed { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/movies/completed?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.movies_completed.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/movies/completed?memos=yes&date_from=\(dateFrom)")!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_completed = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }

    syncRecord!.movies_completed = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesRemovedFromList(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.movies_removed_from_list { return }

    let endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/movies?extended=simkl_ids_only")!

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_removed_from_list = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    let currentSimklIds = Set(movies.compactMap { $0.movie?.ids?.simkl })

    let existingMoviesDescriptor = FetchDescriptor<V1.SDMovies>()
    let existingMovies = try context.fetch(existingMoviesDescriptor)

    let moviesToDelete = existingMovies.filter { movie in
      !currentSimklIds.contains(movie.simkl)
    }

    for movie in moviesToDelete {
      context.delete(movie)
    }

    syncRecord!.movies_removed_from_list = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesRatedAt(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.movies_rated_at { return }

    var endpoint = URLComponents(string: "https://api.simkl.com/sync/ratings/movies?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.movies_rated_at.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/ratings/movies?memos=yes&date_from=\(dateFrom)")!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_rated_at = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }

    syncRecord!.movies_rated_at = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVPlanToWatch(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_plantowatch { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/plantowatch?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_plantowatch.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/shows/plantowatch?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_plantowatch = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }
    await enrichShowReleaseDatesForPlanToWatch(shows, context, formatter)

    syncRecord!.tv_plantowatch = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVCompleted(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_completed { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/completed?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_completed.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/shows/completed?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_completed = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_completed = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVHold(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_hold { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/hold?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_hold.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/shows/hold?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_hold = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_hold = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVDropped(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_dropped { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/dropped?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_dropped.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/shows/dropped?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_dropped = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_dropped = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVWatching(
  _ accessToken: String,
  _ lastActivity: String?,
  _ context: ModelContext,
  forceRefresh: Bool = false
) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if !forceRefresh, lastActivity == syncRecord!.tv_watching { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/watching?memos=yes&next_watch_info=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_watching.flatMap(formatter.date(from:)) {
      if forceRefresh || lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/shows/watching?memos=yes&next_watch_info=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_watching = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    let syncTimestamp = formatter.string(from: Date())
    for showItem in shows {
      context.insert(showItem.toSwiftData(syncedAt: syncTimestamp))
    }

    syncRecord!.tv_watching = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVRemovedFromList(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_removed_from_list { return }

    let endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows?extended=simkl_ids_only")!

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_removed_from_list = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    let currentSimklIds = Set(shows.compactMap { $0.show?.ids?.simkl })

    let existingShowsDescriptor = FetchDescriptor<V1.SDShows>()
    let existingShows = try context.fetch(existingShowsDescriptor)

    let showsToDelete = existingShows.filter { show in
      !currentSimklIds.contains(show.simkl)
    }

    for show in showsToDelete {
      context.delete(show)
    }

    syncRecord!.tv_removed_from_list = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVRatedAt(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_rated_at { return }

    var endpoint = URLComponents(string: "https://api.simkl.com/sync/ratings/tv?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_rated_at.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/ratings/tv?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_rated_at = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_rated_at = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimePlanToWatch(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_plantowatch { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/plantowatch?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_plantowatch.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/anime/plantowatch?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_plantowatch = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }
    await enrichAnimeReleaseDatesForPlanToWatch(animes, context, formatter)

    syncRecord!.anime_plantowatch = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeDropped(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_dropped { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/dropped?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_dropped.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/anime/dropped?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_dropped = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_dropped = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeCompleted(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_completed { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/completed?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_completed.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/anime/completed?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_completed = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_completed = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeHold(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_hold { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/hold?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_hold.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/anime/hold?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_hold = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_hold = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeWatching(
  _ accessToken: String,
  _ lastActivity: String?,
  _ context: ModelContext,
  forceRefresh: Bool = false
) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if !forceRefresh, lastActivity == syncRecord!.anime_watching { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/watching?memos=yes&next_watch_info=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_watching.flatMap(formatter.date(from:)) {
      if forceRefresh || lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/anime/watching?memos=yes&next_watch_info=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_watching = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    let syncTimestamp = formatter.string(from: Date())
    for animeItem in animes {
      context.insert(animeItem.toSwiftData(syncedAt: syncTimestamp))
    }

    syncRecord!.anime_watching = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeRemovedFromList(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_removed_from_list { return }

    let endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime?extended=simkl_ids_only")!

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_removed_from_list = lastActivity
      try context.save()
      return
    }

    let items = result.anime ?? []
    let currentSimklIds = Set(items.compactMap { $0.show?.ids.simkl })

    let existingShowsDescriptor = FetchDescriptor<V1.SDAnimes>()
    let existingShows = try context.fetch(existingShowsDescriptor)

    let showsToDelete = existingShows.filter { show in
      !currentSimklIds.contains(show.simkl)
    }

    for show in showsToDelete {
      context.delete(show)
    }

    syncRecord!.anime_removed_from_list = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeRatedAt(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_rated_at { return }

    var endpoint = URLComponents(string: "https://api.simkl.com/sync/ratings/anime?memos=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_rated_at.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/ratings/anime?memos=yes&date_from=\(dateFrom)"
        )!
      }
    }

    print("\(endpoint.url!)")
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.simklData(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_rated_at = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_rated_at = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

private let releaseDateEnrichmentMaxItemsPerRun = 20
private let releaseDateEnrichmentBackfillMaxItemsPerType = 8
private let releaseDateEnrichmentBackfillCandidateFetchLimit = releaseDateEnrichmentBackfillMaxItemsPerType * 4
private let releaseDateEnrichmentBackfillMinimumSeconds: TimeInterval = 6 * 60 * 60
private let releaseDateEnrichmentMaxConcurrent = 3
private let releaseDateEnrichmentRetryCount = 2

private enum ReleaseDateFetchType: Sendable {
  case movie
  case show
  case anime
}

private func backfillMissingPlanToWatchReleaseDates(_ context: ModelContext) async {
  let formatter = ISO8601DateFormatter()
  let earliestEligibleBackfillDate = Date().addingTimeInterval(-releaseDateEnrichmentBackfillMinimumSeconds)

  do {
    func shouldBackfill(lastSynced: String?) -> Bool {
      guard let lastSynced else { return true }
      guard let lastSyncedDate = formatter.date(from: lastSynced) else { return true }
      return lastSyncedDate <= earliestEligibleBackfillDate
    }

    var moviesDescriptor = FetchDescriptor<V1.SDMovies>(
      predicate: #Predicate { $0.status == "plantowatch" && $0.release_date == nil },
      sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
    )
    moviesDescriptor.fetchLimit = releaseDateEnrichmentBackfillCandidateFetchLimit
    let movieIDs = Array(
      try context.fetch(moviesDescriptor)
        .filter { shouldBackfill(lastSynced: $0.last_sd_synced_at) }
        .prefix(releaseDateEnrichmentBackfillMaxItemsPerType)
        .map { $0.simkl }
    )

    var showsDescriptor = FetchDescriptor<V1.SDShows>(
      predicate: #Predicate { $0.status == "plantowatch" && $0.release_date == nil },
      sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
    )
    showsDescriptor.fetchLimit = releaseDateEnrichmentBackfillCandidateFetchLimit
    let showIDs = Array(
      try context.fetch(showsDescriptor)
        .filter { shouldBackfill(lastSynced: $0.last_sd_synced_at) }
        .prefix(releaseDateEnrichmentBackfillMaxItemsPerType)
        .map { $0.simkl }
    )

    var animesDescriptor = FetchDescriptor<V1.SDAnimes>(
      predicate: #Predicate { $0.status == "plantowatch" && $0.release_date == nil },
      sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
    )
    animesDescriptor.fetchLimit = releaseDateEnrichmentBackfillCandidateFetchLimit
    let animeIDs = Array(
      try context.fetch(animesDescriptor)
        .filter { shouldBackfill(lastSynced: $0.last_sd_synced_at) }
        .prefix(releaseDateEnrichmentBackfillMaxItemsPerType)
        .map { $0.simkl }
    )

    await enrichMovieReleaseDatesForSimklIDs(movieIDs, context, formatter)
    await enrichShowReleaseDatesForSimklIDs(showIDs, context, formatter)
    await enrichAnimeReleaseDatesForSimklIDs(animeIDs, context, formatter)
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

private func enrichMovieReleaseDatesForPlanToWatch(
  _ movies: [MoviesModel_movie],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  let uniqueMovieIDs: [Int] = Array(Set(movies.compactMap { movieItem in
    guard movieItem.status == "plantowatch" else { return nil }
    return movieItem.movie?.ids?.simkl
  }))
  await enrichMovieReleaseDatesForSimklIDs(uniqueMovieIDs, context, formatter)
}

private func enrichShowReleaseDatesForPlanToWatch(
  _ shows: [TVModel_show],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  let uniqueShowIDs: [Int] = Array(Set(shows.compactMap { showItem in
    guard showItem.status == "plantowatch" else { return nil }
    return showItem.show?.ids?.simkl
  }))
  await enrichShowReleaseDatesForSimklIDs(uniqueShowIDs, context, formatter)
}

private func enrichAnimeReleaseDatesForPlanToWatch(
  _ animes: [AnimeModel_record],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  let uniqueAnimeIDs: [Int] = Array(Set(animes.compactMap { animeItem in
    guard animeItem.status == "plantowatch" else { return nil }
    return animeItem.show?.ids.simkl
  }))
  await enrichAnimeReleaseDatesForSimklIDs(uniqueAnimeIDs, context, formatter)
}

private func enrichMovieReleaseDatesForSimklIDs(
  _ simklIDs: [Int],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  if simklIDs.isEmpty { return }

  var candidateIDs: [Int] = []
  do {
    for simklID in simklIDs {
      let currentSimklID = simklID
      let descriptor = FetchDescriptor<V1.SDMovies>(
        predicate: #Predicate<V1.SDMovies> { $0.simkl == currentSimklID }
      )
      if let movie = try context.fetch(descriptor).first, movie.release_date == nil {
        candidateIDs.append(simklID)
      }
    }
  } catch {
    SentrySDK.capture(error: error)
    return
  }

  let cappedCandidates = Array(candidateIDs.prefix(releaseDateEnrichmentMaxItemsPerRun))
  if cappedCandidates.isEmpty { return }

  let releaseDateUpdates = await chunkedReleaseDateUpdates(cappedCandidates, mediaType: .movie)

  let syncTimestamp = formatter.string(from: Date())
  do {
    for update in releaseDateUpdates {
      let currentSimklID = update.simklID
      let descriptor = FetchDescriptor<V1.SDMovies>(
        predicate: #Predicate<V1.SDMovies> { $0.simkl == currentSimklID }
      )
      if let movie = try context.fetch(descriptor).first {
        movie.release_date = update.releaseDate
        movie.last_sd_synced_at = syncTimestamp
      }
    }
  } catch {
    SentrySDK.capture(error: error)
  }
}

private func enrichShowReleaseDatesForSimklIDs(
  _ simklIDs: [Int],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  if simklIDs.isEmpty { return }

  var candidateIDs: [Int] = []
  do {
    for simklID in simklIDs {
      let currentSimklID = simklID
      let descriptor = FetchDescriptor<V1.SDShows>(
        predicate: #Predicate<V1.SDShows> { $0.simkl == currentSimklID }
      )
      if let show = try context.fetch(descriptor).first, show.release_date == nil {
        candidateIDs.append(simklID)
      }
    }
  } catch {
    SentrySDK.capture(error: error)
    return
  }

  let cappedCandidates = Array(candidateIDs.prefix(releaseDateEnrichmentMaxItemsPerRun))
  if cappedCandidates.isEmpty { return }

  let releaseDateUpdates = await chunkedReleaseDateUpdates(cappedCandidates, mediaType: .show)

  let syncTimestamp = formatter.string(from: Date())
  do {
    for update in releaseDateUpdates {
      let currentSimklID = update.simklID
      let descriptor = FetchDescriptor<V1.SDShows>(
        predicate: #Predicate<V1.SDShows> { $0.simkl == currentSimklID }
      )
      if let show = try context.fetch(descriptor).first {
        show.release_date = update.releaseDate
        show.last_sd_synced_at = syncTimestamp
      }
    }
  } catch {
    SentrySDK.capture(error: error)
  }
}

private func enrichAnimeReleaseDatesForSimklIDs(
  _ simklIDs: [Int],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  if simklIDs.isEmpty { return }

  var candidateIDs: [Int] = []
  do {
    for simklID in simklIDs {
      let currentSimklID = simklID
      let descriptor = FetchDescriptor<V1.SDAnimes>(
        predicate: #Predicate<V1.SDAnimes> { $0.simkl == currentSimklID }
      )
      if let anime = try context.fetch(descriptor).first, anime.release_date == nil {
        candidateIDs.append(simklID)
      }
    }
  } catch {
    SentrySDK.capture(error: error)
    return
  }

  let cappedCandidates = Array(candidateIDs.prefix(releaseDateEnrichmentMaxItemsPerRun))
  if cappedCandidates.isEmpty { return }

  let releaseDateUpdates = await chunkedReleaseDateUpdates(cappedCandidates, mediaType: .anime)

  let syncTimestamp = formatter.string(from: Date())
  do {
    for update in releaseDateUpdates {
      let currentSimklID = update.simklID
      let descriptor = FetchDescriptor<V1.SDAnimes>(
        predicate: #Predicate<V1.SDAnimes> { $0.simkl == currentSimklID }
      )
      if let anime = try context.fetch(descriptor).first {
        anime.release_date = update.releaseDate
        anime.last_sd_synced_at = syncTimestamp
      }
    }
  } catch {
    SentrySDK.capture(error: error)
  }
}

private func chunkedReleaseDateUpdates(
  _ candidateIDs: [Int],
  mediaType: ReleaseDateFetchType
) async -> [(simklID: Int, releaseDate: String?)] {
  var releaseDateUpdates: [(simklID: Int, releaseDate: String?)] = []

  for chunkStart in stride(from: 0, to: candidateIDs.count, by: releaseDateEnrichmentMaxConcurrent) {
    let chunkEnd = min(chunkStart + releaseDateEnrichmentMaxConcurrent, candidateIDs.count)
    let chunk = Array(candidateIDs[chunkStart..<chunkEnd])

    await withTaskGroup(of: (Int, String?).self) { group in
      for simklID in chunk {
        group.addTask {
          let releaseDate: String?
          switch mediaType {
          case .movie:
            releaseDate = await fetchMovieReleaseDateWithRetry(simklID)
          case .show:
            releaseDate = await fetchShowReleaseDateWithRetry(simklID)
          case .anime:
            releaseDate = await fetchAnimeReleaseDateWithRetry(simklID)
          }
          return (simklID, releaseDate)
        }
      }

      for await update in group {
        releaseDateUpdates.append(update)
      }
    }
  }

  return releaseDateUpdates
}

private func fetchMovieReleaseDateWithRetry(_ simklID: Int) async -> String? {
  var retryDelayNanoseconds: UInt64 = 500_000_000

  for attempt in 0...releaseDateEnrichmentRetryCount {
    if let details = await MovieDetailView.getMovieDetails(simklID) {
      return normalizeReleaseDateString(details.released)
    }

    if attempt < releaseDateEnrichmentRetryCount {
      try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
      retryDelayNanoseconds *= 2
    }
  }

  return nil
}

private func fetchAnimeReleaseDateWithRetry(_ simklID: Int) async -> String? {
  var retryDelayNanoseconds: UInt64 = 500_000_000

  for attempt in 0...releaseDateEnrichmentRetryCount {
    if let details = await AnimeDetailView.getAnimeDetails(simklID) {
      return normalizeReleaseDateString(details.first_aired)
    }

    if attempt < releaseDateEnrichmentRetryCount {
      try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
      retryDelayNanoseconds *= 2
    }
  }

  return nil
}

private func fetchShowReleaseDateWithRetry(_ simklID: Int) async -> String? {
  var retryDelayNanoseconds: UInt64 = 500_000_000

  for attempt in 0...releaseDateEnrichmentRetryCount {
    if let details = await ShowDetailView.getShowDetails(simklID) {
      return normalizeReleaseDateString(details.first_aired)
    }

    if attempt < releaseDateEnrichmentRetryCount {
      try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
      retryDelayNanoseconds *= 2
    }
  }

  return nil
}

// Trending CDN returns release_date as "MM/DD/YYYY" — year is the last component.
// Defensive parse handles unusual formats by returning nil if no sensible year is found.
func yearFromTrendingReleaseDate(_ raw: String?) -> Int? {
  guard let raw, !raw.isEmpty else { return nil }
  let separator: Character = raw.contains("/") ? "/" : "-"
  let parts = raw.split(separator: separator)
  // Try the last component first (MM/DD/YYYY), then the first (YYYY-MM-DD).
  for candidate in [parts.last, parts.first].compactMap({ $0 }) {
    if let year = Int(candidate), year > 1800, year < 2200 {
      return year
    }
  }
  return nil
}

func syncLatestTrending(_ accessToken: String, _ context: ModelContext) async {
  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    let now = Date()
    let twentyFourHoursInSeconds: TimeInterval = 24 * 60 * 60
    let twentyFourHoursAgo = now.addingTimeInterval(-twentyFourHoursInSeconds)
    var needsSync = false
    if let lastSyncDate = syncRecord!.trending_data {
      if lastSyncDate < twentyFourHoursAgo.ISO8601Format() {
        needsSync = true
      }
    } else {
      needsSync = true
    }
    if !needsSync { return }

    let movies = await getTrendingMovies()
    let shows = await getTrendingShows()
    let animes = await getTrendingAnimes()

    let oldMovies = try? context.fetch(FetchDescriptor<V1.TrendingMovies>())
    oldMovies?.forEach { context.delete($0) }
    for (index, movieItem) in movies.enumerated() {
      context.insert(
        V1.TrendingMovies(
          simkl: movieItem.ids.simkl_id,
          title: movieItem.title,
          poster: movieItem.poster,
          order: index + 1,
          year: yearFromTrendingReleaseDate(movieItem.release_date)
        )
      )
    }

    let oldShows = try? context.fetch(FetchDescriptor<V1.TrendingShows>())
    oldShows?.forEach { context.delete($0) }
    for (index, showItem) in shows.enumerated() {
      context.insert(
        V1.TrendingShows(
          simkl: showItem.ids.simkl_id,
          title: showItem.title,
          poster: showItem.poster,
          order: index + 1,
          year: yearFromTrendingReleaseDate(showItem.release_date)
        )
      )
    }

    let oldAnimes = try? context.fetch(FetchDescriptor<V1.TrendingAnimes>())
    oldAnimes?.forEach { context.delete($0) }
    for (index, animeItem) in animes.enumerated() {
      context.insert(
        V1.TrendingAnimes(
          simkl: animeItem.ids.simkl_id,
          title: animeItem.title,
          poster: animeItem.poster,
          order: index + 1,
          year: yearFromTrendingReleaseDate(animeItem.release_date)
        )
      )
    }

    syncRecord!.trending_data = now.ISO8601Format()
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func processUpNextEpisodes(
  _ accessToken: String,
  _ context: ModelContext,
  forceRefresh: Bool = false
) async {
  let formatter = ISO8601DateFormatter()
  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    let now = Date()
    let sixHoursInSeconds: TimeInterval = 6 * 60 * 60
    let sixHoursAgo = now.addingTimeInterval(-sixHoursInSeconds)
    var needsSync = forceRefresh
    if !needsSync {
      if let lastSyncDateStr = syncRecord!.changes_api,
        let lastSyncDate = formatter.date(from: lastSyncDateStr)
      {
        if lastSyncDate < sixHoursAgo {
          needsSync = true
        }
      } else {
        needsSync = true
      }
    }
    if !needsSync { return }
    var sdShowsFD = FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.status == "watching" })
    sdShowsFD.propertiesToFetch = [\.simkl]
    let sdShowsIds = try context.fetch(sdShowsFD)

    var sdAnimesFD = FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.status == "watching" && $0.anime_type == "tv" })
    sdAnimesFD.propertiesToFetch = [\.simkl]
    let sdAnimesIds = try context.fetch(sdAnimesFD)

    // Batch the /sync/watched lookups: docs warn against per-item calls when
    // /sync/all-items is also in use. One request handles up to 100 shows.
    // We index by simkl with a last-write-wins merge so an unexpected
    // duplicate from the server can't crash the sync (uniqueKeysWithValues
    // would). `hadFailures` propagates so we can skip stamping the 6h cache
    // when any chunk failed (otherwise stale rows stay stale for 6h).
    let showWatchedBatch = await ShowDetailView.getShowWatchlistBatch(
      sdShowsIds.map { $0.simkl }, accessToken
    )
    let showWatchedByID = Dictionary(
      showWatchedBatch.items.map { ($0.simkl, $0) },
      uniquingKeysWith: { _, last in last }
    )

    for show in sdShowsIds {
      let watchedEpisodes = showWatchedByID[show.simkl]

      guard
        let watched = watchedEpisodes,
        (watched.episodes_aired ?? 0) > (watched.episodes_watched ?? 0),
        let seasons = watched.seasons
      else { continue }

      let allEpisodes = await ShowDetailView.getShowEpisodes(show.simkl)

      // All episodes that have aired but are not marked as watched
      let unwatched =
        allEpisodes
        .filter { $0.aired == true }
        .filter { episode in
          guard
            let seasonNum = episode.season,
            let epNum = episode.episode
          else { return false }

          let isWatched =
            seasons
            .first(where: { $0.number == seasonNum })?
            .episodes?
            .first(where: { $0.number == epNum })?
            .watched ?? false

          return !isWatched
        }

      // All episodes that *have* been watched
      let actuallyWatchedEpisodes = allEpisodes.filter { episode in
        guard
          let seasonNum = episode.season,
          let epNum = episode.episode
        else { return false }

        return
          seasons
          .first(where: { $0.number == seasonNum })?
          .episodes?
          .first(where: { $0.number == epNum })?
          .watched ?? false
      }

      // Find the highest watched episode (latest)
      let highestWatched =
        actuallyWatchedEpisodes
        .sorted(by: { ($0.season ?? 0, $0.episode ?? 0) > ($1.season ?? 0, $1.episode ?? 0) })
        .first

      // Find the first unwatched episode that comes *after* the highest watched
      let nextUnwatched =
        unwatched
        .filter { episode in
          guard let highest = highestWatched else { return true }  // no episodes watched yet
          let current = (episode.season ?? 0, episode.episode ?? 0)
          let highestSeen = (highest.season ?? 0, highest.episode ?? 0)
          return current > highestSeen
        }
        .sorted(by: { ($0.season ?? 0, $0.episode ?? 0) < ($1.season ?? 0, $1.episode ?? 0) })  // get the next in order
        .first

      if let latest = nextUnwatched {
        print("Updating", show.simkl)

        let simklId = show.simkl  // capture value outside the predicate

        let fetchDescriptor = FetchDescriptor<V1.SDShows>(
          predicate: #Predicate<V1.SDShows> { $0.simkl == simklId }
        )

        if let existingShow = try context.fetch(fetchDescriptor).first {
          existingShow.next_to_watch_info_title = latest.title
          existingShow.next_to_watch_info_season = latest.season
          existingShow.next_to_watch_info_episode = latest.episode
          existingShow.next_to_watch_info_date = latest.date

          try context.save()
        }
      }
    }

    let animeWatchedBatch = await AnimeDetailView.getAnimeWatchlistBatch(
      sdAnimesIds.map { $0.simkl }, accessToken
    )
    let animeWatchedByID = Dictionary(
      animeWatchedBatch.items.map { ($0.simkl, $0) },
      uniquingKeysWith: { _, last in last }
    )

    for anime in sdAnimesIds {
      let watchedEpisodes = animeWatchedByID[anime.simkl]

      guard
        let watched = watchedEpisodes,
        (watched.episodes_aired ?? 0) > (watched.episodes_watched ?? 0),
        let seasons = watched.seasons
      else { continue }

      let allEpisodes = await AnimeDetailView.getAnimeEpisodes(anime.simkl, countSeasons: false)

      // Anime: /anime/episodes returns episodes with season:nil. The
      // /sync/watched response groups them under season 0 (specials) and
      // season 1 (main run). getAnimeEpisodes(countSeasons: false) maps
      // type=="special" -> 0 and everything else -> 1, so we can match.
      let watchedLookup: (Int, Int) -> Bool = { seasonNum, epNum in
        seasons
          .first(where: { $0.number == seasonNum })?
          .episodes?
          .first(where: { $0.number == epNum })?
          .watched ?? false
      }

      // Exclude specials (season 0 per getAnimeEpisodes mapping). SDAnimes
      // doesn't persist next_to_watch_info_season, and the UpNext swipe
      // path hardcodes season=1 for anime — so surfacing a special as
      // "next" would POST to season 1 + the special's episode number and
      // mark the wrong episode (or no-op). Until anime season is plumbed
      // through SDAnimes + UpNext, restrict to main-run.
      let unwatched =
        allEpisodes
        .filter { $0.aired == true }
        .filter { ($0.season ?? 1) != 0 }
        .filter { episode in
          guard let epNum = episode.episode else { return false }
          let seasonNum = episode.season ?? 1
          return !watchedLookup(seasonNum, epNum)
        }

      let actuallyWatchedEpisodes = allEpisodes
        .filter { ($0.season ?? 1) != 0 }
        .filter { episode in
          guard let epNum = episode.episode else { return false }
          let seasonNum = episode.season ?? 1
          return watchedLookup(seasonNum, epNum)
        }

      // Find the highest watched episode (latest)
      let highestWatched =
        actuallyWatchedEpisodes
        .sorted(by: { ($0.season ?? 1, $0.episode ?? 0) > ($1.season ?? 1, $1.episode ?? 0) })
        .first

      // Find the first unwatched episode that comes *after* the highest watched
      let nextUnwatched =
        unwatched
        .filter { episode in
          guard let highest = highestWatched else { return true }  // no episodes watched yet
          let current = (episode.season ?? 1, episode.episode ?? 0)
          let highestSeen = (highest.season ?? 1, highest.episode ?? 0)
          return current > highestSeen
        }
        .sorted(by: { ($0.season ?? 1, $0.episode ?? 0) < ($1.season ?? 1, $1.episode ?? 0) })  // get the next in order
        .first

      if let latest = nextUnwatched {
        print("Updating", anime.simkl)

        let simklId = anime.simkl  // capture value outside the predicate

        let fetchDescriptor = FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate<V1.SDAnimes> { $0.simkl == simklId }
        )

        if let existingShow = try context.fetch(fetchDescriptor).first {
          existingShow.next_to_watch_info_title = latest.title
          existingShow.next_to_watch_info_episode = latest.episode
          existingShow.next_to_watch_info_date = latest.date

          try context.save()
        }
      }
    }

    // Only stamp the 6h cache as fresh if every batch chunk succeeded.
    // If a /sync/watched chunk failed (rate limit, auth, network), the
    // affected shows/anime kept their previous next_to_watch_info — we
    // need the next scheduled run to retry instead of skipping for 6h.
    if !showWatchedBatch.hadFailures && !animeWatchedBatch.hadFailures {
      syncRecord!.changes_api = now.ISO8601Format()
    }
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}
// TODO: Widgets with next episode and show progress
// TODO: Sync calendar data for "new" and notifications

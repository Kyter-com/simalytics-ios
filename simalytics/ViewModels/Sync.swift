//
//  FetchLatestActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import Sentry
import SwiftData

actor SyncLatestActivitiesGate {
  private var isRunning = false
  private var pendingSync = false
  private var pendingForceRefresh = false

  func begin(forceRefresh: Bool) -> Bool {
    guard !isRunning else {
      pendingSync = true
      pendingForceRefresh = pendingForceRefresh || forceRefresh
      return false
    }

    isRunning = true
    return true
  }

  func finishCurrentRun(discardPending: Bool = false) -> Bool? {
    if discardPending {
      pendingSync = false
      pendingForceRefresh = false
    }
    guard pendingSync else {
      isRunning = false
      pendingForceRefresh = false
      return nil
    }

    let forceRefresh = pendingForceRefresh
    pendingSync = false
    pendingForceRefresh = false
    return forceRefresh
  }
}

private let syncLatestActivitiesGate = SyncLatestActivitiesGate()

private func ensureLastSyncRecord(_ container: ModelContainer) async throws {
  let context = makeSyncContext(container)
  let existing = try context.fetch(
    FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
  ).first
  guard existing == nil else { return }
  context.insert(V1.SDLastSync(id: 1))
  try await saveSyncContext(context)
}

func syncLatestActivities(
  _ accessToken: String,
  modelContainer: ModelContainer,
  forceRefresh: Bool = false
) async {
  #if DEBUG
    // Screenshot harness: the store is pre-seeded with public-domain fixtures and
    // must stay offline, so every sync path (launch, pull-to-refresh, tab .task,
    // mark-watched) is a no-op. See ScreenshotMode.
    if ScreenshotMode.isActive { return }
  #endif
  // A caller that captured a token before sign-out must not resync that account.
  guard SyncAccount.isActive(accessToken) else { return }
  var runForceRefresh = forceRefresh
  guard await syncLatestActivitiesGate.begin(forceRefresh: forceRefresh) else { return }

  while true {
    let syncStartedAt = Date()
    addSyncLifecycleBreadcrumb(message: "Sync started", forceRefresh: runForceRefresh)
    let outcome = await SyncFailureScope.perform(accessToken: accessToken) {
      await runSyncLatestActivities(
        accessToken, modelContainer: modelContainer, forceRefresh: runForceRefresh)
    }
    addSyncLifecycleBreadcrumb(
      message: outcome == .succeeded ? "Sync completed" : "Sync interrupted",
      forceRefresh: runForceRefresh,
      duration: Date().timeIntervalSince(syncStartedAt)
    )

    let nextForceRefresh = await syncLatestActivitiesGate.finishCurrentRun(
      discardPending: outcome.shouldDiscardPendingSync
    )
    if case .storageFailure(let failure) = outcome {
      await MainActor.run {
        NotificationCenter.default.post(name: .syncStorageFailed, object: failure)
      }
    }
    guard let nextForceRefresh else { break }
    runForceRefresh = nextForceRefresh
  }

  await MainActor.run {
    NotificationCenter.default.post(name: .localMediaSnapshotsDidChange, object: nil)
  }
}

private func addSyncLifecycleBreadcrumb(
  message: String,
  forceRefresh: Bool,
  duration: TimeInterval? = nil
) {
  let breadcrumb = Breadcrumb(level: .info, category: "sync.lifecycle")
  breadcrumb.type = "debug"
  breadcrumb.message = message
  breadcrumb.setData(value: forceRefresh, key: "force_refresh")
  if let duration {
    breadcrumb.setData(value: Int((duration * 1_000).rounded()), key: "duration_ms")
  }
  SentrySDK.addBreadcrumb(breadcrumb)
}

private func runSyncLatestActivities(
  _ accessToken: String,
  modelContainer: ModelContainer,
  forceRefresh: Bool = false
) async {
  let syncStartedTimestamp = Date().ISO8601Format()
  do {
    try await SyncFailureScope.check()
    try await ensureLastSyncRecord(modelContainer)
    let urlComponents = URLComponents(string: "https://api.simkl.com/sync/activities")!
    var request = URLRequest(url: urlComponents.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await performSimklRequest(request)
    let result = try JSONDecoder().decode(LastActivitiesModel.self, from: data)

    let cacheContext = makeSyncContext(modelContainer)
    let lastSync = try cacheContext.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    let refreshUpNext = forceRefresh || shouldRefreshUpNext(lastRefresh: lastSync?.changes_api)
    var showsRefreshed = false
    var animeRefreshed = false

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
    // below. Watching summaries also refresh on the six-hour catalog gate,
    // since catalog corrections need not appear in a user-activity delta.
    func step(_ activity: String?, _ handler: (String, String?, ModelContext) async -> Void) async throws {
      try await SyncFailureScope.step {
        await handler(accessToken, activity, makeSyncContext(modelContainer))
      }
    }

    try await step(result.movies?.plantowatch) { token, activity, context in
      await fetchAndStoreMoviesPlanToWatch(token, activity, context)
    }
    try await step(result.movies?.dropped, fetchAndStoreMoviesDropped)
    try await step(result.movies?.completed, fetchAndStoreMoviesCompleted)
    try await step(result.movies?.removed_from_list) { token, activity, context in
      await fetchAndStoreMoviesRemovedFromList(token, activity, context)
    }
    try await step(result.movies?.rated_at, fetchAndStoreMoviesRatedAt)
    try await step(result.tv_shows?.plantowatch, fetchAndStoreTVPlanToWatch)
    try await step(result.tv_shows?.completed, fetchAndStoreTVCompleted)
    try await step(result.tv_shows?.hold, fetchAndStoreTVHold)
    try await step(result.tv_shows?.dropped, fetchAndStoreTVDropped)
    try await step(result.tv_shows?.watching) { token, activity, ctx in
      showsRefreshed = await fetchAndStoreTVWatching(
        token, activity, ctx, forceRefresh: refreshUpNext)
    }
    try await step(result.tv_shows?.removed_from_list) { token, activity, context in
      await fetchAndStoreTVRemovedFromList(token, activity, context)
    }
    try await step(result.tv_shows?.rated_at, fetchAndStoreTVRatedAt)
    try await step(result.anime?.plantowatch, fetchAndStoreAnimePlanToWatch)
    try await step(result.anime?.dropped, fetchAndStoreAnimeDropped)
    try await step(result.anime?.completed, fetchAndStoreAnimeCompleted)
    try await step(result.anime?.hold, fetchAndStoreAnimeHold)
    try await step(result.anime?.rated_at, fetchAndStoreAnimeRatedAt)
    try await step(result.anime?.removed_from_list) { token, activity, context in
      await fetchAndStoreAnimeRemovedFromList(token, activity, context)
    }
    try await step(result.anime?.watching) { token, activity, ctx in
      animeRefreshed = await fetchAndStoreAnimeWatching(
        token, activity, ctx, forceRefresh: refreshUpNext)
    }

    // Stale-data refresh (per-id detail endpoints) also writes to SDLastSync,
    // so it's sequenced here for the same last-write-wins reason. Its internal
    // network work parallelizes independently — only the final SDLastSync
    // write needs ordering. Explore's trending data lives in DiscoverStore.
    try await SyncFailureScope.step {
      await refreshStaleData(accessToken, makeSyncContext(modelContainer))
    }

    // Trust SIMKL's next_to_watch marker instead of rebuilding it from counts
    // and catalog episodes. A nil marker clears old info through the upsert.
    // Failed requests must not make stale data look fresh for six hours.
    if refreshUpNext, showsRefreshed, animeRefreshed, !Task.isCancelled {
      let context = makeSyncContext(modelContainer)
      if let record = try context.fetch(
        FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
      ).first {
        record.changes_api = syncStartedTimestamp
        try await saveSyncContext(context)
      }
    }

    let releaseDateContext = makeSyncContext(modelContainer)
    await backfillMissingPlanToWatchReleaseDates(releaseDateContext)
  } catch {
    await SyncFailureScope.report(error)
  }
}

func fetchAndStoreMoviesPlanToWatch(
  _ accessToken: String, _ lastActivity: String?, _ context: ModelContext,
  session: URLSession = .shared
) async {
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

    let (data, _) = try await performSimklRequest(request, session: session)
    let movies = try decodeSimklLibraryResponse(MoviesModel_movie.self, from: data, key: "movies")
    guard movies.allSatisfy({ ($0.movie?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }
    await enrichMovieReleaseDatesForPlanToWatch(movies, context, formatter)

    syncRecord!.movies_plantowatch = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let movies = try decodeSimklLibraryResponse(MoviesModel_movie.self, from: data, key: "movies")
    guard movies.allSatisfy({ ($0.movie?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }

    syncRecord!.movies_dropped = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let movies = try decodeSimklLibraryResponse(MoviesModel_movie.self, from: data, key: "movies")
    guard movies.allSatisfy({ ($0.movie?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }

    syncRecord!.movies_completed = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
  }
}

func fetchAndStoreMoviesRemovedFromList(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext, session: URLSession = .shared) async {
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

    let (data, _) = try await performSimklRequest(request, session: session)
    let movies = try decodeSimklLibraryResponse(MoviesModel_movie.self, from: data, key: "movies")
    guard movies.allSatisfy({ ($0.movie?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
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
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let movies = try decodeSimklLibraryResponse(MoviesModel_movie.self, from: data, key: "movies")
    guard movies.allSatisfy({ ($0.movie?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for movieItem in movies {
      context.insert(movieItem.toSwiftData())
    }

    syncRecord!.movies_rated_at = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }
    await enrichShowReleaseDatesForPlanToWatch(shows, context, formatter)

    syncRecord!.tv_plantowatch = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_completed = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_hold = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_dropped = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
  }
}

@discardableResult
func fetchAndStoreTVWatching(
  _ accessToken: String,
  _ lastActivity: String?,
  _ context: ModelContext,
  forceRefresh: Bool = false,
  session: URLSession = .shared
) async -> Bool {
  guard lastActivity != nil || forceRefresh else { return true }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if !forceRefresh, lastActivity == syncRecord!.tv_watching { return true }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/watching?memos=yes&next_watch_info=yes")!

    if !forceRefresh,
      let lastActivityDate = lastActivity.flatMap(formatter.date(from:)),
      let previousSyncDate = syncRecord!.tv_watching.flatMap(formatter.date(from:))
    {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/shows/watching?memos=yes&next_watch_info=yes&date_from=\(dateFrom)"
        )!
      }
    }

    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await performSimklRequest(request, session: session)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 && $0.status == "watching" }) else {
      throw SimklMutationError.invalidResponse
    }
    // Clear queue metadata for absent titles only on a full response. They may
    // have moved to another list; preserve their library row and other metadata.
    if endpoint.queryItems?.contains(where: { $0.name == "date_from" }) != true {
      let ids = Set(shows.compactMap { $0.show?.ids?.simkl })
      for row in try context.fetch(FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.status == "watching" }))
        where !ids.contains(row.simkl)
      {
        row.next_to_watch = nil
        row.next_to_watch_info_title = nil
        row.next_to_watch_info_season = nil
        row.next_to_watch_info_episode = nil
        row.next_to_watch_info_date = nil
      }
    }
    let syncTimestamp = formatter.string(from: Date())
    var byID = Dictionary(try context.fetch(FetchDescriptor<V1.SDShows>()).map { ($0.simkl, $0) }, uniquingKeysWith: { first, _ in first })
    for showItem in shows {
      let id = showItem.show!.ids!.simkl  // Validated above before any mutations.
      if let existing = byID[id] {
        showItem.updateWatchingSummary(existing, syncedAt: syncTimestamp)
      } else {
        let row = showItem.toSwiftData(syncedAt: syncTimestamp)
        context.insert(row)
        byID[id] = row
      }
    }

    syncRecord!.tv_watching = lastActivity
    try await saveSyncContext(context)
    return true
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
    return false
  }
}

func fetchAndStoreTVRemovedFromList(
  _ accessToken: String, _ lastActivity: String?, _ context: ModelContext,
  session: URLSession = .shared
) async {
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

    let (data, _) = try await performSimklRequest(request, session: session)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
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
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let shows = try decodeSimklLibraryResponse(TVModel_show.self, from: data, key: "shows")
    guard shows.allSatisfy({ ($0.show?.ids?.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for showItem in shows {
      context.insert(showItem.toSwiftData())
    }

    syncRecord!.tv_rated_at = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let animes = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard animes.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }
    await enrichAnimeReleaseDatesForPlanToWatch(animes, context, formatter)

    syncRecord!.anime_plantowatch = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let animes = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard animes.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_dropped = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let animes = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard animes.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_completed = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let animes = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard animes.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_hold = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
  }
}

@discardableResult
func fetchAndStoreAnimeWatching(
  _ accessToken: String,
  _ lastActivity: String?,
  _ context: ModelContext,
  forceRefresh: Bool = false,
  session: URLSession = .shared
) async -> Bool {
  guard lastActivity != nil || forceRefresh else { return true }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if !forceRefresh, lastActivity == syncRecord!.anime_watching { return true }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/watching?memos=yes&next_watch_info=yes")!

    if !forceRefresh,
      let lastActivityDate = lastActivity.flatMap(formatter.date(from:)),
      let previousSyncDate = syncRecord!.anime_watching.flatMap(formatter.date(from:))
    {
      if lastActivityDate > previousSyncDate {
        let dateFrom = formatter.string(
          from: Calendar.current.date(byAdding: .minute, value: -5, to: previousSyncDate)!)
        endpoint = URLComponents(
          string:
            "https://api.simkl.com/sync/all-items/anime/watching?memos=yes&next_watch_info=yes&date_from=\(dateFrom)"
        )!
      }
    }

    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await performSimklRequest(request, session: session)
    let animes = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard animes.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 && $0.status == "watching" }) else {
      throw SimklMutationError.invalidResponse
    }
    if endpoint.queryItems?.contains(where: { $0.name == "date_from" }) != true {
      let ids = Set(animes.compactMap { $0.show?.ids.simkl })
      for row in try context.fetch(FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.status == "watching" }))
        where !ids.contains(row.simkl)
      {
        row.next_to_watch = nil
        row.next_to_watch_info_title = nil
        row.next_to_watch_info_episode = nil
        row.next_to_watch_info_date = nil
      }
    }
    let syncTimestamp = formatter.string(from: Date())
    var byID = Dictionary(try context.fetch(FetchDescriptor<V1.SDAnimes>()).map { ($0.simkl, $0) }, uniquingKeysWith: { first, _ in first })
    for animeItem in animes {
      let id = animeItem.show!.ids.simkl  // Validated above before any mutations.
      if let existing = byID[id] {
        animeItem.updateWatchingSummary(existing, syncedAt: syncTimestamp)
      } else {
        let row = animeItem.toSwiftData(syncedAt: syncTimestamp)
        context.insert(row)
        byID[id] = row
      }
    }

    syncRecord!.anime_watching = lastActivity
    try await saveSyncContext(context)
    return true
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
    return false
  }
}

func fetchAndStoreAnimeRemovedFromList(
  _ accessToken: String, _ lastActivity: String?, _ context: ModelContext,
  session: URLSession = .shared
) async {
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

    let (data, _) = try await performSimklRequest(request, session: session)
    let items = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard items.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
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
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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

    let (data, _) = try await performSimklRequest(request)
    let animes = try decodeSimklLibraryResponse(AnimeModel_record.self, from: data, key: "anime")
    guard animes.allSatisfy({ ($0.show?.ids.simkl ?? 0) > 0 }) else {
      throw SimklMutationError.invalidResponse
    }
    for animeItem in animes {
      context.insert(animeItem.toSwiftData())
    }

    syncRecord!.anime_rated_at = lastActivity
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
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
    try await SyncFailureScope.check()
    await enrichShowReleaseDatesForSimklIDs(showIDs, context, formatter)
    try await SyncFailureScope.check()
    await enrichAnimeReleaseDatesForSimklIDs(animeIDs, context, formatter)
    try await saveSyncContext(context)
  } catch {
    context.rollback()
    await SyncFailureScope.report(error)
  }
}

private func enrichMovieReleaseDatesForPlanToWatch(
  _ movies: [MoviesModel_movie],
  _ context: ModelContext,
  _ formatter: ISO8601DateFormatter
) async {
  let uniqueMovieIDs: [Int] = Array(
    Set(
      movies.compactMap { movieItem in
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
  let uniqueShowIDs: [Int] = Array(
    Set(
      shows.compactMap { showItem in
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
  let uniqueAnimeIDs: [Int] = Array(
    Set(
      animes.compactMap { animeItem in
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
    context.rollback()
    await SyncFailureScope.report(error)
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
    context.rollback()
    await SyncFailureScope.report(error)
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
    context.rollback()
    await SyncFailureScope.report(error)
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
    context.rollback()
    await SyncFailureScope.report(error)
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
    context.rollback()
    await SyncFailureScope.report(error)
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
    context.rollback()
    await SyncFailureScope.report(error)
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
  var retryDelay = Duration.milliseconds(500)

  for attempt in 0...releaseDateEnrichmentRetryCount {
    guard !Task.isCancelled else { return nil }
    if let details = await MovieDetailView.getMovieDetails(simklID) {
      return normalizeReleaseDateString(details.released)
    }

    if attempt < releaseDateEnrichmentRetryCount {
      do {
        try await Task.sleep(for: retryDelay)
      } catch {
        return nil
      }
      retryDelay += retryDelay
    }
  }

  return nil
}

private func fetchAnimeReleaseDateWithRetry(_ simklID: Int) async -> String? {
  var retryDelay = Duration.milliseconds(500)

  for attempt in 0...releaseDateEnrichmentRetryCount {
    guard !Task.isCancelled else { return nil }
    if let details = await AnimeDetailView.getAnimeDetails(simklID) {
      return normalizeReleaseDateString(details.first_aired)
    }

    if attempt < releaseDateEnrichmentRetryCount {
      do {
        try await Task.sleep(for: retryDelay)
      } catch {
        return nil
      }
      retryDelay += retryDelay
    }
  }

  return nil
}

private func fetchShowReleaseDateWithRetry(_ simklID: Int) async -> String? {
  var retryDelay = Duration.milliseconds(500)

  for attempt in 0...releaseDateEnrichmentRetryCount {
    guard !Task.isCancelled else { return nil }
    if let details = await ShowDetailView.getShowDetails(simklID) {
      return normalizeReleaseDateString(details.first_aired)
    }

    if attempt < releaseDateEnrichmentRetryCount {
      do {
        try await Task.sleep(for: retryDelay)
      } catch {
        return nil
      }
      retryDelay += retryDelay
    }
  }

  return nil
}

// TODO: Widgets with next episode and show progress
// TODO: Sync calendar data for "new" and notifications

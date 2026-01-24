//
//  StaleDataRefresh.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/22/26.
//

import Foundation
import Sentry
import SwiftData

func refreshStaleData(_ accessToken: String, _ context: ModelContext) async {
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    // Check if 24 hours have passed since last stale data refresh
    let now = Date()
    let twentyFourHoursInSeconds: TimeInterval = 24 * 60 * 60
    let twentyFourHoursAgo = now.addingTimeInterval(-twentyFourHoursInSeconds)

    if let lastRefreshStr = syncRecord!.stale_data_refresh,
       let lastRefreshDate = formatter.date(from: lastRefreshStr) {
      if lastRefreshDate >= twentyFourHoursAgo {
        return
      }
    }

    print("Starting stale data refresh...")

    // Get plantowatch items, prioritizing those never synced (nil) then oldest synced
    // Fetch items with nil last_sd_synced_at first, then items with oldest timestamps
    var planToWatchItems: [(type: String, simkl: Int, lastSynced: String?)] = []

    // First: get plantowatch items that have NEVER been synced (nil last_sd_synced_at)
    var moviesNeverSyncedDescriptor = FetchDescriptor<V1.SDMovies>(
      predicate: #Predicate { $0.status == "plantowatch" && $0.last_sd_synced_at == nil }
    )
    moviesNeverSyncedDescriptor.fetchLimit = 10
    for movie in try context.fetch(moviesNeverSyncedDescriptor) {
      planToWatchItems.append((type: "movie", simkl: movie.simkl, lastSynced: nil))
    }

    var showsNeverSyncedDescriptor = FetchDescriptor<V1.SDShows>(
      predicate: #Predicate { $0.status == "plantowatch" && $0.last_sd_synced_at == nil }
    )
    showsNeverSyncedDescriptor.fetchLimit = 10
    for show in try context.fetch(showsNeverSyncedDescriptor) {
      planToWatchItems.append((type: "show", simkl: show.simkl, lastSynced: nil))
    }

    var animesNeverSyncedDescriptor = FetchDescriptor<V1.SDAnimes>(
      predicate: #Predicate { $0.status == "plantowatch" && $0.last_sd_synced_at == nil }
    )
    animesNeverSyncedDescriptor.fetchLimit = 10
    for anime in try context.fetch(animesNeverSyncedDescriptor) {
      planToWatchItems.append((type: "anime", simkl: anime.simkl, lastSynced: nil))
    }

    // If we have fewer than 10 never-synced plantowatch, get oldest synced plantowatch
    if planToWatchItems.count < 10 {
      let remaining = 10 - planToWatchItems.count

      var moviesSyncedDescriptor = FetchDescriptor<V1.SDMovies>(
        predicate: #Predicate { $0.status == "plantowatch" && $0.last_sd_synced_at != nil },
        sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
      )
      moviesSyncedDescriptor.fetchLimit = remaining
      for movie in try context.fetch(moviesSyncedDescriptor) {
        planToWatchItems.append((type: "movie", simkl: movie.simkl, lastSynced: movie.last_sd_synced_at))
      }

      var showsSyncedDescriptor = FetchDescriptor<V1.SDShows>(
        predicate: #Predicate { $0.status == "plantowatch" && $0.last_sd_synced_at != nil },
        sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
      )
      showsSyncedDescriptor.fetchLimit = remaining
      for show in try context.fetch(showsSyncedDescriptor) {
        planToWatchItems.append((type: "show", simkl: show.simkl, lastSynced: show.last_sd_synced_at))
      }

      var animesSyncedDescriptor = FetchDescriptor<V1.SDAnimes>(
        predicate: #Predicate { $0.status == "plantowatch" && $0.last_sd_synced_at != nil },
        sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
      )
      animesSyncedDescriptor.fetchLimit = remaining
      for anime in try context.fetch(animesSyncedDescriptor) {
        planToWatchItems.append((type: "anime", simkl: anime.simkl, lastSynced: anime.last_sd_synced_at))
      }

      // Sort the synced items by oldest first and take what we need
      let neverSyncedCount = planToWatchItems.filter { $0.lastSynced == nil }.count
      let syncedItems = planToWatchItems.filter { $0.lastSynced != nil }
        .sorted { $0.lastSynced! < $1.lastSynced! }
        .prefix(remaining)
      planToWatchItems = planToWatchItems.filter { $0.lastSynced == nil } + Array(syncedItems)
    }

    // Take up to 10 plantowatch items
    var itemsToRefresh = Array(planToWatchItems.prefix(10))

    // If we need more items, get from other statuses (same nil-first logic)
    if itemsToRefresh.count < 10 {
      let remaining = 10 - itemsToRefresh.count
      var otherItems: [(type: String, simkl: Int, lastSynced: String?)] = []

      // First: never-synced items from other statuses
      var moviesOtherNeverSyncedDescriptor = FetchDescriptor<V1.SDMovies>(
        predicate: #Predicate { $0.status != "plantowatch" && $0.last_sd_synced_at == nil }
      )
      moviesOtherNeverSyncedDescriptor.fetchLimit = remaining
      for movie in try context.fetch(moviesOtherNeverSyncedDescriptor) {
        otherItems.append((type: "movie", simkl: movie.simkl, lastSynced: nil))
      }

      var showsOtherNeverSyncedDescriptor = FetchDescriptor<V1.SDShows>(
        predicate: #Predicate { $0.status != "plantowatch" && $0.last_sd_synced_at == nil }
      )
      showsOtherNeverSyncedDescriptor.fetchLimit = remaining
      for show in try context.fetch(showsOtherNeverSyncedDescriptor) {
        otherItems.append((type: "show", simkl: show.simkl, lastSynced: nil))
      }

      var animesOtherNeverSyncedDescriptor = FetchDescriptor<V1.SDAnimes>(
        predicate: #Predicate { $0.status != "plantowatch" && $0.last_sd_synced_at == nil }
      )
      animesOtherNeverSyncedDescriptor.fetchLimit = remaining
      for anime in try context.fetch(animesOtherNeverSyncedDescriptor) {
        otherItems.append((type: "anime", simkl: anime.simkl, lastSynced: nil))
      }

      // If still need more, get oldest synced from other statuses
      if otherItems.count < remaining {
        let stillRemaining = remaining - otherItems.count

        var moviesOtherSyncedDescriptor = FetchDescriptor<V1.SDMovies>(
          predicate: #Predicate { $0.status != "plantowatch" && $0.last_sd_synced_at != nil },
          sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
        )
        moviesOtherSyncedDescriptor.fetchLimit = stillRemaining
        for movie in try context.fetch(moviesOtherSyncedDescriptor) {
          otherItems.append((type: "movie", simkl: movie.simkl, lastSynced: movie.last_sd_synced_at))
        }

        var showsOtherSyncedDescriptor = FetchDescriptor<V1.SDShows>(
          predicate: #Predicate { $0.status != "plantowatch" && $0.last_sd_synced_at != nil },
          sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
        )
        showsOtherSyncedDescriptor.fetchLimit = stillRemaining
        for show in try context.fetch(showsOtherSyncedDescriptor) {
          otherItems.append((type: "show", simkl: show.simkl, lastSynced: show.last_sd_synced_at))
        }

        var animesOtherSyncedDescriptor = FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate { $0.status != "plantowatch" && $0.last_sd_synced_at != nil },
          sortBy: [SortDescriptor(\.last_sd_synced_at, order: .forward)]
        )
        animesOtherSyncedDescriptor.fetchLimit = stillRemaining
        for anime in try context.fetch(animesOtherSyncedDescriptor) {
          otherItems.append((type: "anime", simkl: anime.simkl, lastSynced: anime.last_sd_synced_at))
        }
      }

      // Sort: nil first, then oldest synced
      let neverSynced = otherItems.filter { $0.lastSynced == nil }
      let synced = otherItems.filter { $0.lastSynced != nil }
        .sorted { $0.lastSynced! < $1.lastSynced! }
      let sortedOther = neverSynced + synced

      itemsToRefresh.append(contentsOf: sortedOther.prefix(remaining))
    }

    // Track successful refreshes
    var successCount = 0

    // Refresh each item based on type
    for item in itemsToRefresh {
      var success = false
      switch item.type {
      case "movie":
        success = await refreshMovie(item.simkl, context, formatter)
      case "show":
        success = await refreshShow(item.simkl, context, formatter)
      case "anime":
        success = await refreshAnime(item.simkl, context, formatter)
      default:
        break
      }
      if success {
        successCount += 1
      }
    }

    // Only update the refresh timestamp if at least one item was successfully refreshed
    if successCount > 0 {
      syncRecord!.stale_data_refresh = formatter.string(from: now)
      try context.save()
      print("Stale data refresh completed: \(successCount) items refreshed")
    } else if itemsToRefresh.isEmpty {
      // No items to refresh (empty library) - update timestamp to avoid repeated empty runs
      syncRecord!.stale_data_refresh = formatter.string(from: now)
      try context.save()
      print("Stale data refresh completed: no items to refresh")
    } else {
      print("Stale data refresh failed: all API calls failed, will retry next sync")
    }
  } catch {
    SentrySDK.capture(error: error)
  }
}

private func refreshMovie(_ simkl: Int, _ context: ModelContext, _ formatter: ISO8601DateFormatter) async -> Bool {
  do {
    guard let details = await MovieDetailView.getMovieDetails(simkl) else {
      return false
    }

    let fetchDescriptor = FetchDescriptor<V1.SDMovies>(
      predicate: #Predicate<V1.SDMovies> { $0.simkl == simkl }
    )

    if let movie = try context.fetch(fetchDescriptor).first {
      movie.title = details.title
      movie.poster = details.poster
      movie.year = details.year
      movie.last_sd_synced_at = formatter.string(from: Date())

      print("Refreshed movie: \(details.title)")
      return true
    }
    return false
  } catch {
    SentrySDK.capture(error: error)
    return false
  }
}

private func refreshShow(_ simkl: Int, _ context: ModelContext, _ formatter: ISO8601DateFormatter) async -> Bool {
  do {
    guard let details = await ShowDetailView.getShowDetails(simkl) else {
      return false
    }

    let fetchDescriptor = FetchDescriptor<V1.SDShows>(
      predicate: #Predicate<V1.SDShows> { $0.simkl == simkl }
    )

    if let show = try context.fetch(fetchDescriptor).first {
      show.title = details.title
      show.poster = details.poster
      show.year = details.year
      show.total_episodes_count = details.total_episodes
      show.last_sd_synced_at = formatter.string(from: Date())

      print("Refreshed show: \(details.title)")
      return true
    }
    return false
  } catch {
    SentrySDK.capture(error: error)
    return false
  }
}

private func refreshAnime(_ simkl: Int, _ context: ModelContext, _ formatter: ISO8601DateFormatter) async -> Bool {
  do {
    guard let details = await AnimeDetailView.getAnimeDetails(simkl) else {
      return false
    }

    let fetchDescriptor = FetchDescriptor<V1.SDAnimes>(
      predicate: #Predicate<V1.SDAnimes> { $0.simkl == simkl }
    )

    if let anime = try context.fetch(fetchDescriptor).first {
      anime.title = details.title
      anime.poster = details.poster
      anime.year = details.year
      anime.total_episodes_count = details.total_episodes
      anime.anime_type = details.anime_type
      anime.last_sd_synced_at = formatter.string(from: Date())

      print("Refreshed anime: \(details.title)")
      return true
    }
    return false
  } catch {
    SentrySDK.capture(error: error)
    return false
  }
}

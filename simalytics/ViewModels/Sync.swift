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
    await fetchAndStoreMoviesDropped(accessToken, result.movies?.dropped, context)
    await fetchAndStoreMoviesCompleted(accessToken, result.movies?.completed, context)
    await fetchAndStoreMoviesRemovedFromList(accessToken, result.movies?.removed_from_list, context)
    await fetchAndStoreMoviesRatedAt(accessToken, result.movies?.rated_at, context)
    await fetchAndStoreTVPlanToWatch(accessToken, result.tv_shows?.plantowatch, context)
    await fetchAndStoreTVCompleted(accessToken, result.tv_shows?.completed, context)
    await fetchAndStoreTVHold(accessToken, result.tv_shows?.hold, context)
    await fetchAndStoreTVDropped(accessToken, result.tv_shows?.dropped, context)
    await fetchAndStoreTVWatching(accessToken, result.tv_shows?.watching, context)
    await fetchAndStoreTVRemovedFromList(accessToken, result.tv_shows?.removed_from_list, context)
    await fetchAndStoreTVRatedAt(accessToken, result.tv_shows?.rated_at, context)
    await fetchAndStoreAnimePlanToWatch(accessToken, result.anime?.plantowatch, context)
    await fetchAndStoreAnimeDropped(accessToken, result.anime?.dropped, context)
    await fetchAndStoreAnimeCompleted(accessToken, result.anime?.completed, context)
    await fetchAndStoreAnimeHold(accessToken, result.anime?.hold, context)
    await fetchAndStoreAnimeRatedAt(accessToken, result.anime?.rated_at, context)
    await fetchAndStoreAnimeRemovedFromList(accessToken, result.anime?.removed_from_list, context)
    await fetchAndStoreAnimeWatching(accessToken, result.anime?.watching, context)
    await syncLatestTrending(accessToken, context)
    await processUpNextEpisodes(accessToken, context)
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_plantowatch = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids?.simkl)!,
          title: movieItem.movie?.title,
          added_to_watchlist_at: movieItem.added_to_watchlist_at,
          last_watched_at: movieItem.last_watched_at,
          user_rated_at: movieItem.user_rated_at,
          status: movieItem.status,
          user_rating: movieItem.user_rating,
          poster: movieItem.movie?.poster,
          year: movieItem.movie?.year,
          id_slug: movieItem.movie?.ids?.slug,
          id_tvdbmslug: movieItem.movie?.ids?.tvdbmslug,
          id_imdb: movieItem.movie?.ids?.imdb,
          id_offen: movieItem.movie?.ids?.offen,
          id_traktslug: movieItem.movie?.ids?.traktslug,
          id_letterslug: movieItem.movie?.ids?.letterslug,
          id_jwslug: movieItem.movie?.ids?.jwslug,
          id_tmdb: movieItem.movie?.ids?.tmdb,
          memo_text: movieItem.memo?.text,
          memo_is_private: movieItem.memo?.is_private
        )
      )
    }

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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_dropped = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids?.simkl)!,
          title: movieItem.movie?.title,
          added_to_watchlist_at: movieItem.added_to_watchlist_at,
          last_watched_at: movieItem.last_watched_at,
          user_rated_at: movieItem.user_rated_at,
          status: movieItem.status,
          user_rating: movieItem.user_rating,
          poster: movieItem.movie?.poster,
          year: movieItem.movie?.year,
          id_slug: movieItem.movie?.ids?.slug,
          id_tvdbmslug: movieItem.movie?.ids?.tvdbmslug,
          id_imdb: movieItem.movie?.ids?.imdb,
          id_offen: movieItem.movie?.ids?.offen,
          id_traktslug: movieItem.movie?.ids?.traktslug,
          id_letterslug: movieItem.movie?.ids?.letterslug,
          id_jwslug: movieItem.movie?.ids?.jwslug,
          id_tmdb: movieItem.movie?.ids?.tmdb,
          memo_text: movieItem.memo?.text,
          memo_is_private: movieItem.memo?.is_private
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_completed = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids?.simkl)!,
          title: movieItem.movie?.title,
          added_to_watchlist_at: movieItem.added_to_watchlist_at,
          last_watched_at: movieItem.last_watched_at,
          user_rated_at: movieItem.user_rated_at,
          status: movieItem.status,
          user_rating: movieItem.user_rating,
          poster: movieItem.movie?.poster,
          year: movieItem.movie?.year,
          id_slug: movieItem.movie?.ids?.slug,
          id_tvdbmslug: movieItem.movie?.ids?.tvdbmslug,
          id_imdb: movieItem.movie?.ids?.imdb,
          id_offen: movieItem.movie?.ids?.offen,
          id_traktslug: movieItem.movie?.ids?.traktslug,
          id_letterslug: movieItem.movie?.ids?.letterslug,
          id_jwslug: movieItem.movie?.ids?.jwslug,
          id_tmdb: movieItem.movie?.ids?.tmdb,
          memo_text: movieItem.memo?.text,
          memo_is_private: movieItem.memo?.is_private
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      syncRecord!.movies_rated_at = lastActivity
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids?.simkl)!,
          title: movieItem.movie?.title,
          added_to_watchlist_at: movieItem.added_to_watchlist_at,
          last_watched_at: movieItem.last_watched_at,
          user_rated_at: movieItem.user_rated_at,
          status: movieItem.status,
          user_rating: movieItem.user_rating,
          poster: movieItem.movie?.poster,
          year: movieItem.movie?.year,
          id_slug: movieItem.movie?.ids?.slug,
          id_tvdbmslug: movieItem.movie?.ids?.tvdbmslug,
          id_imdb: movieItem.movie?.ids?.imdb,
          id_offen: movieItem.movie?.ids?.offen,
          id_traktslug: movieItem.movie?.ids?.traktslug,
          id_letterslug: movieItem.movie?.ids?.letterslug,
          id_jwslug: movieItem.movie?.ids?.jwslug,
          id_tmdb: movieItem.movie?.ids?.tmdb,
          memo_text: movieItem.memo?.text,
          memo_is_private: movieItem.memo?.is_private
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_plantowatch = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(
        V1.SDShows(
          simkl: (showItem.show?.ids?.simkl)!,
          added_to_watchlist_at: showItem.added_to_watchlist_at,
          last_watched_at: showItem.last_watched_at,
          user_rated_at: showItem.user_rated_at,
          user_rating: showItem.user_rating,
          status: showItem.status,
          last_watched: showItem.last_watched,
          next_to_watch: showItem.next_to_watch,
          watched_episodes_count: showItem.watched_episodes_count,
          total_episodes_count: showItem.total_episodes_count,
          not_aired_episodes_count: showItem.not_aired_episodes_count,
          title: showItem.show?.title,
          poster: showItem.show?.poster,
          year: showItem.show?.year,
          memo_text: showItem.memo?.text,
          memo_is_private: showItem.memo?.is_private,
          id_slug: showItem.show?.ids?.slug,
          id_offen: showItem.show?.ids?.offen,
          id_tvdbslug: showItem.show?.ids?.tvdbslug,
          id_instagram: showItem.show?.ids?.instagram,
          id_tw: showItem.show?.ids?.tw,
          id_imdb: showItem.show?.ids?.imdb,
          id_tmdb: showItem.show?.ids?.tmdb,
          id_traktslug: showItem.show?.ids?.traktslug,
          id_jwslug: showItem.show?.ids?.jwslug,
          id_tvdb: showItem.show?.ids?.tvdb
        )
      )
    }

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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_completed = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(
        V1.SDShows(
          simkl: (showItem.show?.ids?.simkl)!,
          added_to_watchlist_at: showItem.added_to_watchlist_at,
          last_watched_at: showItem.last_watched_at,
          user_rated_at: showItem.user_rated_at,
          user_rating: showItem.user_rating,
          status: showItem.status,
          last_watched: showItem.last_watched,
          next_to_watch: showItem.next_to_watch,
          watched_episodes_count: showItem.watched_episodes_count,
          total_episodes_count: showItem.total_episodes_count,
          not_aired_episodes_count: showItem.not_aired_episodes_count,
          title: showItem.show?.title,
          poster: showItem.show?.poster,
          year: showItem.show?.year,
          memo_text: showItem.memo?.text,
          memo_is_private: showItem.memo?.is_private,
          id_slug: showItem.show?.ids?.slug,
          id_offen: showItem.show?.ids?.offen,
          id_tvdbslug: showItem.show?.ids?.tvdbslug,
          id_instagram: showItem.show?.ids?.instagram,
          id_tw: showItem.show?.ids?.tw,
          id_imdb: showItem.show?.ids?.imdb,
          id_tmdb: showItem.show?.ids?.tmdb,
          id_traktslug: showItem.show?.ids?.traktslug,
          id_jwslug: showItem.show?.ids?.jwslug,
          id_tvdb: showItem.show?.ids?.tvdb
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_hold = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(
        V1.SDShows(
          simkl: (showItem.show?.ids?.simkl)!,
          added_to_watchlist_at: showItem.added_to_watchlist_at,
          last_watched_at: showItem.last_watched_at,
          user_rated_at: showItem.user_rated_at,
          user_rating: showItem.user_rating,
          status: showItem.status,
          last_watched: showItem.last_watched,
          next_to_watch: showItem.next_to_watch,
          watched_episodes_count: showItem.watched_episodes_count,
          total_episodes_count: showItem.total_episodes_count,
          not_aired_episodes_count: showItem.not_aired_episodes_count,
          title: showItem.show?.title,
          poster: showItem.show?.poster,
          year: showItem.show?.year,
          memo_text: showItem.memo?.text,
          memo_is_private: showItem.memo?.is_private,
          id_slug: showItem.show?.ids?.slug,
          id_offen: showItem.show?.ids?.offen,
          id_tvdbslug: showItem.show?.ids?.tvdbslug,
          id_instagram: showItem.show?.ids?.instagram,
          id_tw: showItem.show?.ids?.tw,
          id_imdb: showItem.show?.ids?.imdb,
          id_tmdb: showItem.show?.ids?.tmdb,
          id_traktslug: showItem.show?.ids?.traktslug,
          id_jwslug: showItem.show?.ids?.jwslug,
          id_tvdb: showItem.show?.ids?.tvdb
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_dropped = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(
        V1.SDShows(
          simkl: (showItem.show?.ids?.simkl)!,
          added_to_watchlist_at: showItem.added_to_watchlist_at,
          last_watched_at: showItem.last_watched_at,
          user_rated_at: showItem.user_rated_at,
          user_rating: showItem.user_rating,
          status: showItem.status,
          last_watched: showItem.last_watched,
          next_to_watch: showItem.next_to_watch,
          watched_episodes_count: showItem.watched_episodes_count,
          total_episodes_count: showItem.total_episodes_count,
          not_aired_episodes_count: showItem.not_aired_episodes_count,
          title: showItem.show?.title,
          poster: showItem.show?.poster,
          year: showItem.show?.year,
          memo_text: showItem.memo?.text,
          memo_is_private: showItem.memo?.is_private,
          id_slug: showItem.show?.ids?.slug,
          id_offen: showItem.show?.ids?.offen,
          id_tvdbslug: showItem.show?.ids?.tvdbslug,
          id_instagram: showItem.show?.ids?.instagram,
          id_tw: showItem.show?.ids?.tw,
          id_imdb: showItem.show?.ids?.imdb,
          id_tmdb: showItem.show?.ids?.tmdb,
          id_traktslug: showItem.show?.ids?.traktslug,
          id_jwslug: showItem.show?.ids?.jwslug,
          id_tvdb: showItem.show?.ids?.tvdb
        )
      )
    }

    syncRecord!.tv_dropped = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreTVWatching(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.tv_watching { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/shows/watching?memos=yes&next_watch_info=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.tv_watching.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_watching = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(
        V1.SDShows(
          simkl: (showItem.show?.ids?.simkl)!,
          added_to_watchlist_at: showItem.added_to_watchlist_at,
          last_watched_at: showItem.last_watched_at,
          user_rated_at: showItem.user_rated_at,
          user_rating: showItem.user_rating,
          status: showItem.status,
          last_watched: showItem.last_watched,
          next_to_watch: showItem.next_to_watch,
          watched_episodes_count: showItem.watched_episodes_count,
          total_episodes_count: showItem.total_episodes_count,
          not_aired_episodes_count: showItem.not_aired_episodes_count,
          title: showItem.show?.title,
          poster: showItem.show?.poster,
          year: showItem.show?.year,
          memo_text: showItem.memo?.text,
          memo_is_private: showItem.memo?.is_private,
          id_slug: showItem.show?.ids?.slug,
          id_offen: showItem.show?.ids?.offen,
          id_tvdbslug: showItem.show?.ids?.tvdbslug,
          id_instagram: showItem.show?.ids?.instagram,
          id_tw: showItem.show?.ids?.tw,
          id_imdb: showItem.show?.ids?.imdb,
          id_tmdb: showItem.show?.ids?.tmdb,
          id_traktslug: showItem.show?.ids?.traktslug,
          id_jwslug: showItem.show?.ids?.jwslug,
          id_tvdb: showItem.show?.ids?.tvdb,
          next_to_watch_info_title: showItem.next_to_watch_info?.title,
          next_to_watch_info_season: showItem.next_to_watch_info?.season,
          next_to_watch_info_episode: showItem.next_to_watch_info?.episode,
          next_to_watch_info_date: showItem.next_to_watch_info?.date,
          last_sd_synced_at: formatter.string(from: Date())
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(TVModel.self, from: data) else {
      syncRecord!.tv_rated_at = lastActivity
      try context.save()
      return
    }

    let shows = result.shows ?? []
    for showItem in shows {
      context.insert(
        V1.SDShows(
          simkl: (showItem.show?.ids?.simkl)!,
          added_to_watchlist_at: showItem.added_to_watchlist_at,
          last_watched_at: showItem.last_watched_at,
          user_rated_at: showItem.user_rated_at,
          user_rating: showItem.user_rating,
          status: showItem.status,
          last_watched: showItem.last_watched,
          next_to_watch: showItem.next_to_watch,
          watched_episodes_count: showItem.watched_episodes_count,
          total_episodes_count: showItem.total_episodes_count,
          not_aired_episodes_count: showItem.not_aired_episodes_count,
          title: showItem.show?.title,
          poster: showItem.show?.poster,
          year: showItem.show?.year,
          memo_text: showItem.memo?.text,
          memo_is_private: showItem.memo?.is_private,
          id_slug: showItem.show?.ids?.slug,
          id_offen: showItem.show?.ids?.offen,
          id_tvdbslug: showItem.show?.ids?.tvdbslug,
          id_instagram: showItem.show?.ids?.instagram,
          id_tw: showItem.show?.ids?.tw,
          id_imdb: showItem.show?.ids?.imdb,
          id_tmdb: showItem.show?.ids?.tmdb,
          id_traktslug: showItem.show?.ids?.traktslug,
          id_jwslug: showItem.show?.ids?.jwslug,
          id_tvdb: showItem.show?.ids?.tvdb
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_plantowatch = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(
        V1.SDAnimes(
          simkl: (animeItem.show?.ids.simkl)!,
          added_to_watchlist_at: animeItem.added_to_watchlist_at,
          last_watched_at: animeItem.last_watched_at,
          user_rated_at: animeItem.user_rated_at,
          user_rating: animeItem.user_rating,
          status: animeItem.status,
          last_watched: animeItem.last_watched,
          next_to_watch: animeItem.next_to_watch,
          watched_episodes_count: animeItem.watched_episodes_count,
          total_episodes_count: animeItem.total_episodes_count,
          not_aired_episodes_count: animeItem.not_aired_episodes_count,
          anime_type: animeItem.anime_type,
          poster: animeItem.show?.poster,
          year: animeItem.show?.year,
          title: animeItem.show?.title,
          memo_text: animeItem.memo?.text,
          memo_is_private: animeItem.memo?.is_private,
          id_slug: animeItem.show?.ids.slug,
          id_offjp: animeItem.show?.ids.offjp,
          id_ann: animeItem.show?.ids.ann,
          id_mal: animeItem.show?.ids.mal,
          id_anfo: animeItem.show?.ids.anfo,
          id_offen: animeItem.show?.ids.offen,
          id_wikien: animeItem.show?.ids.wikien,
          id_wikijp: animeItem.show?.ids.wikijp,
          id_allcin: animeItem.show?.ids.allcin,
          id_imdb: animeItem.show?.ids.imdb,
          id_tmdb: animeItem.show?.ids.tmdb,
          id_animeplanet: animeItem.show?.ids.animeplanet,
          id_anisearch: animeItem.show?.ids.anisearch,
          id_kitsu: animeItem.show?.ids.kitsu,
          id_livechart: animeItem.show?.ids.livechart,
          id_traktslug: animeItem.show?.ids.traktslug,
          id_letterslug: animeItem.show?.ids.letterslug,
          id_jwslug: animeItem.show?.ids.jwslug,
          id_anidb: animeItem.show?.ids.anidb
        )
      )
    }

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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_dropped = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(
        V1.SDAnimes(
          simkl: (animeItem.show?.ids.simkl)!,
          added_to_watchlist_at: animeItem.added_to_watchlist_at,
          last_watched_at: animeItem.last_watched_at,
          user_rated_at: animeItem.user_rated_at,
          user_rating: animeItem.user_rating,
          status: animeItem.status,
          last_watched: animeItem.last_watched,
          next_to_watch: animeItem.next_to_watch,
          watched_episodes_count: animeItem.watched_episodes_count,
          total_episodes_count: animeItem.total_episodes_count,
          not_aired_episodes_count: animeItem.not_aired_episodes_count,
          anime_type: animeItem.anime_type,
          poster: animeItem.show?.poster,
          year: animeItem.show?.year,
          title: animeItem.show?.title,
          memo_text: animeItem.memo?.text,
          memo_is_private: animeItem.memo?.is_private,
          id_slug: animeItem.show?.ids.slug,
          id_offjp: animeItem.show?.ids.offjp,
          id_ann: animeItem.show?.ids.ann,
          id_mal: animeItem.show?.ids.mal,
          id_anfo: animeItem.show?.ids.anfo,
          id_offen: animeItem.show?.ids.offen,
          id_wikien: animeItem.show?.ids.wikien,
          id_wikijp: animeItem.show?.ids.wikijp,
          id_allcin: animeItem.show?.ids.allcin,
          id_imdb: animeItem.show?.ids.imdb,
          id_tmdb: animeItem.show?.ids.tmdb,
          id_animeplanet: animeItem.show?.ids.animeplanet,
          id_anisearch: animeItem.show?.ids.anisearch,
          id_kitsu: animeItem.show?.ids.kitsu,
          id_livechart: animeItem.show?.ids.livechart,
          id_traktslug: animeItem.show?.ids.traktslug,
          id_letterslug: animeItem.show?.ids.letterslug,
          id_jwslug: animeItem.show?.ids.jwslug,
          id_anidb: animeItem.show?.ids.anidb
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_completed = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(
        V1.SDAnimes(
          simkl: (animeItem.show?.ids.simkl)!,
          added_to_watchlist_at: animeItem.added_to_watchlist_at,
          last_watched_at: animeItem.last_watched_at,
          user_rated_at: animeItem.user_rated_at,
          user_rating: animeItem.user_rating,
          status: animeItem.status,
          last_watched: animeItem.last_watched,
          next_to_watch: animeItem.next_to_watch,
          watched_episodes_count: animeItem.watched_episodes_count,
          total_episodes_count: animeItem.total_episodes_count,
          not_aired_episodes_count: animeItem.not_aired_episodes_count,
          anime_type: animeItem.anime_type,
          poster: animeItem.show?.poster,
          year: animeItem.show?.year,
          title: animeItem.show?.title,
          memo_text: animeItem.memo?.text,
          memo_is_private: animeItem.memo?.is_private,
          id_slug: animeItem.show?.ids.slug,
          id_offjp: animeItem.show?.ids.offjp,
          id_ann: animeItem.show?.ids.ann,
          id_mal: animeItem.show?.ids.mal,
          id_anfo: animeItem.show?.ids.anfo,
          id_offen: animeItem.show?.ids.offen,
          id_wikien: animeItem.show?.ids.wikien,
          id_wikijp: animeItem.show?.ids.wikijp,
          id_allcin: animeItem.show?.ids.allcin,
          id_imdb: animeItem.show?.ids.imdb,
          id_tmdb: animeItem.show?.ids.tmdb,
          id_animeplanet: animeItem.show?.ids.animeplanet,
          id_anisearch: animeItem.show?.ids.anisearch,
          id_kitsu: animeItem.show?.ids.kitsu,
          id_livechart: animeItem.show?.ids.livechart,
          id_traktslug: animeItem.show?.ids.traktslug,
          id_letterslug: animeItem.show?.ids.letterslug,
          id_jwslug: animeItem.show?.ids.jwslug,
          id_anidb: animeItem.show?.ids.anidb
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_hold = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(
        V1.SDAnimes(
          simkl: (animeItem.show?.ids.simkl)!,
          added_to_watchlist_at: animeItem.added_to_watchlist_at,
          last_watched_at: animeItem.last_watched_at,
          user_rated_at: animeItem.user_rated_at,
          user_rating: animeItem.user_rating,
          status: animeItem.status,
          last_watched: animeItem.last_watched,
          next_to_watch: animeItem.next_to_watch,
          watched_episodes_count: animeItem.watched_episodes_count,
          total_episodes_count: animeItem.total_episodes_count,
          not_aired_episodes_count: animeItem.not_aired_episodes_count,
          anime_type: animeItem.anime_type,
          poster: animeItem.show?.poster,
          year: animeItem.show?.year,
          title: animeItem.show?.title,
          memo_text: animeItem.memo?.text,
          memo_is_private: animeItem.memo?.is_private,
          id_slug: animeItem.show?.ids.slug,
          id_offjp: animeItem.show?.ids.offjp,
          id_ann: animeItem.show?.ids.ann,
          id_mal: animeItem.show?.ids.mal,
          id_anfo: animeItem.show?.ids.anfo,
          id_offen: animeItem.show?.ids.offen,
          id_wikien: animeItem.show?.ids.wikien,
          id_wikijp: animeItem.show?.ids.wikijp,
          id_allcin: animeItem.show?.ids.allcin,
          id_imdb: animeItem.show?.ids.imdb,
          id_tmdb: animeItem.show?.ids.tmdb,
          id_animeplanet: animeItem.show?.ids.animeplanet,
          id_anisearch: animeItem.show?.ids.anisearch,
          id_kitsu: animeItem.show?.ids.kitsu,
          id_livechart: animeItem.show?.ids.livechart,
          id_traktslug: animeItem.show?.ids.traktslug,
          id_letterslug: animeItem.show?.ids.letterslug,
          id_jwslug: animeItem.show?.ids.jwslug,
          id_anidb: animeItem.show?.ids.anidb
        )
      )
    }

    syncRecord!.anime_hold = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreAnimeWatching(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    var syncRecord = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first
    if syncRecord == nil {
      syncRecord = V1.SDLastSync(id: 1)
      context.insert(syncRecord!)
    }

    if lastActivity == syncRecord!.anime_watching { return }

    var endpoint = URLComponents(
      string: "https://api.simkl.com/sync/all-items/anime/watching?memos=yes&next_watch_info=yes")!

    let lastActivityDate = formatter.date(from: lastActivity)!
    if let previousSyncDate = syncRecord!.anime_watching.flatMap(formatter.date(from:)) {
      if lastActivityDate > previousSyncDate {
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_watching = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(
        V1.SDAnimes(
          simkl: (animeItem.show?.ids.simkl)!,
          added_to_watchlist_at: animeItem.added_to_watchlist_at,
          last_watched_at: animeItem.last_watched_at,
          user_rated_at: animeItem.user_rated_at,
          user_rating: animeItem.user_rating,
          status: animeItem.status,
          last_watched: animeItem.last_watched,
          next_to_watch: animeItem.next_to_watch,
          watched_episodes_count: animeItem.watched_episodes_count,
          total_episodes_count: animeItem.total_episodes_count,
          not_aired_episodes_count: animeItem.not_aired_episodes_count,
          anime_type: animeItem.anime_type,
          poster: animeItem.show?.poster,
          year: animeItem.show?.year,
          title: animeItem.show?.title,
          memo_text: animeItem.memo?.text,
          memo_is_private: animeItem.memo?.is_private,
          id_slug: animeItem.show?.ids.slug,
          id_offjp: animeItem.show?.ids.offjp,
          id_ann: animeItem.show?.ids.ann,
          id_mal: animeItem.show?.ids.mal,
          id_anfo: animeItem.show?.ids.anfo,
          id_offen: animeItem.show?.ids.offen,
          id_wikien: animeItem.show?.ids.wikien,
          id_wikijp: animeItem.show?.ids.wikijp,
          id_allcin: animeItem.show?.ids.allcin,
          id_imdb: animeItem.show?.ids.imdb,
          id_tmdb: animeItem.show?.ids.tmdb,
          id_animeplanet: animeItem.show?.ids.animeplanet,
          id_anisearch: animeItem.show?.ids.anisearch,
          id_kitsu: animeItem.show?.ids.kitsu,
          id_livechart: animeItem.show?.ids.livechart,
          id_traktslug: animeItem.show?.ids.traktslug,
          id_letterslug: animeItem.show?.ids.letterslug,
          id_jwslug: animeItem.show?.ids.jwslug,
          id_anidb: animeItem.show?.ids.anidb,
          next_to_watch_info_title: animeItem.next_to_watch_info?.title,
          next_to_watch_info_episode: animeItem.next_to_watch_info?.episode,
          next_to_watch_info_date: animeItem.next_to_watch_info?.date,
          last_sd_synced_at: formatter.string(from: Date())
        )
      )
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

    let (data, _) = try await URLSession.shared.data(for: request)
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

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(AnimeModel.self, from: data) else {
      syncRecord!.anime_rated_at = lastActivity
      try context.save()
      return
    }

    let animes = result.anime ?? []
    for animeItem in animes {
      context.insert(
        V1.SDAnimes(
          simkl: (animeItem.show?.ids.simkl)!,
          added_to_watchlist_at: animeItem.added_to_watchlist_at,
          last_watched_at: animeItem.last_watched_at,
          user_rated_at: animeItem.user_rated_at,
          user_rating: animeItem.user_rating,
          status: animeItem.status,
          last_watched: animeItem.last_watched,
          next_to_watch: animeItem.next_to_watch,
          watched_episodes_count: animeItem.watched_episodes_count,
          total_episodes_count: animeItem.total_episodes_count,
          not_aired_episodes_count: animeItem.not_aired_episodes_count,
          anime_type: animeItem.anime_type,
          poster: animeItem.show?.poster,
          year: animeItem.show?.year,
          title: animeItem.show?.title,
          memo_text: animeItem.memo?.text,
          memo_is_private: animeItem.memo?.is_private,
          id_slug: animeItem.show?.ids.slug,
          id_offjp: animeItem.show?.ids.offjp,
          id_ann: animeItem.show?.ids.ann,
          id_mal: animeItem.show?.ids.mal,
          id_anfo: animeItem.show?.ids.anfo,
          id_offen: animeItem.show?.ids.offen,
          id_wikien: animeItem.show?.ids.wikien,
          id_wikijp: animeItem.show?.ids.wikijp,
          id_allcin: animeItem.show?.ids.allcin,
          id_imdb: animeItem.show?.ids.imdb,
          id_tmdb: animeItem.show?.ids.tmdb,
          id_animeplanet: animeItem.show?.ids.animeplanet,
          id_anisearch: animeItem.show?.ids.anisearch,
          id_kitsu: animeItem.show?.ids.kitsu,
          id_livechart: animeItem.show?.ids.livechart,
          id_traktslug: animeItem.show?.ids.traktslug,
          id_letterslug: animeItem.show?.ids.letterslug,
          id_jwslug: animeItem.show?.ids.jwslug,
          id_anidb: animeItem.show?.ids.anidb
        )
      )
    }

    syncRecord!.anime_rated_at = lastActivity
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
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
          order: index + 1
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
          order: index + 1
        )
      )
    }

    syncRecord!.trending_data = now.ISO8601Format()
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}

func processUpNextEpisodes(_ accessToken: String, _ context: ModelContext) async {
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
    var needsSync = false
    if let lastSyncDateStr = syncRecord!.changes_api,
      let lastSyncDate = formatter.date(from: lastSyncDateStr)
    {
      if lastSyncDate < sixHoursAgo {
        needsSync = true
      }
    } else {
      needsSync = true
    }
    if !needsSync { return }
    var sdShowsFD = FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.status == "watching" })
    sdShowsFD.propertiesToFetch = [\.simkl]
    let sdShowsIds = try context.fetch(sdShowsFD)

    var sdAnimesFD = FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.status == "watching" && $0.anime_type == "tv" })
    sdAnimesFD.propertiesToFetch = [\.simkl]
    let sdAnimesIds = try context.fetch(sdAnimesFD)

    for show in sdShowsIds {
      let watchedEpisodes = await ShowDetailView.getShowWatchlist(show.simkl, accessToken)

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

    for anime in sdAnimesIds {
      let watchedEpisodes = await AnimeDetailView.getAnimeWatchlist(anime.simkl, accessToken)

      guard
        let watched = watchedEpisodes,
        (watched.episodes_aired ?? 0) > (watched.episodes_watched ?? 0),
        let seasons = watched.seasons
      else { continue }

      let allEpisodes = await AnimeDetailView.getAnimeEpisodes(anime.simkl, countSeasons: false)

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

    syncRecord!.changes_api = now.ISO8601Format()
    try context.save()
  } catch {
    SentrySDK.capture(error: error)
  }
}
// TODO: Widgets with next episode and show progress
// TODO: Sync calendar data for "new" and notifications

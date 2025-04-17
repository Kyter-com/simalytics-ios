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
  } catch {
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesPlanToWatch(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    let lastSync = try context.fetch(FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })).first?.movies_plantowatch
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

    print(endpoint.url!)
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      let syncRecord =
        try context.fetch(
          FetchDescriptor<V1.SDLastSync>(
            predicate: #Predicate { $0.id == 1 }
          )
        ).first ?? V1.SDLastSync(id: 1)
      syncRecord.movies_plantowatch = lastActivity
      context.insert(syncRecord)
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids!.simkl)!,
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
          memo_text: movieItem.movie?.memo?.text,
          memo_is_private: movieItem.movie?.memo?.is_private
        )
      )
    }
    let syncRecord =
      try context.fetch(
        FetchDescriptor<V1.SDLastSync>(
          predicate: #Predicate { $0.id == 1 }
        )
      ).first ?? V1.SDLastSync(id: 1)
    syncRecord.movies_plantowatch = lastActivity
    context.insert(syncRecord)
    try context.save()
  } catch {
    print(error)
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesDropped(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    let lastSync = try context.fetch(FetchDescriptor<V1.SDLastSync>()).first?.movies_dropped
    if lastActivity == lastSync { return }

    var endpoint = URLComponents(string: "https://api.simkl.com/sync/all-items/movies/dropped?memos=yes")!
    let lastActivityDate = formatter.date(from: lastActivity)!

    if let lastSync = lastSync {
      let lastSyncDate = formatter.date(from: lastSync) ?? Date(timeIntervalSince1970: 0)
      if lastActivityDate > lastSyncDate {
        let dateFrom = formatter.string(from: Calendar.current.date(byAdding: .minute, value: -5, to: lastActivityDate)!)
        endpoint = URLComponents(string: "https://api.simkl.com/sync/all-items/movies/dropped?memos=yes&date_from=\(dateFrom)")!
      }
    }

    print(endpoint.url!)
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      context.insert(V1.SDLastSync(id: 1, movies_dropped: lastActivity))
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids!.simkl)!,
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
          memo_text: movieItem.movie?.memo?.text,
          memo_is_private: movieItem.movie?.memo?.is_private
        )
      )
    }
    context.insert(V1.SDLastSync(id: 1, movies_dropped: lastActivity))
    try context.save()
  } catch {
    print(error)
    SentrySDK.capture(error: error)
  }
}

func fetchAndStoreMoviesCompleted(_ accessToken: String, _ lastActivity: String?, _ context: ModelContext) async {
  guard let lastActivity = lastActivity else { return }
  let formatter = ISO8601DateFormatter()

  do {
    let lastSync = try context.fetch(FetchDescriptor<V1.SDLastSync>()).first?.movies_completed
    print(lastSync, lastActivity)
    if lastActivity == lastSync { return }

    var endpoint = URLComponents(string: "https://api.simkl.com/sync/all-items/movies/completed?memos=yes")!
    let lastActivityDate = formatter.date(from: lastActivity)!

    if let lastSync = lastSync {
      let lastSyncDate = formatter.date(from: lastSync) ?? Date(timeIntervalSince1970: 0)
      if lastActivityDate > lastSyncDate {
        let dateFrom = formatter.string(from: Calendar.current.date(byAdding: .minute, value: -5, to: lastActivityDate)!)
        endpoint = URLComponents(string: "https://api.simkl.com/sync/all-items/movies/completed?memos=yes&date_from=\(dateFrom)")!
      }
    }

    print(endpoint.url!)
    var request = URLRequest(url: endpoint.url!)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let result = try? JSONDecoder().decode(MoviesModel.self, from: data) else {
      context.insert(V1.SDLastSync(id: 1, movies_completed: lastActivity))
      try context.save()
      return
    }

    let movies = result.movies ?? []
    for movieItem in movies {
      context.insert(
        V1.SDMovies(
          simkl: (movieItem.movie?.ids!.simkl)!,
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
          memo_text: movieItem.movie?.memo?.text,
          memo_is_private: movieItem.movie?.memo?.is_private
        )
      )
    }
    context.insert(V1.SDLastSync(id: 1, movies_completed: lastActivity))
    try context.save()
  } catch {
    print(error)
    SentrySDK.capture(error: error)
  }
}

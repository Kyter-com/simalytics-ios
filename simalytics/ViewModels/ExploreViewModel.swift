//
//  ExploreViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/13/25.
//

import Foundation
import Sentry

// Trending data is served from the CDN host data.simkl.in per the current
// Simkl docs. Each file ships title/poster/ids and is cached for ~1h.
private let SIMKL_TRENDING_BASE = "https://data.simkl.in/discover/trending"

private func fetchTrendingArray<T: Decodable>(_ type: String) async -> [T] {
  guard let url = URL(string: "\(SIMKL_TRENDING_BASE)/\(type)/today_100.json") else { return [] }
  do {
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }

    return try JSONDecoder().decode([T].self, from: data)
  } catch {
    SentrySDK.capture(error: error)
    return []
  }
}

func getTrendingMovies() async -> [TrendingMovieModel] {
  await fetchTrendingArray("movies")
}

func getTrendingAnimes() async -> [TrendingAnimeModel] {
  await fetchTrendingArray("anime")
}

func getTrendingShows() async -> [TrendingShowModel] {
  await fetchTrendingArray("tv")
}

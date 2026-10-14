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

private func fetchTrendingArray<T: Decodable>(_ type: String) async throws -> [T] {
  let url = URL(string: "\(SIMKL_TRENDING_BASE)/\(type)/today_100.json")!
  var request = URLRequest(url: url)
  request.setValue("application/json", forHTTPHeaderField: "Accept")
  let (data, _) = try await performSimklRequest(request)
  return try JSONDecoder().decode([T].self, from: data)
}

func getTrendingMovies() async throws -> [TrendingMovieModel] {
  try await fetchTrendingArray("movies")
}

func getTrendingAnimes() async throws -> [TrendingAnimeModel] {
  try await fetchTrendingArray("anime")
}

func getTrendingShows() async throws -> [TrendingShowModel] {
  try await fetchTrendingArray("tv")
}

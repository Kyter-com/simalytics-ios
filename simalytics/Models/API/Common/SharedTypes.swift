//
//  SharedTypes.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/8/26.
//

import Foundation

// MARK: - Ratings

struct Rating: Codable {
  let rating: Double?
  let votes: Int?
}

struct Ratings: Codable {
  let simkl: Rating?
  let imdb: Rating?
}

// MARK: - Watchlist Structures

struct WatchlistSeason: Codable, Sendable {
  let number: Int?
  let episodes_total: Int?
  let episodes_aired: Int?
  let episodes_to_be_aired: Int?
  let episodes_watched: Int?
  var episodes: [WatchlistEpisode]?
}

struct WatchlistEpisode: Codable, Sendable {
  let number: Int?
  var watched: Bool?
  let aired: Bool?
  let last_watched_at: String?
}

/// The whole-number share of a title's regular episodes that were watched.
/// SIMKL's `episodes_watched` also counts specials (season 0), which a title's
/// `total_episodes` leaves out, so a show with watched specials could read
/// past 100%. Without per-season counts, the overall count is used.
func watchedPercentage(seasons: [WatchlistSeason]?, episodesWatched: Int?, total: Int?) -> Int {
  guard let total, total > 0 else { return 0 }
  let watched =
    seasons.map { seasons in
      seasons.filter { ($0.number ?? 0) > 0 }.reduce(0) { $0 + max($1.episodes_watched ?? 0, 0) }
    } ?? episodesWatched ?? 0
  return min(100, max(0, Int(Double(watched) / Double(total) * 100)))
}

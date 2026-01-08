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

struct WatchlistSeason: Codable {
  let number: Int?
  let episodes_total: Int?
  let episodes_aired: Int?
  let episodes_to_be_aired: Int?
  let episodes_watched: Int?
  var episodes: [WatchlistEpisode]?
}

struct WatchlistEpisode: Codable {
  let number: Int?
  var watched: Bool?
  let aired: Bool?
  let last_watched_at: String?
}

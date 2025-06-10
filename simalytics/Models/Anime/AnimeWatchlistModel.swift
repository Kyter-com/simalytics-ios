//
//  AnimeWatchlistModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Foundation

struct AnimeWatchlistModel: Codable {
  let list: String?
  let last_watched_at: String?
  let simkl: Int
  let episodes_watched: Int?
  let episodes_aired: Int?
  var seasons: [AnimeWatchlistModel_seasons]?
}

struct AnimeWatchlistModel_seasons: Codable {
  let number: Int?
  let episodes_total: Int?
  let episodes_aired: Int?
  let episodes_to_be_aired: Int?
  let episodes_watched: Int?
  var episodes: [AnimeWatchlistModel_episodes]?
}

struct AnimeWatchlistModel_episodes: Codable {
  let number: Int?
  var watched: Bool?
  let aired: Bool?
  let last_watched_at: String?
}

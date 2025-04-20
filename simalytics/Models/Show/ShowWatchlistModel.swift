//
//  ShowWatchlistModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/21/25.
//

import Foundation

struct ShowWatchlistModel: Codable {
  let list: String?
  let last_watched_at: String?
  let simkl: Int
  let episodes_watched: Int?
  let seasons: [ShowWatchlistModel_seasons]?
}

struct ShowWatchlistModel_seasons: Codable {
  let number: Int?
  let episodes_total: Int?
  let episodes_aired: Int?
  let episodes_to_be_aired: Int?
  let episodes_watched: Int?
  let episodes: [ShowWatchlistModel_episodes]?
}

struct ShowWatchlistModel_episodes: Codable {
  let number: Int?
  let watched: Bool?
  let aired: Bool?
  let last_watched_at: String?
}

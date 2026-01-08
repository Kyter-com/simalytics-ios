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
  let episodes_aired: Int?
  var seasons: [WatchlistSeason]?
}

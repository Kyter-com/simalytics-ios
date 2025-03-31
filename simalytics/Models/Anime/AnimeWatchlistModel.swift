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
}

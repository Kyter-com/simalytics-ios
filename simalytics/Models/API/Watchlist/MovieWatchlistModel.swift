//
//  MovieWatchlistModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/16/25.
//

import Foundation

struct MovieWatchlistModel: Codable {
  let list: String?
  let last_watched_at: String?
  let simkl: Int
}

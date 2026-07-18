//
//  AnimeWatchlistModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Foundation

struct AnimeWatchlistModel: Sendable {
  let list: String?
  let last_watched_at: String?
  let simkl: Int
  let episodes_watched: Int?
  let episodes_aired: Int?
  var seasons: [WatchlistSeason]?
}

extension AnimeWatchlistModel: Decodable {
  private enum CodingKeys: String, CodingKey {
    case list, last_watched_at, simkl, ids, episodes_watched, episodes_aired, seasons
  }

  private struct IDs: Decodable {
    let simkl: Int
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    list = try container.decodeIfPresent(String.self, forKey: .list)
    last_watched_at = try container.decodeIfPresent(String.self, forKey: .last_watched_at)
    simkl =
      try container.decodeIfPresent(Int.self, forKey: .simkl)
      ?? container.decode(IDs.self, forKey: .ids).simkl
    episodes_watched = try container.decodeIfPresent(Int.self, forKey: .episodes_watched)
    episodes_aired = try container.decodeIfPresent(Int.self, forKey: .episodes_aired)
    seasons = try container.decodeIfPresent([WatchlistSeason].self, forKey: .seasons)
  }
}

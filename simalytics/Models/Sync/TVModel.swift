//
//  TVModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/17/25.
//

import Foundation

struct TVModel: Codable {
  let shows: [TVModel_show]?
}

struct TVModel_show: Codable {
  let added_to_watchlist_at: String?
  let last_watched_at: String?
  let user_rated_at: String?
  let user_rating: Int?
  let status: String?
  let last_watched: String?
  let next_to_watch: String?
  let watched_episodes_count: Int?
  let total_episodes_count: Int?
  let not_aired_episodes_count: Int?
  let show: TVModel_show_item?
  let memo: TVModel_show_item_memo?
}

struct TVModel_show_item: Codable {
  let title: String?
  let poster: String?
  let year: Int?
  let ids: TVModel_show_item_ids?
}

struct TVModel_show_item_ids: Codable {
  let simkl: Int
  let slug: String?
  let offen: String?
  let tvdbslug: String?
  let instagram: String?
  let tw: String?
  let imdb: String?
  let tmdb: String?
  let traktslug: String?
  let jwslug: String?
  let tvdb: String?
}

struct TVModel_show_item_memo: Codable {
  let text: String?
  let is_private: Bool?
}

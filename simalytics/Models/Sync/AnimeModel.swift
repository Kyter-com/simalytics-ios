//
//  AnimeModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/22/25.
//

import Foundation

struct AnimeModel: Codable {
  let anime: [AnimeModel_record]?
}

struct AnimeModel_record: Codable {
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
  let anime_type: String?
  let show: AnimeModel_record_item?
  let memo: AnimeModel_record_item_memo?
}

struct AnimeModel_record_item: Codable {
  let title: String?
  let poster: String?
  let year: Int?
  let ids: AnimeModel_record_item_ids
}

struct AnimeModel_record_item_ids: Codable {
  let simkl: Int
  let slug: String?
  let offjp: String?
}

struct AnimeModel_record_item_memo: Codable {
  let text: String?
  let is_private: Bool?
}

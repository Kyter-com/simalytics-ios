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
  let next_to_watch_info: TVModel_show_item_next_to_watch_info?
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

struct TVModel_show_item_next_to_watch_info: Codable {
  let title: String?
  let season: Int?
  let episode: Int?
  let date: String?
}

// MARK: - SwiftData Conversion

extension TVModel_show {
  func toSwiftData(syncedAt: String? = nil) -> V1.SDShows {
    V1.SDShows(
      simkl: (show?.ids?.simkl)!,
      added_to_watchlist_at: added_to_watchlist_at,
      last_watched_at: last_watched_at,
      user_rated_at: user_rated_at,
      user_rating: user_rating,
      status: status,
      last_watched: last_watched,
      next_to_watch: next_to_watch,
      watched_episodes_count: watched_episodes_count,
      total_episodes_count: total_episodes_count,
      not_aired_episodes_count: not_aired_episodes_count,
      title: show?.title,
      poster: show?.poster,
      year: show?.year,
      memo_text: memo?.text,
      memo_is_private: memo?.is_private,
      id_slug: show?.ids?.slug,
      id_offen: show?.ids?.offen,
      id_tvdbslug: show?.ids?.tvdbslug,
      id_instagram: show?.ids?.instagram,
      id_tw: show?.ids?.tw,
      id_imdb: show?.ids?.imdb,
      id_tmdb: show?.ids?.tmdb,
      id_traktslug: show?.ids?.traktslug,
      id_jwslug: show?.ids?.jwslug,
      id_tvdb: show?.ids?.tvdb,
      next_to_watch_info_title: next_to_watch_info?.title,
      next_to_watch_info_season: next_to_watch_info?.season,
      next_to_watch_info_episode: next_to_watch_info?.episode,
      next_to_watch_info_date: next_to_watch_info?.date,
      last_sd_synced_at: syncedAt
    )
  }
}

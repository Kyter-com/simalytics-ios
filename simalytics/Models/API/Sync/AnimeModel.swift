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
  let next_to_watch_info: AnimeModel_record_item_next_to_watch_info?
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
  let mal: String?
  let imdb: String?
  let tmdb: String?
  let anilist: String?
  let kitsu: String?
  let anidb: String?
  let tvdb: String?
  let tvdbslug: String?
  let trakttvslug: String?
}

struct AnimeModel_record_item_memo: Codable {
  let text: String?
  let is_private: Bool?
}

struct AnimeModel_record_item_next_to_watch_info: Codable {
  let title: String?
  let episode: Int?
  let date: String?
}

// MARK: - SwiftData Conversion

extension AnimeModel_record {
  func toSwiftData(syncedAt: String? = nil) -> V1.SDAnimes {
    V1.SDAnimes(
      simkl: (show?.ids.simkl)!,
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
      anime_type: anime_type,
      poster: show?.poster,
      year: show?.year,
      title: show?.title,
      memo_text: memo?.text,
      memo_is_private: memo?.is_private,
      id_slug: show?.ids.slug,
      id_offjp: nil,
      id_ann: nil,
      id_mal: show?.ids.mal,
      id_anfo: nil,
      id_offen: nil,
      id_wikien: nil,
      id_wikijp: nil,
      id_allcin: nil,
      id_imdb: show?.ids.imdb,
      id_tmdb: show?.ids.tmdb,
      id_anilist: show?.ids.anilist,
      id_animeplanet: nil,
      id_anisearch: nil,
      id_kitsu: show?.ids.kitsu,
      id_livechart: nil,
      id_traktslug: show?.ids.trakttvslug,
      id_letterslug: nil,
      id_jwslug: nil,
      id_anidb: show?.ids.anidb,
      next_to_watch_info_title: next_to_watch_info?.title,
      next_to_watch_info_episode: next_to_watch_info?.episode,
      next_to_watch_info_date: next_to_watch_info?.date,
      last_sd_synced_at: syncedAt
    )
  }
}

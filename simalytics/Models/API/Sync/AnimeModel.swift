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
  /// Watching pulls update user state without erasing separately enriched catalog data.
  func updateWatchingSummary(_ row: V1.SDAnimes, syncedAt: String) {
    row.added_to_watchlist_at = added_to_watchlist_at
    row.last_watched_at = last_watched_at
    row.user_rated_at = user_rated_at
    row.user_rating = user_rating
    row.status = status
    row.last_watched = last_watched
    row.next_to_watch = next_to_watch
    row.watched_episodes_count = watched_episodes_count
    row.total_episodes_count = total_episodes_count
    row.not_aired_episodes_count = not_aired_episodes_count
    row.anime_type = anime_type
    row.title = show?.title
    row.poster = show?.poster
    row.year = show?.year
    row.memo_text = memo?.text
    row.memo_is_private = memo?.is_private
    row.id_slug = show?.ids.slug ?? row.id_slug
    row.id_mal = show?.ids.mal ?? row.id_mal
    row.id_imdb = show?.ids.imdb ?? row.id_imdb
    row.id_tmdb = show?.ids.tmdb ?? row.id_tmdb
    row.id_anilist = show?.ids.anilist ?? row.id_anilist
    row.id_kitsu = show?.ids.kitsu ?? row.id_kitsu
    row.id_anidb = show?.ids.anidb ?? row.id_anidb
    row.id_traktslug = show?.ids.trakttvslug ?? row.id_traktslug
    let next = next_to_watch?.isEmpty == false ? next_to_watch_info : nil
    row.next_to_watch_info_title = next?.title
    row.next_to_watch_info_episode = next?.episode
    row.next_to_watch_info_date = next?.date
    row.last_sd_synced_at = syncedAt
  }

  func toSwiftData(syncedAt: String? = nil) -> V1.SDAnimes {
    // A catalog row can outlive its next-to-watch marker (e.g. during a hiatus).
    let next = next_to_watch?.isEmpty == false ? next_to_watch_info : nil
    return V1.SDAnimes(
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
      next_to_watch_info_title: next?.title,
      next_to_watch_info_episode: next?.episode,
      next_to_watch_info_date: next?.date,
      last_sd_synced_at: syncedAt
    )
  }
}

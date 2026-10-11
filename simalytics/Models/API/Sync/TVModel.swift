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
  let tvdbslug: String?
  let imdb: String?
  let tmdb: String?
  let trakttvslug: String?
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
  /// Watching pulls update user state without erasing separately enriched catalog data.
  func updateWatchingSummary(_ row: V1.SDShows, syncedAt: String) {
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
    row.title = show?.title
    row.poster = show?.poster
    row.year = show?.year
    row.memo_text = memo?.text
    row.memo_is_private = memo?.is_private
    row.id_slug = show?.ids?.slug ?? row.id_slug
    row.id_tvdbslug = show?.ids?.tvdbslug ?? row.id_tvdbslug
    row.id_imdb = show?.ids?.imdb ?? row.id_imdb
    row.id_tmdb = show?.ids?.tmdb ?? row.id_tmdb
    row.id_traktslug = show?.ids?.trakttvslug ?? row.id_traktslug
    row.id_tvdb = show?.ids?.tvdb ?? row.id_tvdb
    let next = next_to_watch?.isEmpty == false ? next_to_watch_info : nil
    row.next_to_watch_info_title = next?.title
    row.next_to_watch_info_season = next?.season
    row.next_to_watch_info_episode = next?.episode
    row.next_to_watch_info_date = next?.date
    row.last_sd_synced_at = syncedAt
  }

  func toSwiftData(syncedAt: String? = nil) -> V1.SDShows {
    // A catalog row can outlive its next-to-watch marker (e.g. during a hiatus).
    let next = next_to_watch?.isEmpty == false ? next_to_watch_info : nil
    return V1.SDShows(
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
      id_offen: nil,
      id_tvdbslug: show?.ids?.tvdbslug,
      id_instagram: nil,
      id_tw: nil,
      id_imdb: show?.ids?.imdb,
      id_tmdb: show?.ids?.tmdb,
      id_traktslug: show?.ids?.trakttvslug,
      id_jwslug: nil,
      id_tvdb: show?.ids?.tvdb,
      next_to_watch_info_title: next?.title,
      next_to_watch_info_season: next?.season,
      next_to_watch_info_episode: next?.episode,
      next_to_watch_info_date: next?.date,
      last_sd_synced_at: syncedAt
    )
  }
}

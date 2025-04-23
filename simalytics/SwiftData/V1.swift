//
//  V1.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/9/25.
//

import Foundation
import SwiftData

enum V1: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(1, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [SDLastSync.self, SDMovies.self, SDShows.self, SDAnimes.self]
  }

  @Model
  class SDLastSync {
    @Attribute(.unique) var id: Int = 1
    var movies_plantowatch: String?
    var movies_dropped: String?
    var movies_completed: String?
    var movies_removed_from_list: String?
    var movies_rated_at: String?

    var tv_plantowatch: String?
    var tv_completed: String?
    var tv_hold: String?
    var tv_dropped: String?
    var tv_watching: String?
    var tv_removed_from_list: String?
    var tv_rated_at: String?

    var anime_plantowatch: String?
    var anime_dropped: String?
    var anime_completed: String?
    var anime_hold: String?
    init(
      id: Int = 1,
      movies_plantowatch: String? = nil,
      movies_dropped: String? = nil,
      movies_completed: String? = nil,
      movies_removed_from_list: String? = nil,
      movies_rated_at: String? = nil,

      tv_plantowatch: String? = nil,
      tv_completed: String? = nil,
      tv_hold: String? = nil,
      tv_dropped: String? = nil,
      tv_watching: String? = nil,
      tv_removed_from_list: String? = nil,
      tv_rated_at: String? = nil,

      anime_plantowatch: String? = nil,
      anime_dropped: String? = nil,
      anime_completed: String? = nil,
      anime_hold: String? = nil
    ) {
      self.id = id
      self.movies_plantowatch = movies_plantowatch
      self.movies_dropped = movies_dropped
      self.movies_completed = movies_completed
      self.movies_removed_from_list = movies_removed_from_list
      self.movies_rated_at = movies_rated_at

      self.tv_plantowatch = tv_plantowatch
      self.tv_completed = tv_completed
      self.tv_hold = tv_hold
      self.tv_dropped = tv_dropped
      self.tv_watching = tv_watching
      self.tv_removed_from_list = tv_removed_from_list
      self.tv_rated_at = tv_rated_at

      self.anime_plantowatch = anime_plantowatch
      self.anime_dropped = anime_dropped
      self.anime_completed = anime_completed
      self.anime_hold = anime_hold
    }
  }

  @Model
  class SDMovies {
    @Attribute(.unique) var simkl: Int
    var title: String?
    var added_to_watchlist_at: String?
    var last_watched_at: String?
    var user_rated_at: String?
    var status: String?
    var user_rating: Int?
    var poster: String?
    var year: Int?
    var id_slug: String?
    var id_tvdbmslug: String?
    var id_imdb: String?
    var id_offen: String?
    var id_traktslug: String?
    var id_letterslug: String?
    var id_jwslug: String?
    var id_tmdb: String?
    var memo_text: String?
    var memo_is_private: Bool?

    init(
      simkl: Int,
      title: String?,
      added_to_watchlist_at: String?,
      last_watched_at: String?,
      user_rated_at: String?,
      status: String?,
      user_rating: Int?,
      poster: String?,
      year: Int?,
      id_slug: String?,
      id_tvdbmslug: String?,
      id_imdb: String?,
      id_offen: String?,
      id_traktslug: String?,
      id_letterslug: String?,
      id_jwslug: String?,
      id_tmdb: String?,
      memo_text: String?,
      memo_is_private: Bool?
    ) {
      self.simkl = simkl
      self.title = title
      self.added_to_watchlist_at = added_to_watchlist_at
      self.last_watched_at = last_watched_at
      self.user_rated_at = user_rated_at
      self.status = status
      self.user_rating = user_rating
      self.poster = poster
      self.year = year
      self.id_slug = id_slug
      self.id_tvdbmslug = id_tvdbmslug
      self.id_imdb = id_imdb
      self.id_offen = id_offen
      self.id_traktslug = id_traktslug
      self.id_letterslug = id_letterslug
      self.id_jwslug = id_jwslug
      self.id_tmdb = id_tmdb
      self.memo_text = memo_text
      self.memo_is_private = memo_is_private
    }
  }

  @Model
  class SDShows {
    @Attribute(.unique) var simkl: Int
    var added_to_watchlist_at: String?
    var last_watched_at: String?
    var user_rated_at: String?
    var user_rating: Int?
    var status: String?
    var last_watched: String?
    var next_to_watch: String?
    var watched_episodes_count: Int?
    var total_episodes_count: Int?
    var not_aired_episodes_count: Int?
    var title: String?
    var poster: String?
    var year: Int?
    var memo_text: String?
    var memo_is_private: Bool?
    var id_slug: String?
    var id_offen: String?
    var id_tvdbslug: String?
    var id_instagram: String?
    var id_tw: String?
    var id_imdb: String?
    var id_tmdb: String?
    var id_traktslug: String?
    var id_jwslug: String?
    var id_tvdb: String?
    init(
      simkl: Int,
      added_to_watchlist_at: String?,
      last_watched_at: String?,
      user_rated_at: String?,
      user_rating: Int?,
      status: String?,
      last_watched: String?,
      next_to_watch: String?,
      watched_episodes_count: Int?,
      total_episodes_count: Int?,
      not_aired_episodes_count: Int?,
      title: String?,
      poster: String?,
      year: Int?,
      memo_text: String?,
      memo_is_private: Bool?,
      id_slug: String?,
      id_offen: String?,
      id_tvdbslug: String?,
      id_instagram: String?,
      id_tw: String?,
      id_imdb: String?,
      id_tmdb: String?,
      id_traktslug: String?,
      id_jwslug: String?,
      id_tvdb: String?
    ) {
      self.simkl = simkl
      self.added_to_watchlist_at = added_to_watchlist_at
      self.last_watched_at = last_watched_at
      self.user_rated_at = user_rated_at
      self.user_rating = user_rating
      self.status = status
      self.last_watched = last_watched
      self.next_to_watch = next_to_watch
      self.watched_episodes_count = watched_episodes_count
      self.total_episodes_count = total_episodes_count
      self.not_aired_episodes_count = not_aired_episodes_count
      self.title = title
      self.poster = poster
      self.year = year
      self.memo_text = memo_text
      self.memo_is_private = memo_is_private
      self.id_slug = id_slug
      self.id_offen = id_offen
      self.id_tvdbslug = id_tvdbslug
      self.id_instagram = id_instagram
      self.id_tw = id_tw
      self.id_imdb = id_imdb
      self.id_tmdb = id_tmdb
      self.id_traktslug = id_traktslug
      self.id_jwslug = id_jwslug
      self.id_tvdb = id_tvdb
    }
  }

  @Model
  class SDAnimes {
    @Attribute(.unique) var simkl: Int
    var added_to_watchlist_at: String?
    var last_watched_at: String?
    var user_rated_at: String?
    var user_rating: Int?
    var status: String?
    var last_watched: String?
    var next_to_watch: String?
    var watched_episodes_count: Int?
    var total_episodes_count: Int?
    var not_aired_episodes_count: Int?
    var anime_type: String?
    var poster: String?
    var year: Int?
    var memo_text: String?
    var memo_is_private: Bool?
    var id_slug: String?
    var id_offjp: String?
    var id_ann: String?
    var id_mal: String?
    var id_anfo: String?
    var id_offen: String?
    var id_wikien: String?
    var id_wikijp: String?
    var id_allcin: String?
    var id_imdb: String?
    var id_tmdb: String?
    var id_anilist: String?
    var id_animeplanet: String?
    var id_anisearch: String?
    var id_kitsu: String?
    var id_livechart: String?
    var id_traktslug: String?
    var id_letterslug: String?
    var id_jwslug: String?
    var id_anidb: String?
    init(
      simkl: Int,
      added_to_watchlist_at: String? = nil,
      last_watched_at: String? = nil,
      user_rated_at: String? = nil,
      user_rating: Int? = nil,
      status: String? = nil,
      last_watched: String? = nil,
      next_to_watch: String? = nil,
      watched_episodes_count: Int? = nil,
      total_episodes_count: Int? = nil,
      not_aired_episodes_count: Int? = nil,
      anime_type: String? = nil,
      poster: String? = nil,
      year: Int? = nil,
      memo_text: String? = nil,
      memo_is_private: Bool? = nil,
      id_slug: String? = nil,
      id_offjp: String? = nil,
      id_ann: String? = nil,
      id_mal: String? = nil,
      id_anfo: String? = nil,
      id_offen: String? = nil,
      id_wikien: String? = nil,
      id_wikijp: String? = nil,
      id_allcin: String? = nil,
      id_imdb: String? = nil,
      id_tmdb: String? = nil,
      id_anilist: String? = nil,
      id_animeplanet: String? = nil,
      id_anisearch: String? = nil,
      id_kitsu: String? = nil,
      id_livechart: String? = nil,
      id_traktslug: String? = nil,
      id_letterslug: String? = nil,
      id_jwslug: String? = nil,
      id_anidb: String? = nil
    ) {
      self.simkl = simkl
      self.added_to_watchlist_at = added_to_watchlist_at
      self.last_watched_at = last_watched_at
      self.user_rated_at = user_rated_at
      self.user_rating = user_rating
      self.status = status
      self.last_watched = last_watched
      self.next_to_watch = next_to_watch
      self.watched_episodes_count = watched_episodes_count
      self.total_episodes_count = total_episodes_count
      self.not_aired_episodes_count = not_aired_episodes_count
      self.anime_type = anime_type
      self.poster = poster
      self.year = year
      self.memo_text = memo_text
      self.memo_is_private = memo_is_private
      self.id_slug = id_slug
      self.id_offjp = id_offjp
      self.id_ann = id_ann
      self.id_mal = id_mal
      self.id_anfo = id_anfo
      self.id_offen = id_offen
      self.id_wikien = id_wikien
      self.id_wikijp = id_wikijp
      self.id_allcin = id_allcin
      self.id_imdb = id_imdb
      self.id_tmdb = id_tmdb
      self.id_anilist = id_anilist
      self.id_animeplanet = id_animeplanet
      self.id_anisearch = id_anisearch
      self.id_kitsu = id_kitsu
      self.id_livechart = id_livechart
      self.id_traktslug = id_traktslug
      self.id_letterslug = id_letterslug
      self.id_jwslug = id_jwslug
      self.id_anidb = id_anidb
    }
  }
}

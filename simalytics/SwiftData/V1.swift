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
    [SDLastSync.self, SDMovies.self]
  }

  @Model
  class SDLastSync {
    @Attribute(.unique) var id: Int
    var movies_plantowatch: String?
    var movies_dropped: String?
    var movies_completed: String?
    init(
      id: Int = 1,
      movies_plantowatch: String? = nil,
      movies_dropped: String? = nil,
      movies_completed: String? = nil
    ) {
      self.id = id
      self.movies_plantowatch = movies_plantowatch
      self.movies_dropped = movies_dropped
      self.movies_completed = movies_completed
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
}

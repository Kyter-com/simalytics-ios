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
    init(
      id: Int = 1,
      movies_plantowatch: String? = nil
    ) {
      self.id = id
      self.movies_plantowatch = movies_plantowatch
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

    init(
      simkl: Int,
      title: String?,
      added_to_watchlist_at: String?,
      last_watched_at: String?,
      user_rated_at: String?,
      status: String?,
      user_rating: Int?,
      poster: String?
    ) {
      self.simkl = simkl
      self.title = title
      self.added_to_watchlist_at = added_to_watchlist_at
      self.last_watched_at = last_watched_at
      self.user_rated_at = user_rated_at
      self.status = status
      self.user_rating = user_rating
      self.poster = poster
    }
  }
}

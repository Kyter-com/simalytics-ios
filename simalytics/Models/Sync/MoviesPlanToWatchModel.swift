//
//  MoviesPlanToWatchModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/8/25.
//

import Foundation

struct MoviesPlanToWatchModel: Codable {
  let movies: [MoviesPlanToWatchModel_movie]?
}

struct MoviesPlanToWatchModel_movie: Codable {
  let added_to_watchlist_at: String?
  let last_watched_at: String?
  let user_rated_at: String?
  let status: String?
  let user_rating: Int?
  let movie: MoviesPlanToWatchModel_movie_item?
}

struct MoviesPlanToWatchModel_movie_item: Codable {
  let title: String?
  let poster: String?
  let year: Int?
  let ids: MoviesPlanToWatchModel_movie_item_ids?
  let memo: MoviesPlanToWatchModel_movie_item_memo?
}

struct MoviesPlanToWatchModel_movie_item_ids: Codable {
  let simkl: Int
  let slug: String?
  let tvdbmslug: String?
  let imdb: String?
  let offen: String?
  let traktslug: String?
  let letterslug: String?
  let jwslug: String?
  let tmdb: String?
}

struct MoviesPlanToWatchModel_movie_item_memo: Codable {
  let text: String?
  let is_private: Bool?
}

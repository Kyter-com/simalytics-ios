//
//  MoviesModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/8/25.
//

import Foundation

struct MoviesModel: Codable {
  let movies: [MoviesModel_movie]?
}

struct MoviesModel_movie: Codable {
  let added_to_watchlist_at: String?
  let last_watched_at: String?
  let user_rated_at: String?
  let status: String?
  let user_rating: Int?
  let movie: MoviesModel_movie_item?
  let memo: MoviesModel_movie_item_memo?
}

struct MoviesModel_movie_item: Codable {
  let title: String?
  let poster: String?
  let year: Int?
  let ids: MoviesModel_movie_item_ids?
}

struct MoviesModel_movie_item_ids: Codable {
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

struct MoviesModel_movie_item_memo: Codable {
  let text: String?
  let is_private: Bool?
}

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

// MARK: - SwiftData Conversion

extension MoviesModel_movie {
  func toSwiftData() -> V1.SDMovies {
    V1.SDMovies(
      simkl: (movie?.ids?.simkl)!,
      title: movie?.title,
      added_to_watchlist_at: added_to_watchlist_at,
      last_watched_at: last_watched_at,
      user_rated_at: user_rated_at,
      status: status,
      user_rating: user_rating,
      poster: movie?.poster,
      year: movie?.year,
      id_slug: movie?.ids?.slug,
      id_tvdbmslug: movie?.ids?.tvdbmslug,
      id_imdb: movie?.ids?.imdb,
      id_offen: movie?.ids?.offen,
      id_traktslug: movie?.ids?.traktslug,
      id_letterslug: movie?.ids?.letterslug,
      id_jwslug: movie?.ids?.jwslug,
      id_tmdb: movie?.ids?.tmdb,
      memo_text: memo?.text,
      memo_is_private: memo?.is_private
    )
  }
}

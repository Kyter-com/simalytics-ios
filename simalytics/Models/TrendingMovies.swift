//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingMovie: Codable {
  let title: String
  let url: String
  let poster: String
  let fanart: String?
  let ids: TrendingMoviesIDs
  let release_date: String?
  let rank: Int?
  let drop_rate: String?
  let watched: Int?
  let plan_to_watch: Int?
  let ratings: TrendingMoviesRatings
  let country: String
  let runtime: String?
  let status: String
  let dvd_date: String?
  let metadata: String
  let overview: String
  let genres: [String]
  let theater: String?
}

struct TrendingMoviesIDs: Codable {
  let simkl_id: Int
  let slug: String
  let tmdb: String
}

struct TrendingMoviesRatings: Codable {
  let simkl: TrendingMoviesRating
  let imdb: TrendingMoviesRating?
}

struct TrendingMoviesRating: Codable {
  let rating: Double?
  let votes: Int?
}

//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingMovie: Codable {
  let title: String
  let url: String
  let poster: String
  let fanart: String?
  let ids: TrendingMoviesIDs
  let releaseDate: String?
  let rank: Int?
  let dropRate: String?
  let watched: Int
  let planToWatch: Int?
  let ratings: TrendingMoviesRatings
  let country: String
  let runtime: String?
  let status: String
  let dvdDate: String?
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
  let simkl: Rating
  let imdb: Rating?
}

struct Rating: Codable {
  let rating: Double?
  let votes: Int?
}

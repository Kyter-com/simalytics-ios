//
//  MovieDetailsModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/7/25.
//

import Foundation

struct MovieDetailsModel: Codable {
  let title: String
  let year: Int?
  let poster: String?
  let runtime: Int?
  let fanart: String?
  let rank: Int?
  let certification: String?
  let language: String?
  let ratings: MovieDetailsModelRatings?
  let overview: String?
  let genres: [String]?
  let trailers: [MovieDetailsModelTrailer]?
  let users_recommendations: [MovieDetailsModelRecommendation]?
}

struct MovieDetailsModelRatings: Codable {
  let simkl: MovieDetailsModelRating?
  let imdb: MovieDetailsModelRating?
}

struct MovieDetailsModelRating: Codable {
  let rating: Double?
  let votes: Int?
}

struct MovieDetailsModelTrailer: Codable {
  let name: String?
  let youtube: String?
  let size: Int?
}

struct MovieDetailsModelRecommendation: Codable {
  let title: String
  let year: Int?
  let poster: String?
  let ids: MovieDetailsModelRecommendationIds
}

struct MovieDetailsModelRecommendationIds: Codable {
  let simkl: Int
  let slug: String
}

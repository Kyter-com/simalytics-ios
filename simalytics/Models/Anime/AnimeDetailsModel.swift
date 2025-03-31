//
//  AnimeDetailsModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Foundation

struct AnimeDetailsModel: Codable {
  let title: String
  let fanart: String?
  let poster: String?
  let genres: [String]?
  let overview: String?
  let year_start_end: String?
  let users_recommendations: [RecommendationModel]?
  let total_episodes: Int?
  let ratings: ShowDetailsModelRatings?
  let runtime: Int?
}

struct AnimeDetailsModelRatings: Codable {
  let simkl: AnimeDetailsModelRating?
  let imdb: AnimeDetailsModelRating?
}

struct AnimeDetailsModelRating: Codable {
  let rating: Double?
  let votes: Int?
}

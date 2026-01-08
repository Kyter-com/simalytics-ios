//
//  ShowDetailsModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/21/25.
//

import Foundation

struct ShowDetailsModel: Codable {
  let title: String
  let poster: String?
  let fanart: String?
  let year: Int?
  let ratings: Ratings?
  let year_start_end: String?
  let runtime: Int?
  let total_episodes: Int?
  let overview: String?
  let genres: [String]?
  let users_recommendations: [RecommendationModel]?
  let ids: ShowDetailsModelIds?
}

struct ShowDetailsModelIds: Codable {
  let tmdb: String?
}

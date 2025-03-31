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
}

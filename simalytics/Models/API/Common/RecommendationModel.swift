//
//  RecommendationModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/30/25.
//

import Foundation

struct RecommendationModel: Codable {
  let title: String
  let year: Int?
  let poster: String?
  let ids: RecommendationModelIds
  let type: String
}

struct RecommendationModelIds: Codable {
  let simkl: Int
  let slug: String
}

//
//  TrendingAnimeModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingAnimeModel: Codable {
  let title: String
  let poster: String
  let ids: TrendingAnimeModel_ids
}

struct TrendingAnimeModel_ids: Codable {
  let simkl_id: Int
}

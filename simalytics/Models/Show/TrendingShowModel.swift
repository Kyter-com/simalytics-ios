//
//  TrendingShowModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingShowModel: Codable {
  let title: String
  let poster: String
  let ids: TrendingShowModel_ids
}

struct TrendingShowModel_ids: Codable {
  let simkl_id: Int
}

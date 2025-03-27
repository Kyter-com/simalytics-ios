//
//  TrendingShowModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingShowModel: Codable {
  let title: String
  let poster: String  // TODO: Make optional and use default image
  let ids: TrendingShowModel_ids
}

struct TrendingShowModel_ids: Codable {
  let simkl_id: Int
}

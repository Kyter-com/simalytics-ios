//
//  SearchResultModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/3/25.
//

import Foundation

struct SearchResultModel: Codable {
  let title: String
  let year: Int?
  let poster: String?
  let endpoint_type: String
  let ids: SearchResultModel_ids
}

struct SearchResultModel_ids: Codable {
  let simkl_id: Int
}

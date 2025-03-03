//
//  SearchResultsModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/3/25.
//

import Foundation

struct SearchResult: Codable {
  let title: String
  let year: Int
  let poster: String
  let endpoint_type: String
  let ids: SearchResultIDs
}

struct SearchResultIDs: Codable {
  let simkl_id: Int
  let slug: String
  let tmdb: String?
}

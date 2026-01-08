//
//  TrendingMovieModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingMovieModel: Codable {
  let title: String
  let poster: String?
  let ids: TrendingMovieModel_ids
}

struct TrendingMovieModel_ids: Codable {
  let simkl_id: Int
}

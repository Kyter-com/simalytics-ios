//
//  MovieDetailsModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/7/25.
//

import Foundation

struct MovieDetailsModel: Codable {
  let title: String
  let year: Int?
  let poster: String?
  let runtime: Int?
  let fanart: String?
}

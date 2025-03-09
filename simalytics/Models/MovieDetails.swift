//
//  MovieDetails.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/7/25.
//

import Foundation

struct MovieDetails: Codable {
  let title: String
  let year: Int?
  let fanart: String?
  let runtime: Int?
}

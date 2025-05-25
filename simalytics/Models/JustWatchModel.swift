//
//  JustWatchModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/24/25.
//

import Foundation

struct JustWatchModel: Codable {
  let id: Int
  let results: JustWatchResults
}

struct JustWatchResults: Codable {
  let US: JustWatchListings
}

struct JustWatchFlatrate: Codable {
  let logoPath: String
  let providerID: Int
  let providerName: String
  let displayPriority: Int

  enum CodingKeys: String, CodingKey {
    case logoPath
    case providerID
    case providerName
    case displayPriority
  }
}

struct JustWatchListings: Codable {
  let link: String
  let buy: [JustWatchFlatrate]?
  let flatrate: [JustWatchFlatrate]?
  let rent: [JustWatchFlatrate]?
}

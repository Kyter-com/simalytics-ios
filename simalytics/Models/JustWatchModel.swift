//
//  JustWatchModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/24/25.
//

import Foundation

struct JustWatchModel: Codable {
  let id: Int
  let results: JustWatchResults?
}

struct JustWatchResults: Codable {
  let US: JustWatchListings?
}

struct JustWatchOption: Codable {
  let logo_path: String?
  let provider_id: Int?
  let provider_name: String?
  let display_priority: Int?
}

struct JustWatchListings: Codable {
  let link: String?
  let buy: [JustWatchOption]?
  let flatrate: [JustWatchOption]?
  let rent: [JustWatchOption]?
  let free: [JustWatchOption]?
}

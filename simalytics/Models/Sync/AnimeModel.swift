//
//  AnimeModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/22/25.
//

import Foundation

struct AnimeModel: Codable {
  let anime: [AnimeModel_record]?
}

struct AnimeModel_record: Codable {
  let added_to_watchlist_at: String?
  let show: AnimeModel_record_item?
}

struct AnimeModel_record_item: Codable {
  let title: String?
  let ids: AnimeModel_record_item_ids
}

struct AnimeModel_record_item_ids: Codable {
  let simkl: Int
}

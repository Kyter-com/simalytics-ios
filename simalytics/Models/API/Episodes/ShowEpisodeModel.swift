//
//  ShowEpisodeModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/24/25.
//

import Foundation

struct ShowEpisodeModel: Codable {
  let title: String
  let description: String?
  let season: Int?
  let episode: Int?
  let type: String?
  let date: String?
  let img: String?
  let aired: Bool?
  let ids: ShowEpisodeModelIds
}

struct ShowEpisodeModelIds: Codable {
  let simkl_id: Int
}

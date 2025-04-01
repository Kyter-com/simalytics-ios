//
//  AnimeEpisodeModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import Foundation

struct AnimeEpisodeModel: Codable {
  let title: String
  let description: String?
  let episode: Int?
  let type: String?
  let aired: Bool?
  let img: String?
  let date: String?
  // Added in ViewModel
  var season: Int?
  let ids: AnimeEpisodeModelIds
}

struct AnimeEpisodeModelIds: Codable {
  let simkl_id: Int
}

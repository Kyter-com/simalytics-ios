//
//  UpNextShowModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/26/25.
//

import Foundation

struct UpNextShowModel: Decodable {
  let shows: [UpNextShowModel_show]
}

struct UpNextShowModel_show: Decodable {
  let next_to_watch_info: UpNextShowModel_next_to_watch_info?
  let show: UpNextShowModel_show_details

  struct UpNextShowModel_next_to_watch_info: Decodable {
    let title: String?
    let season: Int?
    let episode: Int?
  }

  struct UpNextShowModel_show_details: Decodable {
    let title: String
    let poster: String
    let ids: UpNextShowModel_ids

    struct UpNextShowModel_ids: Decodable {
      let simkl: Int
    }
  }
}

//
//  UpNextShowModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/26/25.
//

import Foundation

struct ShowsResponse: Decodable {
  let shows: [Show]
}

struct Show: Decodable {
  let next_to_watch_info: NextToWatchInfo?
  let show: ShowDetails

  struct NextToWatchInfo: Decodable {
    let title: String?
    let season: Int?
    let episode: Int?
  }

  struct ShowDetails: Decodable {
    let title: String
    let poster: String
    let ids: IDs

    struct IDs: Decodable {
      let simkl: Int
    }
  }
}

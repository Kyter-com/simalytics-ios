//
//  TrendingShows.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingShow: Decodable {
  let title: String
  let url: String
  let poster: String
  let fanart: String
  let ids: IDs
  let release_date: String
  let rank: Int?
  let drop_rate: String
  let watched: Int
  let plan_to_watch: Int
  let ratings: Ratings
  let country: String
  let runtime: String
  let status: String
  let total_episodes: Int
  let network: String
  let metadata: String
  let overview: String
  let genres: [String]
  let trailer: String
}

struct IDs: Decodable {
  let simkl_id: Int
  let slug: String
  let tmdb: String
}

struct Ratings: Decodable {
  let simkl: Simkl?
  let imdb: IMDB?
}

struct Simkl: Decodable {
  let rating: Double?
  let votes: Int?
}

struct IMDB: Decodable {
  let rating: Double?
  let votes: Int?
}

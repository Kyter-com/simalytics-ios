//
//  TrendingAnimes.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/28/25.
//

import Foundation

struct TrendingAnime: Codable {
  let title: String
  let url: String
  let poster: String
  let fanart: String?
  let ids: TrendingAnimesIDs
  let release_date: String
  let rank: Int
  let drop_rate: String?
  let watched: Int
  let plan_to_watch: Int
  let ratings: TrendingAnimesRatings
  let country: String
  let runtime: String
  let status: String
  let anime_type: String
  let total_episodes: Int
  let network: String?
  let metadata: String
  let overview: String?
  let genres: [String]
  let trailer: String?
}

struct TrendingAnimesIDs: Codable {
  let simkl_id: Int
  let slug: String
  let tmdb: String?
}

struct TrendingAnimesRatings: Codable {
  let simkl: TrendingAnimeRating
  let mal: TrendingAnimeRating
}

struct TrendingAnimeRating: Codable {
  let rating: Double
  let votes: Int
}

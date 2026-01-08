//
//  LastActivitiesModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/6/25.
//

import Foundation

struct LastActivitiesModel: Codable {
  let all: String?
  let tv_shows: LastActivitiesTVModel?
  let movies: LastActivitiesMovieModel?
  let anime: LastActivitiesAnimeModel?
  let settings: LastActivitiesSettingsModel?
}

struct LastActivitiesAnimeModel: Codable {
  let all: String?
  let rated_at: String?
  let plantowatch: String?
  let watching: String?
  let completed: String?
  let hold: String?
  let dropped: String?
  let removed_from_list: String?
}

struct LastActivitiesMovieModel: Codable {
  let all: String?
  let rated_at: String?
  let plantowatch: String?
  let completed: String?
  let dropped: String?
  let removed_from_list: String?
}

struct LastActivitiesTVModel: Codable {
  let all: String?
  let rated_at: String?
  let plantowatch: String?
  let watching: String?
  let completed: String?
  let hold: String?
  let dropped: String?
  let removed_from_list: String?
}

struct LastActivitiesSettingsModel: Codable {
  let all: String?
}

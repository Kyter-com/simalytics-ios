//
//  LastActivitiesModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import SwiftData

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

@Model
class LastActivities {
  @Attribute(.unique) var id: UUID
  var all: String?
  var tv_shows: LastActivitiesTV?
  var movies: LastActivitiesMovie?
  var anime: LastActivitiesAnime?

  init(
    all: String?, tv_shows: LastActivitiesTV?, movies: LastActivitiesMovie?,
    anime: LastActivitiesAnime?
  ) {
    self.id = UUID()
    self.all = all
    self.tv_shows = tv_shows
    self.movies = movies
    self.anime = anime
  }
}

@Model
class LastActivitiesAnime {
  var all: String?
  var rated_at: String?
  var plantowatch: String?
  var watching: String?
  var completed: String?
  var hold: String?
  var dropped: String?
  var removed_from_list: String?

  init(
    all: String?, rated_at: String?, plantowatch: String?, watching: String?, completed: String?,
    hold: String?, dropped: String?, removed_from_list: String?
  ) {
    self.all = all
    self.rated_at = rated_at
    self.plantowatch = plantowatch
    self.watching = watching
    self.completed = completed
    self.hold = hold
    self.dropped = dropped
    self.removed_from_list = removed_from_list
  }
}

@Model
class LastActivitiesMovie {
  var all: String?
  var rated_at: String?
  var plantowatch: String?
  var completed: String?
  var dropped: String?
  var removed_from_list: String?

  init(
    all: String?, rated_at: String?, plantowatch: String?, completed: String?, dropped: String?,
    removed_from_list: String?
  ) {
    self.all = all
    self.rated_at = rated_at
    self.plantowatch = plantowatch
    self.completed = completed
    self.dropped = dropped
    self.removed_from_list = removed_from_list
  }
}

@Model
class LastActivitiesTV {
  var all: String?
  var rated_at: String?
  var plantowatch: String?
  var watching: String?
  var completed: String?
  var hold: String?
  var dropped: String?
  var removed_from_list: String?

  init(
    all: String?, rated_at: String?, plantowatch: String?, watching: String?, completed: String?,
    hold: String?, dropped: String?, removed_from_list: String?
  ) {
    self.all = all
    self.rated_at = rated_at
    self.plantowatch = plantowatch
    self.watching = watching
    self.completed = completed
    self.hold = hold
    self.dropped = dropped
    self.removed_from_list = removed_from_list
  }
}

@Model
class LastActivitiesSettings {
  var all: String?
  init(all: String?) {
    self.all = all
  }
}

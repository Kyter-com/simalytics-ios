//
//  SDLastActivities.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/4/25.
//

import Foundation
import SwiftData

@Model
class SDLastActivities {
  @Attribute(.unique) var id: UUID
  var all: String?

  var settings_all: String?

  var tv_shows_all: String?
  var tv_shows_rated_at: String?
  var tv_shows_plantowatch: String?
  var tv_shows_watching: String?
  var tv_shows_completed: String?
  var tv_shows_hold: String?
  var tv_shows_dropped: String?
  var tv_shows_removed_from_list: String?

  var movies_all: String?
  var movies_rated_at: String?
  var movies_plantowatch: String?
  var movies_completed: String?
  var movies_dropped: String?
  var movies_removed_from_list: String?

  var anime_all: String?
  var anime_rated_at: String?
  var anime_plantowatch: String?
  var anime_watching: String?
  var anime_completed: String?
  var anime_hold: String?
  var anime_dropped: String?
  var anime_removed_from_list: String?
  init(
    all: String?,
    settings_all: String?,
    tv_shows_all: String?,
    tv_shows_rated_at: String?,
    tv_shows_plantowatch: String?,
    tv_shows_watching: String?,
    tv_shows_completed: String?,
    tv_shows_hold: String?,
    tv_shows_dropped: String?,
    tv_shows_removed_from_list: String?,
    movies_all: String?,
    movies_rated_at: String?,
    movies_plantowatch: String?,
    movies_completed: String?,
    movies_dropped: String?,
    movies_removed_from_list: String?,
    anime_all: String?,
    anime_rated_at: String?,
    anime_plantowatch: String?,
    anime_watching: String?,
    anime_completed: String?,
    anime_hold: String?,
    anime_dropped: String?,
    anime_removed_from_list: String?
  ) {
    self.id = UUID()
    self.all = all
    self.settings_all = settings_all
    self.tv_shows_all = tv_shows_all
    self.tv_shows_rated_at = tv_shows_rated_at
    self.tv_shows_plantowatch = tv_shows_plantowatch
    self.tv_shows_watching = tv_shows_watching
    self.tv_shows_completed = tv_shows_completed
    self.tv_shows_hold = tv_shows_hold
    self.tv_shows_dropped = tv_shows_dropped
    self.tv_shows_removed_from_list = tv_shows_removed_from_list
    self.movies_all = movies_all
    self.movies_rated_at = movies_rated_at
    self.movies_plantowatch = movies_plantowatch
    self.movies_completed = movies_completed
    self.movies_dropped = movies_dropped
    self.movies_removed_from_list = movies_removed_from_list
    self.anime_all = anime_all
    self.anime_rated_at = anime_rated_at
    self.anime_plantowatch = anime_plantowatch
    self.anime_watching = anime_watching
    self.anime_completed = anime_completed
    self.anime_hold = anime_hold
    self.anime_dropped = anime_dropped
    self.anime_removed_from_list = anime_removed_from_list
  }
}

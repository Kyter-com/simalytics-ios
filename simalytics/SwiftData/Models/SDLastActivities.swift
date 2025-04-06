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
    tv_shows_removed_from_list: String?
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
  }
}

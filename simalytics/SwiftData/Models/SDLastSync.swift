//
//  SDLastSync.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/8/25.
//

import Foundation
import SwiftData

@Model
class SDLastSync {
  @Attribute(.unique) var id: Int
  var movies_plantowatch: String?
  init(
    id: Int = 1,
    movies_plantowatch: String? = nil
  ) {
    self.id = id
    self.movies_plantowatch = movies_plantowatch
  }
}

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
  @Attribute(.unique) var id: UUID
  var movies_plantowatch: String?
  init(
    movies_plantowatch: String? = nil,
  ) {
    self.id = UUID()
    self.movies_plantowatch = movies_plantowatch
  }
}

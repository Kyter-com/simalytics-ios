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
  init(
    all: String?
  ) {
    self.id = UUID()
    self.all = all
  }
}

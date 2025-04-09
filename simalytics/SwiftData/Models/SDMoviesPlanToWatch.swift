//
//  SDMoviesPlanToWatch.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/7/25.
//

import Foundation
import SwiftData

@Model
class SDMoviesPlanToWatch {
  @Attribute(.unique) var simkl: Int

  init(simkl: Int) {
    self.simkl = simkl
  }
}

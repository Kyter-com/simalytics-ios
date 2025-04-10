//
//  V1.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/9/25.
//

import Foundation
import SwiftData

enum V1: VersionedSchema {
  static var versionIdentifier: Schema.Version {
    Schema.Version(1, 0, 0)
  }

  static var models: [any PersistentModel.Type] {
    [SDLastSync.self, SDMoviesPlanToWatch.self]
  }

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

  @Model
  class SDMoviesPlanToWatch {
    @Attribute(.unique) var simkl: Int
    var title: String?

    init(simkl: Int, title: String?) {
      self.simkl = simkl
      self.title = title
    }
  }
}

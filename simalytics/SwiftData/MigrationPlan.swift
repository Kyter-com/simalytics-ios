//
//  MigrationPlan.swift
//  simalytics
//

import Foundation
import SwiftData

enum SimalyticsMigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] { [V1.self] }
  static var stages: [MigrationStage] { [] }
}

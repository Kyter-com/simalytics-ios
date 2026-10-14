//
//  GlobalLoadingIndicator.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import SwiftUI

@MainActor @Observable
final class GlobalLoadingIndicator {
  private var activeOperations = 0

  var isSyncing: Bool { activeOperations > 0 }

  func startSync() {
    activeOperations += 1
  }

  func stopSync() {
    activeOperations = max(0, activeOperations - 1)
  }
}

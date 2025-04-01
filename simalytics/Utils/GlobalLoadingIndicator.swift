//
//  GlobalLoadingIndicator.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import SwiftUI

@Observable
class GlobalLoadingIndicator {
  var isSyncing: Bool = false

  func startSync() {
    isSyncing = true
  }

  func stopSync() {
    isSyncing = false
  }
}

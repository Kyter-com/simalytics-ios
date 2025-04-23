//
//  Dates.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/23/25.
//

import Foundation

extension Date {
  func timeAgoDisplay() -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: self, relativeTo: Date())
  }
}

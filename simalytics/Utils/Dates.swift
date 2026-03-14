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

func normalizeReleaseDateString(_ rawDate: String?) -> String? {
  guard let trimmed = rawDate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
    return nil
  }

  let dayFormatter = DateFormatter()
  dayFormatter.locale = Locale(identifier: "en_US_POSIX")
  dayFormatter.dateFormat = "yyyy-MM-dd"

  if let date = dayFormatter.date(from: trimmed) {
    return dayFormatter.string(from: date)
  }

  let isoFormatter = ISO8601DateFormatter()
  if let date = isoFormatter.date(from: trimmed) {
    return dayFormatter.string(from: date)
  }

  isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = isoFormatter.date(from: trimmed) {
    return dayFormatter.string(from: date)
  }

  if trimmed.count >= 10 {
    let prefix = String(trimmed.prefix(10))
    if dayFormatter.date(from: prefix) != nil {
      return prefix
    }
  }

  return nil
}

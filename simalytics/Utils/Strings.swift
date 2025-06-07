//
//  Strings.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Foundation

extension String {
  var stripHTML: String {
    var strippedText = self
    let replacements: [String: String] = [
      "<br>": "\n"
    ]

    for (tag, replacement) in replacements {
      strippedText = strippedText.replacingOccurrences(of: tag, with: replacement)
    }

    return strippedText
  }

  func formattedEpisodeDate() -> String {
    let isoFormatter = ISO8601DateFormatter()
    guard let date = isoFormatter.date(from: self) else { return self }

    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
  }
}

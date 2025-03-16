//
//  MovieWatchlistButton.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/16/25.
//

import SwiftUI

struct MovieWatchlistButton: View {
  var status: String?

  var body: some View {
    Button(action: {
      // Action to perform
    }) {
      HStack {
        Image(systemName: mapStatusToIcon(status))
        Text(mapStatus(status))
      }
    }
    .buttonStyle(.borderedProminent)
  }

  private func mapStatusToIcon(_ status: String?) -> String {
    if status == nil {
      return "list.star"
    } else if status == "plantowatch" {
      return "star"
    } else if status == "dropped" {
      return "xmark.app"
    } else if status == "completed" {
      return "checkmark.seal"
    } else {
      return "questionmark.app"
    }
  }

  private func mapStatus(_ status: String?) -> String {
    if status == nil {
      return "Add to Watchlist"
    } else if status == "plantowatch" {
      return "Plan to Watch"
    } else if status == "dropped" {
      return "Dropped"
    } else if status == "completed" {
      return "Completed"
    } else {
      return "Unknown"
    }
  }
}

//
//  MovieWatchlistButton.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/16/25.
//

import SwiftUI

struct MovieWatchlistButton: View {
  @State private var status: String?
  let statusOptions = ["plantowatch", "dropped", "completed"]

  var body: some View {
    Menu {
      if status != nil {
        Button(
          role: .destructive,
          action: {
            status = nil
          }
        ) {
          Label("Remove from List", systemImage: "trash")
        }
        Divider()
      }

      ForEach(statusOptions, id: \.self) { option in
        Button(action: {
          status = option
        }) {
          Label(mapStatus(option), systemImage: mapStatusToIcon(option))
        }
      }
    } label: {
      HStack {
        Image(systemName: mapStatusToIcon(status))
        Text(mapStatus(status))
      }
      .foregroundColor(.blue)  // Apply to both icon and text
      .padding(.horizontal, 75)
      .padding(.vertical, 15)
      .background(Color.blue.opacity(0.1))
      .cornerRadius(10)
    }
  }

  private func mapStatusToIcon(_ status: String?) -> String {
    switch status {
    case "plantowatch":
      return "star"
    case "dropped":
      return "hand.thumbsdown"
    case "completed":
      return "checkmark.circle"
    default:
      return "list.bullet.indent"
    }
  }

  private func mapStatus(_ status: String?) -> String {
    switch status {
    case "plantowatch":
      return "Plan to Watch"
    case "dropped":
      return "Dropped"
    case "completed":
      return "Completed"
    default:
      return "Add to List"
    }
  }
}

struct MovieWatchlistMenu_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      MovieWatchlistButton()
    }
  }
}

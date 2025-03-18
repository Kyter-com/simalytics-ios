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
      .foregroundColor(foregroundColor(status))
      .bold()
      .padding(.horizontal, 75)
      .padding(.vertical, 15)
      .background(mapStatusToColor(status))
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

  private func mapStatusToColor(_ status: String?) -> Color {
    switch status {
    case "plantowatch":
      return Color.yellow.opacity(0.1)
    case "dropped":
      return Color.red.opacity(0.1)
    case "completed":
      return Color.green.opacity(0.1)
    default:
      return Color.blue.opacity(0.1)
    }
  }

  private func foregroundColor(_ status: String?) -> Color {
    switch status {
    case "plantowatch":
      return Color.yellow.darker()
    case "dropped":
      return Color.red
    case "completed":
      return Color.green
    default:
      return Color.blue
    }
  }
}

extension Color {
  func darker(by percentage: CGFloat = 30.0) -> Color {
    return self.adjust(by: -1 * abs(percentage))
  }

  func adjust(by percentage: CGFloat = 30.0) -> Color {
    let uiColor = UIColor(self)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    return Color(
      red: min(r + percentage / 100, 1.0),
      green: min(g + percentage / 100, 1.0),
      blue: min(b + percentage / 100, 1.0),
      opacity: Double(a)
    )
  }
}

struct MovieWatchlistMenu_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      MovieWatchlistButton()
    }
  }
}

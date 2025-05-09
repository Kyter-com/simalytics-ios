//
//  ShowWatchlistButton.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/21/25.
//

import SwiftUI

struct ShowWatchlistButton: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @Binding var status: String?
  var simkl_id: Int
  let statusOptions = ["watching", "plantowatch", "completed", "hold", "dropped"]

  var body: some View {
    Menu {
      ForEach(statusOptions, id: \.self) { option in
        Button(action: {
          status = option
        }) {
          Label(mapStatus(option), systemImage: mapStatusToIcon(option))
        }
      }

      if status != nil {
        Divider()
        Button(
          role: .destructive,
          action: {
            status = nil
          }
        ) {
          Label("Remove from List", systemImage: "trash")
        }
      }
    } label: {
      HStack {
        Image(systemName: mapStatusToIcon(status))
        Text(mapStatus(status))
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
      }
      .foregroundColor(foregroundColor(status))
      .bold()
      .padding(.horizontal, 15)
      .padding(.vertical, 15)
      .background(mapStatusToColor(status))
      .cornerRadius(8)
    }
    .onChange(of: status ?? "nil") { _, newValue in
      Task {
        await ShowWatchlistButton.updateShowList(simkl_id, auth.simklAccessToken, newValue)
        await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
      }
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
    case "hold":
      return "pause"
    case "watching":
      return "popcorn"
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
    case "hold":
      return "On Hold"
    case "watching":
      return "Watching"
    default:
      return "Add to List"
    }
  }

  private func mapStatusToColor(_ status: String?) -> Color {
    switch status {
    case "plantowatch":
      return Color.yellow.opacity(0.2)
    case "dropped":
      return Color.red.opacity(0.2)
    case "completed":
      return Color.green.opacity(0.2)
    case "hold":
      return Color.gray.opacity(0.2)
    case "watching":
      return Color.indigo.opacity(0.2)
    default:
      return Color.blue.opacity(0.2)
    }
  }

  private func foregroundColor(_ status: String?) -> Color {
    switch status {
    case "plantowatch":
      return colorScheme == .dark ? Color.yellow : Color.yellow.darker()
    case "dropped":
      return colorScheme == .dark ? Color.red : Color.red.darker()
    case "completed":
      return colorScheme == .dark ? Color.green : Color.green.darker()
    case "hold":
      return colorScheme == .dark ? Color.gray : Color.gray.darker()
    case "watching":
      return colorScheme == .dark ? Color.indigo : Color.indigo.darker()
    default:
      return colorScheme == .dark ? Color.blue : Color.blue.darker()
    }
  }
}

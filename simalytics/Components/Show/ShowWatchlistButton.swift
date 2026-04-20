//
//  ShowWatchlistButton.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/21/25.
//

import SwiftUI

struct ShowWatchlistButton: View {
  @Environment(Auth.self) private var auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @ScaledMetric(relativeTo: .body) private var buttonPadding: CGFloat = 15
  @Binding var status: String?
  var simkl_id: Int
  let statusOptions = ["watching", "plantowatch", "completed", "hold", "dropped"]
  @State private var isRollingBackStatus = false
  @State private var showUpdateErrorAlert = false
  @State private var updateErrorMessage = ""
  @State private var statusUpdateTask: Task<Void, Never>?
  @State private var latestMutationID: UUID?

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
          .font(.body)
        Text(mapStatus(status))
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
      }
      .foregroundStyle(foregroundColor(status))
      .bold()
      .padding(.horizontal, buttonPadding)
      .padding(.vertical, buttonPadding)
      .background(mapStatusToColor(status))
      .clipShape(.rect(cornerRadius: 8))
    }
    .onChange(of: status ?? "nil") { oldValue, newValue in
      if isRollingBackStatus {
        isRollingBackStatus = false
        return
      }

      let previousStatus = oldValue == "nil" ? nil : oldValue
      let mutationID = UUID()
      latestMutationID = mutationID
      statusUpdateTask?.cancel()
      statusUpdateTask = Task {
        if let errorMessage = await ShowWatchlistButton.updateShowList(simkl_id, auth.simklAccessToken, newValue) {
          if Task.isCancelled || latestMutationID != mutationID {
            return
          }
          isRollingBackStatus = true
          status = previousStatus
          updateErrorMessage = errorMessage
          showUpdateErrorAlert = true
          return
        }

        if Task.isCancelled || latestMutationID != mutationID {
          return
        }
        await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
      }
    }
    .onDisappear {
      statusUpdateTask?.cancel()
    }
    .alert("Couldn't update list", isPresented: $showUpdateErrorAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(updateErrorMessage)
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

import SwiftUI

struct StorageRecoveryView: View {
  let failure: StorageFailure
  let retry: () async -> Void
  let reset: () async -> Void
  @State private var confirmingReset = false

  var body: some View {
    ContentUnavailableView {
      Label("Couldn't Open Library", systemImage: "externaldrive.badge.exclamationmark")
    } description: {
      Text(failure.message)
    } actions: {
      Button("Try Again") {
        Task { await retry() }
      }
      .buttonStyle(.borderedProminent)
      // A damaged store fails on every launch; resetting it is the way out.
      // Freeing space is the fix for a full disk, so don't offer it there.
      if failure == .unavailable {
        Button("Reset Library", role: .destructive) {
          confirmingReset = true
        }
      }
    }
    .confirmationDialog(
      "Reset the library on this device?", isPresented: $confirmingReset,
      titleVisibility: .visible
    ) {
      Button("Reset Library", role: .destructive) {
        Task { await reset() }
      }
    } message: {
      Text(
        "Simalytics will delete its saved copy and download your library again from Simkl. Your Simkl lists, ratings, and watch history aren't affected."
      )
    }
  }
}

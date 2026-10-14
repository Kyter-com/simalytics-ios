import SwiftUI

struct StorageRecoveryView: View {
  let failure: StorageFailure
  let retry: () async -> Void

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
    }
  }
}

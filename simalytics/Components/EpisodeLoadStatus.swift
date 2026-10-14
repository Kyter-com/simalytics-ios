import SwiftUI

struct EpisodeLoadStatus: View {
  let isLoading: Bool
  let errorMessage: String?
  let retry: () async -> Void

  var body: some View {
    if isLoading {
      ProgressView("Loading episodes…")
        .frame(maxWidth: .infinity)
        .padding()
    } else if let errorMessage {
      VStack(spacing: 12) {
        Label("Episodes Unavailable", systemImage: "wifi.exclamationmark")
          .font(.headline)
        Text(errorMessage)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Try Again") {
          Task { await retry() }
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .padding()
    }
  }
}

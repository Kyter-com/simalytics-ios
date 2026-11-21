import SwiftData
import SwiftUI

/// A Completed movie's rewatches: log one, see how many, remove the latest.
/// Only shown while Track Rewatches is on for a Simkl PRO / VIP account.
struct MovieRewatchCard: View {
  let simkl: Int
  let title: String?
  /// The movie's list. A rewatch is a second viewing, so only Completed
  /// movies offer one.
  let status: String?
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @AppStorage(RewatchStore.preferenceKey) private var trackRewatches = false
  @State private var isUpdating = false
  @State private var errorMessage: String?
  @State private var confirmingRemoval = false
  private let rewatches = RewatchStore.shared

  private var isShown: Bool {
    trackRewatches && rewatches.isPlanEligible && !auth.simklAccessToken.isEmpty
      && status == "completed" && rewatches.hasCountedMovieRewatches
  }

  private var rewatchIDs: [Int] { rewatches.movieRewatchIDs(simkl: simkl) }

  /// With nothing to show, the card adds no view at all, so the page keeps the
  /// spacing it has without rewatches. An alert keeps it on screen.
  var body: some View {
    if isShown || errorMessage != nil {
      card
    }
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 8) {
      if isShown {
        if !rewatchIDs.isEmpty {
          countRow
        }
        if rewatchIDs.count >= RewatchStore.maxSessionsPerTitle {
          Text(
            "You've reached Simkl's limit of \(RewatchStore.maxSessionsPerTitle) rewatches for this title."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          watchedAgainButton
        }
      }
    }
    .padding(.horizontal)
    .padding(.top, 8)
    .alert(
      "Couldn't Update Rewatch",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "Please try again.")
    }
  }

  private var countRow: some View {
    let layout =
      dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
    return layout {
      Label(
        rewatchIDs.count == 1 ? "Rewatched once" : "Rewatched \(rewatchIDs.count) times",
        systemImage: "arrow.counterclockwise"
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      Button("Remove Latest", role: .destructive) { confirmingRemoval = true }
        .font(.subheadline)
        .frame(minHeight: 44)
        .disabled(isUpdating)
        .accessibilityLabel("Remove latest rewatch")
        // Attached here, so on iPad and iOS 26 the popover points at this button.
        .confirmationDialog(
          "Remove your latest rewatch?", isPresented: $confirmingRemoval,
          titleVisibility: .visible
        ) {
          Button("Remove Rewatch", role: .destructive) { Task { await removeLatest() } }
        } message: {
          Text("Simkl deletes this rewatch. Your first watch stays.")
        }
    }
  }

  @ViewBuilder private var watchedAgainButton: some View {
    if isUpdating {
      ProgressView("Updating rewatches…")
        .frame(maxWidth: .infinity, minHeight: 44)
    } else {
      let button = Button {
        Task { await logRewatch() }
      } label: {
        Label("Watched Again", systemImage: "arrow.counterclockwise")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
      .accessibilityHint("Logs a rewatch of this movie on Simkl.")
      if #available(iOS 26, *) {
        button.buttonStyle(.glass)
      } else {
        button.buttonStyle(.bordered)
      }
    }
  }

  private func logRewatch() async {
    guard !isUpdating, rewatchIDs.count < RewatchStore.maxSessionsPerTitle else { return }
    isUpdating = true
    defer { isUpdating = false }
    let token = auth.simklAccessToken
    switch await RewatchMutation.logMovie(token, simkl: simkl, title: title) {
    case .logged(let rewatchID):
      rewatches.recordMovieRewatch(simkl: simkl, id: rewatchID)
      resync(token)
    case .failed(let message):
      errorMessage = message
    case .cancelled:
      break
    }
  }

  private func removeLatest() async {
    guard !isUpdating, let latest = rewatchIDs.last else { return }
    isUpdating = true
    defer { isUpdating = false }
    let token = auth.simklAccessToken
    switch await RewatchMutation.removeMovieRewatch(token, simkl: simkl, rewatchID: latest) {
    case .removed, .gone:
      // Already deleted, such as on simkl.com, is what the user asked for.
      rewatches.removeMovieRewatch(simkl: simkl, id: latest)
      resync(token)
    case .failed(let message):
      errorMessage = message
    case .cancelled:
      break
    }
  }

  /// Confirms the write and recounts the movie's rewatches.
  private func resync(_ token: String) {
    let container = modelContext.container
    Task { await syncLatestActivities(token, modelContainer: container, forceRefresh: true) }
  }
}

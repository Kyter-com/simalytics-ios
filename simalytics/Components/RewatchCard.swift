import SwiftData
import SwiftUI

/// A title's active rewatch on its detail page, or the button that starts one.
/// Only shown while Track Rewatches is on for a Simkl PRO / VIP account.
struct RewatchCard: View {
  let simkl: Int
  let kind: RewatchKind
  let title: String?
  let poster: String?
  var animeType: String? = nil
  /// The title's list. Starting and stopping stay on Completed titles: SIMKL
  /// auto-fills a show posted without episodes, which for anything unfinished
  /// would mark its remaining episodes watched.
  let status: String?
  let totalEpisodes: Int?
  /// Whether the episode list shows and edits this rewatch or the first watch.
  @Binding var followsRewatch: Bool
  let isEpisodeListBusy: Bool
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var modelContext
  @AppStorage(RewatchStore.preferenceKey) private var trackRewatches = false
  @State private var isUpdating = false
  @State private var errorMessage: String?
  @State private var confirmingStop = false
  private let rewatches = RewatchStore.shared

  private var isTracking: Bool {
    trackRewatches && rewatches.isPlanEligible && !auth.simklAccessToken.isEmpty
  }

  private var session: RewatchSession? {
    isTracking ? rewatches.activeSession(simkl: simkl, kind: kind) : nil
  }

  /// SIMKL asks apps to count a title's sessions before offering another.
  private var isAtSessionLimit: Bool {
    rewatches.sessionCount(simkl: simkl, kind: kind) >= RewatchStore.maxSessionsPerTitle
  }

  var body: some View {
    VStack(spacing: 0) {
      if let session {
        activeCard(session)
      } else if isTracking, status == "completed", rewatches.hasCountedSessions(kind) {
        if isAtSessionLimit {
          Text(
            "You've reached Simkl's limit of \(RewatchStore.maxSessionsPerTitle) rewatches for this title."
          )
          .font(.footnote)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
        } else {
          startButton
        }
      }
    }
    .padding(.horizontal)
    .padding(.top, 8)
    .confirmationDialog(
      "Stop rewatching?", isPresented: $confirmingStop, titleVisibility: .visible
    ) {
      Button("Stop Rewatching", role: .destructive) { Task { await stop() } }
    } message: {
      Text("Simkl keeps the episodes you've rewatched, and you can pick this rewatch back up on simkl.com.")
    }
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

  private func activeCard(_ session: RewatchSession) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Label("Rewatching", systemImage: "arrow.counterclockwise")
          .font(.headline)
        Spacer()
        if let total = session.totalEpisodes, total > 0 {
          Text("\(session.watchedCount) of \(total)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
      }
      if let total = session.totalEpisodes, total > 0 {
        ProgressView(value: Double(min(session.watchedCount, total)), total: Double(total))
          .accessibilityLabel("Rewatch progress")
          .accessibilityValue("\(session.watchedCount) of \(total) episodes")
      }
      if let next = session.next {
        Text("Next: \(nextLabel(next))")
          .font(.subheadline)
          .lineLimit(2)
      }
      Picker("Episode checkmarks", selection: $followsRewatch) {
        Text("This Rewatch").tag(true)
        Text("First Watch").tag(false)
      }
      .pickerStyle(.segmented)
      .disabled(isEpisodeListBusy)
      if isUpdating {
        ProgressView("Updating rewatch…")
          .frame(maxWidth: .infinity, minHeight: 44)
      } else if status == "completed" {
        Button("Stop Rewatching", systemImage: "stop.circle", role: .destructive) {
          confirmingStop = true
        }
        .frame(minHeight: 44)
        .disabled(isEpisodeListBusy)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassBackground(cornerRadius: 12)
  }

  @ViewBuilder private var startButton: some View {
    if isUpdating {
      ProgressView("Starting rewatch…")
        .frame(maxWidth: .infinity, minHeight: 44)
    } else {
      let button = Button {
        Task { await start() }
      } label: {
        Label("Start Rewatch", systemImage: "arrow.counterclockwise")
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
      .disabled(isEpisodeListBusy)
      if #available(iOS 26, *) {
        button.buttonStyle(.glass)
      } else {
        button.buttonStyle(.bordered)
      }
    }
  }

  private func nextLabel(_ next: RewatchNextEpisode) -> String {
    let episode = kind == .tv ? "S\(next.season) · E\(next.episode)" : "Episode \(next.episode)"
    guard let title = next.title, !title.isEmpty else { return episode }
    return "\(episode) · \(title)"
  }

  private func start() async {
    guard !isUpdating, rewatches.hasCountedSessions(kind), !isAtSessionLimit else { return }
    isUpdating = true
    defer { isUpdating = false }
    let token = auth.simklAccessToken
    switch await RewatchMutation.start(token, simkl: simkl, kind: kind, title: title) {
    case .started(let rewatchID):
      rewatches.insert(
        RewatchSession(
          id: rewatchID, simkl: simkl, kind: kind, title: title, poster: poster,
          animeType: animeType, totalEpisodes: totalEpisodes))
      followsRewatch = true
      resync(token)
    case .failed(let message):
      errorMessage = message
    case .cancelled:
      break
    }
  }

  private func stop() async {
    guard !isUpdating, let session else { return }
    isUpdating = true
    defer { isUpdating = false }
    let token = auth.simklAccessToken
    switch await RewatchMutation.stop(token, session) {
    case .succeeded:
      rewatches.removeSession(id: session.id)
      resync(token)
    case .failed(let message):
      errorMessage = message
    case .cancelled:
      break
    }
  }

  /// Fills in the session's episodes and next episode, and Up Next with it.
  private func resync(_ token: String) {
    let container = modelContext.container
    invalidateUpNextCache(modelContainer: container)
    Task { await syncLatestActivities(token, modelContainer: container, forceRefresh: true) }
  }
}

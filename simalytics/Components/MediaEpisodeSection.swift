import SwiftUI

/// A question to ask before an episode change with side effects goes through.
struct EpisodeChangeConfirmation: Equatable {
  let title: String
  let message: String
  let action: String
}

struct MediaEpisodeSection: View {
  @Bindable var model: EpisodeBrowserModel
  let scrollProxy: ScrollViewProxy
  let canEdit: Bool
  /// The checkmarks belong to a rewatch session rather than the first watch.
  var isRewatch = false
  /// Asked before each change (episode, will be watched); a confirmation
  /// holds the change until the user agrees.
  var confirmChange: (EpisodeListItem, Bool) -> EpisodeChangeConfirmation? = { _, _ in nil }
  let mutation: (EpisodeListItem, Bool) async -> SimklMutationResult
  let commit: (EpisodeListItem, Bool) -> Void
  let reconcile: () async -> [WatchlistSeason]?
  @AppStorage("blurEpisodeImages") private var blurImages = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var selectedEpisode: EpisodeListItem?
  @State private var pendingEpisode: EpisodeListItem?
  @State private var confirmingChange: PendingEpisodeChange?

  var body: some View {
    // Keep the episode controls in the content instead of pinning a second bar
    // below the navigation bar while the episodes scroll.
    LazyVStack(spacing: 0) {
      Section {
        ForEach(model.currentGroup?.episodes ?? []) { episode in
          EpisodeBrowserRow(
            episode: episode, isWatched: model.watchedIDs.contains(episode.id),
            blurImages: blurImages, canEdit: canEdit,
            isBusy: pendingEpisode != nil || model.updatingID != nil,
            isUpdating: model.updatingID == episode.id,
            open: { selectedEpisode = episode }, toggle: { queueChange(episode) }
          )
          .id(EpisodeScrollTarget.episode(episode.id))
        }
      } header: {
        EpisodeSectionHeader(
          groups: model.groups, selection: $model.selectedGroup,
          watched: model.watchedCount, total: model.currentGroup?.episodes.count ?? 0,
          progressVerb: isRewatch ? "rewatched" : "watched",
          canJump: model.nextUnwatched != nil, jump: jumpToNext
        )
        .id(EpisodeScrollTarget.header)
      }
    }
    .episodeSwipeContainer()
    .onChange(of: model.selectedGroup) {
      scrollProxy.scrollTo(EpisodeScrollTarget.header, anchor: .top)
    }
    .task(id: pendingEpisode?.id) {
      guard let episode = pendingEpisode else { return }
      await model.toggle(episode, mutation: mutation, commit: commit, reconcile: reconcile)
      pendingEpisode = nil
    }
    .sheet(item: $selectedEpisode) { episode in
      MediaEpisodeDetailSheet(
        episode: episode, isWatched: model.watchedIDs.contains(episode.id),
        blurImages: blurImages, canEdit: canEdit,
        isBusy: pendingEpisode != nil || model.updatingID != nil,
        isUpdating: pendingEpisode?.id == episode.id || model.updatingID == episode.id,
        toggle: { queueChange(episode) }
      )
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
      .episodeErrorAlert(model: model, enabled: true)
      .episodeChangeConfirmation($confirmingChange, enabled: true) { pendingEpisode = $0 }
    }
    .episodeErrorAlert(model: model, enabled: selectedEpisode == nil)
    .episodeChangeConfirmation($confirmingChange, enabled: selectedEpisode == nil) {
      pendingEpisode = $0
    }
  }

  private func queueChange(_ episode: EpisodeListItem) {
    guard canEdit, pendingEpisode == nil, model.updatingID == nil else { return }
    let willWatch = !model.watchedIDs.contains(episode.id)
    if let confirmation = confirmChange(episode, willWatch) {
      confirmingChange = PendingEpisodeChange(episode: episode, confirmation: confirmation)
      return
    }
    pendingEpisode = episode
  }

  private func jumpToNext() {
    guard let episode = model.nextUnwatched else { return }
    withAnimation(reduceMotion ? nil : .snappy) {
      scrollProxy.scrollTo(EpisodeScrollTarget.episode(episode.id), anchor: .center)
    }
  }
}

private struct PendingEpisodeChange {
  let episode: EpisodeListItem
  let confirmation: EpisodeChangeConfirmation
}

extension View {
  /// Shown from the section, or from the episode sheet while it's open.
  fileprivate func episodeChangeConfirmation(
    _ change: Binding<PendingEpisodeChange?>, enabled: Bool,
    confirm: @escaping (EpisodeListItem) -> Void
  ) -> some View {
    confirmationDialog(
      change.wrappedValue?.confirmation.title ?? "",
      isPresented: Binding(
        get: { enabled && change.wrappedValue != nil },
        set: { if !$0 && enabled { change.wrappedValue = nil } }
      ),
      titleVisibility: .visible,
      presenting: change.wrappedValue
    ) { pending in
      Button(pending.confirmation.action, role: .destructive) {
        change.wrappedValue = nil
        confirm(pending.episode)
      }
    } message: { pending in
      Text(pending.confirmation.message)
    }
  }

  fileprivate func episodeErrorAlert(model: EpisodeBrowserModel, enabled: Bool) -> some View {
    alert(
      "Couldn't Update Episode",
      isPresented: Binding(
        get: { enabled && model.errorMessage != nil },
        set: { if !$0 && enabled { model.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "Please try again.")
    }
  }

  @ViewBuilder
  fileprivate func episodeSwipeContainer() -> some View {
    if #available(iOS 27, *) { swipeActionsContainer() } else { self }
  }
}

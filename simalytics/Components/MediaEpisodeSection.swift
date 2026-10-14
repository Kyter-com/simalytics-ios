import SwiftUI

struct MediaEpisodeSection: View {
  @Bindable var model: EpisodeBrowserModel
  let scrollProxy: ScrollViewProxy
  let canEdit: Bool
  let mutation: (EpisodeListItem, Bool) async -> SimklMutationResult
  let commit: (EpisodeListItem, Bool) -> Void
  let reconcile: () async -> [WatchlistSeason]?
  @AppStorage("blurEpisodeImages") private var blurImages = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var selectedEpisode: EpisodeListItem?
  @State private var pendingEpisode: EpisodeListItem?

  var body: some View {
    // Large text needs the whole viewport for rows; let its taller header scroll away.
    LazyVStack(
      spacing: 0, pinnedViews: dynamicTypeSize.isAccessibilitySize ? [] : [.sectionHeaders]
    ) {
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
        toggle: { queueChange(episode) }
      )
      .presentationDetents([.medium, .large])
      .presentationDragIndicator(.visible)
      .episodeErrorAlert(model: model, enabled: true)
    }
    .episodeErrorAlert(model: model, enabled: selectedEpisode == nil)
  }

  private func queueChange(_ episode: EpisodeListItem) {
    guard canEdit, pendingEpisode == nil, model.updatingID == nil else { return }
    pendingEpisode = episode
  }

  private func jumpToNext() {
    guard let episode = model.nextUnwatched else { return }
    withAnimation(reduceMotion ? nil : .snappy) {
      scrollProxy.scrollTo(EpisodeScrollTarget.episode(episode.id), anchor: .center)
    }
  }
}

extension View {
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

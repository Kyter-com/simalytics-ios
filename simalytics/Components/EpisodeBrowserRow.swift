import SwiftUI

struct EpisodeBrowserRow: View {
  let episode: EpisodeListItem
  let isWatched: Bool
  let blurImages: Bool
  let canEdit: Bool
  let isBusy: Bool
  let isUpdating: Bool
  let open: () -> Void
  let toggle: () -> Void

  var body: some View {
    HStack(alignment: .top, spacing: 4) {
      Button(action: open) {
        MediaEpisodeRow(episode: episode, isWatched: isWatched, blurImages: blurImages)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(episode.numberLabel), \(episode.title)")
      .accessibilityValue(isWatched ? "Watched" : "Unwatched")
      .accessibilityHint("Opens the full description and episode actions")
      Button(action: toggle) {
        Label(
          isWatched ? "Mark unwatched" : "Mark watched",
          systemImage: isWatched ? "checkmark.circle.fill" : "circle"
        )
        .labelStyle(.iconOnly)
        .font(.title2)
        .opacity(isUpdating ? 0 : 1)
        .overlay { if isUpdating { ProgressView() } }
        .frame(minWidth: 44, minHeight: 44)
      }
      .buttonStyle(.borderless)
      .tint(isWatched ? .green : .secondary)
      .disabled(!canEdit || isBusy || !episode.canMarkWatched)
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.background)
    .episodeSwipeActions(
      isWatched: isWatched, canEdit: canEdit && episode.canMarkWatched,
      isBusy: isBusy, toggle: toggle
    )
    .contextMenu {
      Button("Episode details", systemImage: "info.circle", action: open)
      if canEdit && episode.canMarkWatched {
        Button(
          isWatched ? "Mark unwatched" : "Mark watched",
          systemImage: isWatched ? "arrow.uturn.backward" : "checkmark", action: toggle
        ).disabled(isBusy)
      }
    }
    .overlay(alignment: .bottom) { Divider().padding(.horizontal) }
  }
}

extension View {
  @ViewBuilder
  fileprivate func episodeSwipeActions(
    isWatched: Bool, canEdit: Bool, isBusy: Bool, toggle: @escaping () -> Void
  ) -> some View {
    if #available(iOS 27, *) {
      swipeActions(edge: .trailing, allowsFullSwipe: true) {
        if canEdit {
          Button(
            isWatched ? "Unwatched" : "Watched",
            systemImage: isWatched ? "arrow.uturn.backward" : "checkmark", action: toggle
          )
          .tint(isWatched ? .orange : .green)
          .disabled(isBusy)
        }
      }
    } else {
      self
    }
  }
}

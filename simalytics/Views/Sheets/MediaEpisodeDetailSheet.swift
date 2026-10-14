import SwiftUI

struct MediaEpisodeDetailSheet: View {
  let episode: EpisodeListItem
  let isWatched: Bool
  let blurImages: Bool
  let canEdit: Bool
  let isBusy: Bool
  let isUpdating: Bool
  let toggle: () -> Void
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
          layout {
            EpisodeThumbnail(
              episode: episode, isWatched: isWatched, blurImages: blurImages, width: 128)
            VStack(alignment: .leading, spacing: 8) {
              Text(episode.title).font(.title3.bold())
              if let date = episode.airDate {
                Text(date, format: .dateTime.month(.wide).day().year())
                  .font(.subheadline).foregroundStyle(.secondary)
              }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          Button(action: toggle) {
            Label(
              isWatched ? "Mark unwatched" : "Mark watched",
              systemImage: isWatched ? "arrow.uturn.backward" : "checkmark"
            )
            .opacity(isUpdating ? 0 : 1)
            .overlay { if isUpdating { ProgressView() } }
            .frame(maxWidth: .infinity, minHeight: 32)
          }
          .buttonStyle(.borderedProminent)
          .disabled(!canEdit || isBusy || !episode.canMarkWatched)
          if !episode.overview.isEmpty {
            Text(episode.overview)
              .font(.body)
              .fixedSize(horizontal: false, vertical: true)
              .textSelection(.enabled)
          }
        }
        .padding()
      }
      .navigationTitle(episode.numberLabel)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}

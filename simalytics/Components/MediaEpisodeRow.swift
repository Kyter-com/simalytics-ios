import SwiftUI

struct MediaEpisodeRow: View {
  let episode: EpisodeListItem
  let isWatched: Bool
  let blurImages: Bool
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    let layout =
      dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
      : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    layout {
      EpisodeThumbnail(episode: episode, isWatched: isWatched, blurImages: blurImages, width: 104)
      VStack(alignment: .leading, spacing: 4) {
        Text(episode.numberLabel)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1, reservesSpace: true)
        Text(episode.title)
          .font(.headline)
          .lineLimit(2, reservesSpace: true)
        Text(episode.preview.isEmpty ? " " : episode.preview)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2, reservesSpace: true)
        Group {
          if let date = episode.airDate {
            Text(date, format: .dateTime.month(.abbreviated).day().year())
          } else {
            Text("Air date unavailable")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1, reservesSpace: true)
      }
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(.rect)
  }
}

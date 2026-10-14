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
      VStack(alignment: .leading, spacing: 3) {
        Text(episode.title)
          .font(.headline)
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
        Text(episode.preview.isEmpty ? " " : episode.preview)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1, reservesSpace: true)
        HStack(spacing: 4) {
          Text(episode.numberLabel)
          if let date = episode.airDate {
            Text("·")
            Text(date, format: .dateTime.month(.abbreviated).day().year())
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

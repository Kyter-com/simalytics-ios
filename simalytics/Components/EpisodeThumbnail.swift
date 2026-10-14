import SwiftUI

struct EpisodeThumbnail: View {
  let episode: EpisodeListItem
  let isWatched: Bool
  let blurImages: Bool
  let width: CGFloat

  var body: some View {
    CustomKFImage(
      imageUrlString: episode.image.map { "\(SIMKL_CDN_URL)/episodes/\($0)_w.jpg" },
      memoryCacheOnly: true, height: width * 9 / 16, width: width
    )
    .frame(width: width, height: width * 9 / 16)
    .blur(radius: blurImages && !isWatched ? 12 : 0)
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityHidden(true)
  }
}

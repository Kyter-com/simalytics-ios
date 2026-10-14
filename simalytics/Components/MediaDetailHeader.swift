import SwiftUI

struct MediaDetailHeader<Info: View>: View {
  let poster: String?
  let title: String
  @ViewBuilder let info: () -> Info
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var showingPoster = false

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 16) {
          posterView
          information
        }
      } else {
        HStack(alignment: .top, spacing: 16) {
          posterView
          information
        }
      }
    }
    .padding(.horizontal)
    .offset(y: -10)
    .background(colorScheme == .dark ? Color.black : Color.white)
    .fullScreenCover(isPresented: $showingPoster) {
      if let poster { FullscreenPosterView(posterPath: poster) }
    }
  }

  private var information: some View {
    VStack(alignment: .leading, spacing: 8, content: info)
      .padding(.top, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder private var posterView: some View {
    if let poster {
      Button {
        showingPoster = true
      } label: {
        posterImage("\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg")
      }
      .buttonStyle(.plain)
      .accessibilityLabel("View \(title) poster")
    } else {
      posterImage(nil)
        .accessibilityLabel("No poster available")
    }
  }

  private func posterImage(_ url: String?) -> some View {
    CustomKFImage(imageUrlString: url, memoryCacheOnly: true, height: 225, width: 150)
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 4)
      }
  }
}

import SwiftUI

struct MediaDetailHeader<Info: View, Status: View>: View {
  let poster: String?
  let title: String
  var posterHeight: CGFloat = 220.59
  @ViewBuilder let info: () -> Info
  @ViewBuilder let status: () -> Status
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var showingPoster = false

  var body: some View {
    Group {
      if dynamicTypeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 16) {
          posterView
          VStack(alignment: .leading, spacing: 8) {
            info().labeledContentStyle(AccessibleMediaInfoStyle())
            status()
          }
        }
      } else {
        // Preserve the original detail layout: natural stack spacing and centered
        // alignment, without stretching the status column to the poster's height.
        HStack {
          posterView
          Spacer()
          VStack {
            Spacer().frame(height: 8)
            Spacer()
            info()
            Spacer()
            status()
            Spacer().frame(height: 2)
          }
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
    CustomKFImage(imageUrlString: url, memoryCacheOnly: true, height: posterHeight, width: 150)
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 4)
      }
  }
}

import SwiftUI

struct MediaDetailHeader<Info: View, Status: View>: View {
  let poster: String?
  let title: String
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
          information
        }
      } else {
        HStack(alignment: .top, spacing: 8) {
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
    VStack(spacing: 8) {
      if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
      if dynamicTypeSize.isAccessibilitySize {
        info().labeledContentStyle(AccessibleMediaInfoStyle())
      } else {
        info()
      }
      if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
      status()
      if !dynamicTypeSize.isAccessibilitySize { Spacer().frame(height: 2) }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? nil : 220.59)
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
    CustomKFImage(imageUrlString: url, memoryCacheOnly: true, height: 220.59, width: 150)
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(colorScheme == .dark ? Color.black : Color.white, lineWidth: 4)
      }
  }
}

//
//  JustWatchProviderSection.swift
//  simalytics
//
import SwiftUI

struct JustWatchProviderSection: View {
  let title: String
  let options: [JustWatchOption]
  let listingURL: URL?

  @Environment(\.openURL) private var openURL

  var body: some View {
    if !options.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.headline)
          .padding(.horizontal)

        ScrollView(.horizontal) {
          HStack(spacing: 16) {
            ForEach(options.indices, id: \.self) { index in
              let option = options[index]

              Button {
                if let listingURL {
                  openURL(listingURL)
                }
              } label: {
                CustomKFImage(
                  imageUrlString: option.logo_path.map { "https://media.themoviedb.org/t/p/original/\($0)" },
                  memoryCacheOnly: false,
                  height: 50,
                  width: 50,
                  contentMode: .fit
                )
                .frame(minWidth: 56, minHeight: 56)
              }
              .buttonStyle(.plain)
              .disabled(listingURL == nil)
              .accessibilityLabel("Open \(option.provider_name ?? "provider") on JustWatch")
              .accessibilityHint("Opens streaming details")
            }
          }
          .padding(.horizontal)
          .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
      }
    }
  }
}

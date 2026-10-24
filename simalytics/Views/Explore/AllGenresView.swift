//
//  AllGenresView.swift
//  simalytics
//

import SwiftUI

/// Every browsable genre as a grid of tiles.
struct AllGenresView: View {
  let groups: [DiscoverGenreGroup]
  let preferredType: DiscoverMediaType?

  @ScaledMetric(relativeTo: .headline) private var tileHeight: CGFloat = 88

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
        ForEach(groups) { group in
          NavigationLink {
            GenreDetailView(group: group, preferredType: preferredType)
          } label: {
            GenreTile(group: group, width: nil, height: tileHeight)
          }
          .buttonStyle(.plain)
        }
      }
      .padding()
    }
    .navigationTitle("Genres")
    .navigationBarTitleDisplayMode(.inline)
  }
}

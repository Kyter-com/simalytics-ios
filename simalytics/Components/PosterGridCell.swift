//
//  PosterGridCell.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/25/26.
//

import SwiftUI

enum ListLayout: String {
  case list, grid
}

struct LayoutToggleButton: View {
  @Binding var layout: ListLayout

  var body: some View {
    Button {
      withAnimation(.snappy(duration: 0.2)) {
        layout = layout == .list ? .grid : .list
      }
    } label: {
      Image(systemName: layout == .list ? "square.grid.2x2" : "list.bullet")
        .contentTransition(.symbolEffect(.replace))
    }
    .accessibilityLabel(layout == .list ? "Switch to grid view" : "Switch to list view")
  }
}

// Cells are 110pt wide so they fit 3-up on the narrowest supported iPhone.
// Adaptive grid with a max keeps them from ballooning on iPad.
let posterGridColumns: [GridItem] = [GridItem(.adaptive(minimum: 110, maximum: 130), spacing: 12)]

struct PosterGridCell: View {
  let title: String
  let poster: String?
  var year: Int? = nil
  var badge: String? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ZStack(alignment: .bottomLeading) {
        CustomKFImage(
          imageUrlString: poster != nil
            ? "\(SIMKL_CDN_URL)/posters/\(poster!)_m.jpg"
            : nil,
          memoryCacheOnly: true,
          height: 165,
          width: 110
        )

        if let year {
          YearOverlayTitle(year: year)
        }

        if let badge {
          Text(badge)
            .font(.caption)
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.7), in: Capsule())
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityLabel("Next episode \(badge)")
        }
      }
      .frame(width: 110, height: 165)

      Text(title)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(2, reservesSpace: true)
        .multilineTextAlignment(.leading)
        .frame(width: 110, alignment: .leading)
    }
    .frame(maxWidth: .infinity)
  }
}

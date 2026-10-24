//
//  ExploreTitles.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/15/25.
//

import SwiftUI

struct ExploreTitle: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.subheadline)
      .padding(.top, 2)
      .lineLimit(2, reservesSpace: true)
      .truncationMode(.tail)
      .multilineTextAlignment(.leading)
      .frame(width: 100, alignment: .leading)
  }
}

struct ExploreGroupTitle: View {
  var title: String

  var body: some View {
    Text(title)
      .font(.title2)
      .bold()
      .padding([.top, .leading])
  }
}

struct YearOverlayTitle: View {
  var year: Int

  var body: some View {
    Text(String(year))
      .font(.caption)
      .bold()
      .padding(.horizontal, 6)
      .padding(.vertical, 4)
      .glassBackground(cornerRadius: 6)
      .padding([.leading, .bottom], 6)
  }
}

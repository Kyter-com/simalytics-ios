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
      .lineLimit(1)
      .truncationMode(.tail)
      .frame(width: 100)
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

struct ExploreGroupHeader<Destination: View>: View {
  let title: String
  let destination: () -> Destination

  var body: some View {
    NavigationLink(destination: destination()) {
      HStack(spacing: 4) {
        Text(title)
          .font(.title2)
          .bold()
        Image(systemName: "chevron.right")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }
      .contentShape(Rectangle())
      .padding([.top, .leading])
    }
    .buttonStyle(.plain)
  }
}

struct YearOverlayTitle: View {
  var year: Int

  var body: some View {
    Text(String(year))
      .font(.caption2)
      .padding(4)
      .background(
        Color(
          UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? .black : .white
          }
        ).opacity(0.8)
      )
      .clipShape(.rect(cornerRadius: 6))
      .padding([.leading, .bottom], 6)
  }
}

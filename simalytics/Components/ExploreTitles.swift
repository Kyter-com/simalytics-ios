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
      .font(.caption)
      .bold()
      .padding(.horizontal, 6)
      .padding(.vertical, 4)
      .background(.regularMaterial)
      .clipShape(.rect(cornerRadius: 6))
      .padding([.leading, .bottom], 6)
  }
}

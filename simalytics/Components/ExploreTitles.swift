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
      .padding(.top, 4)
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

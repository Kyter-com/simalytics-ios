//
//  ListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import SwiftData
import SwiftUI

struct ListView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var moviesPlanToWatch: [SDMoviesPlanToWatch]

  var body: some View {
    List(moviesPlanToWatch) { movie in
      Text(movie.title ?? "")
    }
  }
}

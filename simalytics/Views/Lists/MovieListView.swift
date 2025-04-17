//
//  MovieListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/16/25.
//

import SwiftData
import SwiftUI

struct MovieListView: View {
  var status: String
  @Query private var movies: [V1.SDMovies]

  init(status: String) {
    self.status = status
    let predicate = #Predicate<V1.SDMovies> { movie in
      movie.status == status
    }
    _movies = Query(filter: predicate, sort: \.title)
  }

  var body: some View {
    List(movies, id: \.self) { movie in
      Text(movie.title ?? "Untitled")
    }
    .navigationTitle("Nav Title")
  }
}

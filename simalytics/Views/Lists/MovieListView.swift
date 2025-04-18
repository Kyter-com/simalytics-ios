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
  @State private var searchText: String = ""

  init(status: String) {
    self.status = status
    let predicate = #Predicate<V1.SDMovies> { movie in
      movie.status == status
    }
    _movies = Query(filter: predicate, sort: \.title)
  }

  var filteredMovies: [V1.SDMovies] {
    if searchText.isEmpty {
      return movies
    } else {
      return movies.filter { movie in
        (movie.title ?? "").localizedStandardContains(searchText)
      }
    }
  }

  var body: some View {
    List(filteredMovies, id: \.self) { movie in
      HStack {
        CustomKFImage(
          imageUrlString: movie.poster != nil
            ? "\(SIMKL_CDN_URL)/posters/\(movie.poster!)_m.jpg"
            : NO_IMAGE_URL,
          memoryCacheOnly: true,
          height: 118,
          width: 80
        )

        VStack(alignment: .leading) {
          Text(movie.title ?? "")
            .font(.headline)

          if let year = movie.year {
            Text(String(year))
              .font(.footnote)
              .foregroundColor(.secondary)
          }

        }
      }
    }
    .listStyle(.inset)
    .navigationTitle(
      status == "plantowatch"
        ? "Plan to Watch"
        : status == "completed" ? "Completed" : status == "Dropped" ? "Dropped" : ""
    )
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Sort A-Z") {

          }
          Button("Sort by Year") {

          }
        } label: {
          Label("Sort", systemImage: "arrow.up.arrow.down.circle")
        }
      }
    }
  }
}

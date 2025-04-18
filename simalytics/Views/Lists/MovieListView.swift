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
  @Environment(\.modelContext) private var context
  @State private var movies: [V1.SDMovies] = []
  @State private var searchText: String = ""
  @State private var sortDescriptor: SortDescriptor<V1.SDMovies> = .init(\.title)
  @AppStorage("movieSortField") private var sortField: String = "title"
  @AppStorage("movieSortAscending") private var sortAscending: Bool = true

  private var resolvedSortDescriptor: SortDescriptor<V1.SDMovies> {
    if sortField == "title" {
      return SortDescriptor(\V1.SDMovies.title, order: sortAscending ? .forward : .reverse)
    } else {
      return SortDescriptor(\V1.SDMovies.year, order: sortAscending ? .forward : .reverse)
    }
  }

  private func fetchMovies() {
    let descriptor = FetchDescriptor<V1.SDMovies>(
      predicate: #Predicate { $0.status == status },
      sortBy: [sortDescriptor]
    )
    do {
      movies = try context.fetch(descriptor)
    } catch {
      movies = []
    }
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
    .onAppear {
      sortDescriptor = resolvedSortDescriptor
      fetchMovies()
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
          Menu("Sort by Title") {
            Button("Ascending (A–Z)") {
              sortField = "title"
              sortAscending = true
              sortDescriptor = .init(\.title, order: .forward)
              fetchMovies()
            }
            Button("Descending (Z–A)") {
              sortField = "title"
              sortAscending = false
              sortDescriptor = .init(\.title, order: .reverse)
              fetchMovies()
            }
          }
          Menu("Sort by Year") {
            Button("Ascending (Oldest First)") {
              sortField = "year"
              sortAscending = true
              sortDescriptor = .init(\.year, order: .forward)
              fetchMovies()
            }
            Button("Descending (Newest First)") {
              sortField = "year"
              sortAscending = false
              sortDescriptor = .init(\.year, order: .reverse)
              fetchMovies()
            }
          }
        } label: {
          Label("Sort", systemImage: "arrow.up.arrow.down.circle")
        }
      }
    }
  }
}

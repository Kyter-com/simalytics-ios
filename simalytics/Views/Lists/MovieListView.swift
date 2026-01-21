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

  private static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    return f
  }()

  private var resolvedSortDescriptor: SortDescriptor<V1.SDMovies> {
    if sortField == "title" {
      return SortDescriptor(\V1.SDMovies.title, order: sortAscending ? .forward : .reverse)
    } else if sortField == "added_at" && status != "completed" {
      return SortDescriptor(\V1.SDMovies.added_to_watchlist_at, order: sortAscending ? .forward : .reverse)
    } else if sortField == "added_at" && status == "completed" {
      return SortDescriptor(\V1.SDMovies.last_watched_at, order: sortAscending ? .forward : .reverse)
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
      NavigationLink(destination: MovieDetailView(simkl_id: movie.simkl)) {
        HStack {
          CustomKFImage(
            imageUrlString: movie.poster != nil
              ? "\(SIMKL_CDN_URL)/posters/\(movie.poster!)_m.jpg"
              : nil,
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

            // If the movie is completed, display when it was completed instead of when it was added to list
            if status == "completed" {
              if let isoString = movie.last_watched_at,
                let completedDate = Self.isoFormatter.date(from: isoString)
              {
                Text("Completed: " + completedDate.timeAgoDisplay())
                  .font(.footnote)
                  .foregroundColor(.secondary)
              }
            } else {
              if let isoString = movie.added_to_watchlist_at,
                let addedDate = Self.isoFormatter.date(from: isoString)
              {
                Text("Added: " + addedDate.timeAgoDisplay())
                  .font(.footnote)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }
      .contextMenu {
        if let tmdbId = movie.id_tmdb {
          ShareLink(
            item: URL(string: "https://www.themoviedb.org/movie/\(tmdbId)")!,
            subject: Text(movie.title ?? ""),
            message: Text("Check out \(movie.title ?? "this movie")!")
          ) {
            Label("Share", systemImage: "square.and.arrow.up")
          }
        }
      } preview: {
        PreviewCard(
          title: movie.title ?? "Unknown",
          year: movie.year,
          poster: movie.poster,
          userRating: movie.user_rating,
          status: movie.status,
          mediaType: "movie"
        )
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
          Picker("Sort by", selection: $sortField) {
            Text("Title").tag("title")
            Text("Year").tag("year")
            if status == "completed" {
              Text("Completed").tag("added_at")
            } else {
              Text("Added to List").tag("added_at")
            }
          }

          Picker("Order", selection: $sortAscending) {
            Text("Ascending").tag(true)
            Text("Descending").tag(false)
          }
        } label: {
          Label("Sort", systemImage: "arrow.up.arrow.down.circle")
        }
      }
    }
    .onChange(of: sortField) {
      sortDescriptor = resolvedSortDescriptor
      fetchMovies()
    }
    .onChange(of: sortAscending) {
      sortDescriptor = resolvedSortDescriptor
      fetchMovies()
    }
  }
}

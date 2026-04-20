//
//  TVListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/23/25.
//

import SwiftData
import SwiftUI

struct TVListView: View {
  var status: String
  @Environment(\.modelContext) private var context
  @State private var shows: [V1.SDShows] = []
  @State private var searchText: String = ""
  @State private var sortDescriptor: SortDescriptor<V1.SDShows> = .init(\.title)
  @AppStorage("tvSortField") private var sortField: String = "title"
  @AppStorage("tvSortAscending") private var sortAscending: Bool = true

  private static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    return f
  }()

  private var resolvedSortDescriptor: SortDescriptor<V1.SDShows> {
    if sortField == "title" {
      return SortDescriptor(\V1.SDShows.title, order: sortAscending ? .forward : .reverse)
    } else if sortField == "release_date" && status == "plantowatch" {
      return SortDescriptor(\V1.SDShows.title, order: .forward)
    } else if sortField == "added_at" && status != "completed" {
      return SortDescriptor(\V1.SDShows.added_to_watchlist_at, order: sortAscending ? .forward : .reverse)
    } else if sortField == "added_at" && status == "completed" {
      return SortDescriptor(\V1.SDShows.last_watched_at, order: sortAscending ? .forward : .reverse)
    } else {
      return SortDescriptor(\V1.SDShows.year, order: sortAscending ? .forward : .reverse)
    }
  }

  private func fetchShows() {
    let descriptor = FetchDescriptor<V1.SDShows>(
      predicate: #Predicate { $0.status == status },
      sortBy: [sortDescriptor]
    )
    do {
      shows = try context.fetch(descriptor)
    } catch {
      shows = []
    }
  }

  var filteredShows: [V1.SDShows] {
    if searchText.isEmpty {
      return shows
    } else {
      return shows.filter { show in
        (show.title ?? "").localizedStandardContains(searchText)
      }
    }
  }

  private var sortedShows: [V1.SDShows] {
    let filtered = filteredShows
    guard status == "plantowatch" && sortField == "release_date" else {
      return filtered
    }

    return filtered.sorted { lhs, rhs in
      let lhsReleaseDate = normalizeReleaseDateString(lhs.release_date)
      let rhsReleaseDate = normalizeReleaseDateString(rhs.release_date)
      let lhsSortYear = lhsReleaseDate.flatMap { Int($0.prefix(4)) } ?? lhs.year
      let rhsSortYear = rhsReleaseDate.flatMap { Int($0.prefix(4)) } ?? rhs.year

      switch (lhsSortYear, rhsSortYear) {
      case (let lhsYear?, let rhsYear?) where lhsYear != rhsYear:
        return sortAscending ? lhsYear < rhsYear : lhsYear > rhsYear
      case (nil, _?):
        return false
      case (_?, nil):
        return true
      default:
        break
      }

      if let lhsReleaseDate, let rhsReleaseDate, lhsReleaseDate != rhsReleaseDate {
        return sortAscending ? lhsReleaseDate < rhsReleaseDate : lhsReleaseDate > rhsReleaseDate
      }

      return compareTitle(lhs, rhs)
    }
  }

  private func compareTitle(_ lhs: V1.SDShows, _ rhs: V1.SDShows) -> Bool {
    let lhsTitle = lhs.title ?? ""
    let rhsTitle = rhs.title ?? ""
    let comparison = lhsTitle.localizedCaseInsensitiveCompare(rhsTitle)

    if comparison == .orderedSame {
      return lhs.simkl < rhs.simkl
    }

    if sortAscending {
      return comparison == .orderedAscending
    }

    return comparison == .orderedDescending
  }

  var body: some View {
    List(sortedShows, id: \.self) { show in
      NavigationLink(destination: ShowDetailView(simkl_id: show.simkl)) {
        HStack {
          CustomKFImage(
            imageUrlString: show.poster != nil
              ? "\(SIMKL_CDN_URL)/posters/\(show.poster!)_m.jpg"
              : nil,
            memoryCacheOnly: true,
            height: 118,
            width: 80
          )

          VStack(alignment: .leading) {
            Text(show.title ?? "")
              .font(.headline)

            if let year = show.year {
              Text(String(year))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            // If the show is completed, display when it was completed instead of when it was added to list
            if status == "completed" {
              if let isoString = show.last_watched_at,
                let completedDate = Self.isoFormatter.date(from: isoString)
              {
                Text("Completed: " + completedDate.timeAgoDisplay())
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            } else {
              if let isoString = show.added_to_watchlist_at,
                let addedDate = Self.isoFormatter.date(from: isoString)
              {
                Text("Added: " + addedDate.timeAgoDisplay())
                  .font(.footnote)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }
      .contextMenu {
        if let tmdbId = show.id_tmdb {
          ShareLink(
            item: URL(string: "https://www.themoviedb.org/tv/\(tmdbId)")!,
            subject: Text(show.title ?? ""),
            message: Text("Check out \(show.title ?? "this show")!")
          ) {
            Label("Share", systemImage: "square.and.arrow.up")
          }
        }
      } preview: {
        PreviewCard(
          title: show.title ?? "Unknown",
          year: show.year,
          poster: show.poster,
          userRating: show.user_rating,
          status: show.status,
          mediaType: "tv",
          watchedEpisodes: show.watched_episodes_count,
          totalEpisodes: show.total_episodes_count
        )
      }
    }
    .onAppear {
      sortDescriptor = resolvedSortDescriptor
      fetchShows()
    }
    .listStyle(.inset)
    .navigationTitle(
      status == "plantowatch"
        ? "Plan to Watch"
        : status == "completed"
          ? "Completed"
          : status == "dropped"
            ? "Dropped"
            : status == "hold"
              ? "On Hold"
              : status == "watching"
                ? "Watching"
                : ""
    )
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Picker("Sort by", selection: $sortField) {
            Text("Title").tag("title")
            Text("Year").tag("year")
            if status == "plantowatch" {
              Text("Release Date").tag("release_date")
            }
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
      fetchShows()
    }
    .onChange(of: sortAscending) {
      sortDescriptor = resolvedSortDescriptor
      fetchShows()
    }
  }
}

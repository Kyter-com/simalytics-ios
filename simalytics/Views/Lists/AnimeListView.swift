//
//  AnimeListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/23/25.
//

import SwiftData
import SwiftUI

struct AnimeListView: View {
  var status: String
  @Environment(\.modelContext) private var context
  @State private var animes: [V1.SDAnimes] = []
  @State private var searchText: String = ""
  @State private var sortDescriptor: SortDescriptor<V1.SDAnimes> = .init(\.title)
  @AppStorage("animeSortField") private var sortField: String = "title"
  @AppStorage("animeSortAscending") private var sortAscending: Bool = true

  private static let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    return f
  }()

  private var resolvedSortDescriptor: SortDescriptor<V1.SDAnimes> {
    if sortField == "title" {
      return SortDescriptor(\V1.SDAnimes.title, order: sortAscending ? .forward : .reverse)
    } else if sortField == "added_at" && status != "completed" {
      return SortDescriptor(\V1.SDAnimes.added_to_watchlist_at, order: sortAscending ? .forward : .reverse)
    } else if sortField == "added_at" && status == "completed" {
      return SortDescriptor(\V1.SDAnimes.last_watched_at, order: sortAscending ? .forward : .reverse)
    } else {
      return SortDescriptor(\V1.SDAnimes.year, order: sortAscending ? .forward : .reverse)
    }
  }

  private func fetchAnimes() {
    let descriptor = FetchDescriptor<V1.SDAnimes>(
      predicate: #Predicate { $0.status == status },
      sortBy: [sortDescriptor]
    )
    do {
      animes = try context.fetch(descriptor)
    } catch {
      animes = []
    }
  }

  var filteredAnimes: [V1.SDAnimes] {
    if searchText.isEmpty {
      return animes
    } else {
      return animes.filter { anime in
        (anime.title ?? "").localizedStandardContains(searchText)
      }
    }
  }

  var body: some View {
    List(filteredAnimes, id: \.self) { anime in
      NavigationLink(
        destination: AnimeDetailView(simkl_id: anime.simkl)
      ) {
        HStack {
          CustomKFImage(
            imageUrlString: anime.poster != nil
              ? "\(SIMKL_CDN_URL)/posters/\(anime.poster!)_m.jpg"
              : nil,
            memoryCacheOnly: true,
            height: 118,
            width: 80
          )

          VStack(alignment: .leading) {
            Text(anime.title ?? "")
              .font(.headline)

            if let year = anime.year {
              Text(String(year))
                .font(.footnote)
                .foregroundColor(.secondary)
            }

            // If the anime is completed, display when it was completed instead of when it was added to list
            if status == "completed" {
              if let isoString = anime.last_watched_at,
                let completedDate = Self.isoFormatter.date(from: isoString)
              {
                Text("Completed: " + completedDate.timeAgoDisplay())
                  .font(.footnote)
                  .foregroundColor(.secondary)
              }
            } else {
              if let isoString = anime.added_to_watchlist_at,
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
        if let malId = anime.id_mal {
          ShareLink(
            item: URL(string: "https://myanimelist.net/anime/\(malId)")!,
            subject: Text(anime.title ?? ""),
            message: Text("Check out \(anime.title ?? "this anime")!")
          ) {
            Label("Share", systemImage: "square.and.arrow.up")
          }
        }
      } preview: {
        PreviewCard(
          title: anime.title ?? "Unknown",
          year: anime.year,
          poster: anime.poster,
          userRating: anime.user_rating,
          status: anime.status,
          mediaType: "anime",
          animeType: anime.anime_type,
          watchedEpisodes: anime.watched_episodes_count,
          totalEpisodes: anime.total_episodes_count
        )
      }
    }
    .onAppear {
      sortDescriptor = resolvedSortDescriptor
      fetchAnimes()
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
      fetchAnimes()
    }
    .onChange(of: sortAscending) {
      sortDescriptor = resolvedSortDescriptor
      fetchAnimes()
    }
  }
}

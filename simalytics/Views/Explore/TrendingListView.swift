//
//  TrendingListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/25/26.
//

import SwiftData
import SwiftUI

enum TrendingCategory: String {
  case tv, movies, anime

  var title: String {
    switch self {
    case .tv: return "Trending Shows"
    case .movies: return "Trending Movies"
    case .anime: return "Trending Anime"
    }
  }

  var mediaType: String {
    switch self {
    case .tv: return "tv"
    case .movies: return "movie"
    case .anime: return "anime"
    }
  }

  var shareURLPath: String {
    switch self {
    case .tv: return "tv"
    case .movies: return "movies"
    case .anime: return "anime"
    }
  }
}

struct TrendingListView: View {
  let category: TrendingCategory

  @Environment(\.modelContext) private var context
  @State private var movies: [V1.TrendingMovies] = []
  @State private var shows: [V1.TrendingShows] = []
  @State private var animes: [V1.TrendingAnimes] = []

  private func fetchData() {
    do {
      switch category {
      case .movies:
        movies = try context.fetch(FetchDescriptor<V1.TrendingMovies>(sortBy: [SortDescriptor(\V1.TrendingMovies.order, order: .forward)]))
      case .tv:
        shows = try context.fetch(FetchDescriptor<V1.TrendingShows>(sortBy: [SortDescriptor(\V1.TrendingShows.order, order: .forward)]))
      case .anime:
        animes = try context.fetch(FetchDescriptor<V1.TrendingAnimes>(sortBy: [SortDescriptor(\V1.TrendingAnimes.order, order: .forward)]))
      }
    } catch {
      // Leave empty on failure; grid will just show no items.
    }
  }

  @ViewBuilder
  private func destinationView(simkl: Int) -> some View {
    switch category {
    case .tv: ShowDetailView(simkl_id: simkl)
    case .movies: MovieDetailView(simkl_id: simkl)
    case .anime: AnimeDetailView(simkl_id: simkl)
    }
  }

  @ViewBuilder
  private func shareLink(simkl: Int, title: String) -> some View {
    ShareLink(
      item: URL(string: "https://simkl.com/\(category.shareURLPath)/\(simkl)")!,
      subject: Text(title),
      message: Text("Check out \(title)!")
    ) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }

  @ViewBuilder
  private func previewCard(simkl: Int, title: String, year: Int?, poster: String?) -> some View {
    SmartPreviewCard(
      simklId: simkl,
      title: title,
      year: year,
      poster: poster,
      mediaType: category.mediaType,
      localData: LocalDataLookup.lookup(simklId: simkl, mediaType: category.mediaType, context: context)
    )
  }

  @ViewBuilder
  private func cell(simkl: Int, title: String?, poster: String?, year: Int?) -> some View {
    NavigationLink(destination: destinationView(simkl: simkl)) {
      PosterGridCell(title: title ?? "", poster: poster, year: year)
    }
    .buttonStyle(.plain)
    .contextMenu {
      shareLink(simkl: simkl, title: title ?? "")
    } preview: {
      previewCard(simkl: simkl, title: title ?? "Unknown", year: year, poster: poster)
    }
  }

  var body: some View {
    ScrollView {
      LazyVGrid(columns: posterGridColumns, spacing: 16) {
        switch category {
        case .movies:
          ForEach(movies, id: \.simkl) { item in
            cell(simkl: item.simkl, title: item.title, poster: item.poster, year: item.year)
          }
        case .tv:
          ForEach(shows, id: \.simkl) { item in
            cell(simkl: item.simkl, title: item.title, poster: item.poster, year: item.year)
          }
        case .anime:
          ForEach(animes, id: \.simkl) { item in
            cell(simkl: item.simkl, title: item.title, poster: item.poster, year: item.year)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .navigationTitle(category.title)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { fetchData() }
  }
}

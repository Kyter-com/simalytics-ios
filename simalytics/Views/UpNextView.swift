//
//  UpNextView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftData
import SwiftUI

protocol UpNextMedia {
  var simkl: Int { get }
  var title: String? { get }
  var poster: String? { get }
  var next_to_watch_info_title: String? { get }
  var next_to_watch_info_season: Int? { get }
  var next_to_watch_info_episode: Int? { get }
  var type: String { get }
}

extension V1.SDShows: UpNextMedia {
  var type: String { "tv" }
}
extension V1.SDAnimes: UpNextMedia {
  var type: String { "anime" }
  var next_to_watch_info_season: Int? { nil }
}

struct UpNextView: View {
  @Environment(Auth.self) private var auth
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage("upNextLayout") private var layout: ListLayout = .list
  @State private var searchText: String = ""
  @Environment(\.modelContext) private var context
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator

  private func nextEpisodeBadge(for media: any UpNextMedia) -> String? {
    var parts: [String] = []
    if let season = media.next_to_watch_info_season {
      parts.append("S\(season)")
    }
    if let episode = media.next_to_watch_info_episode {
      parts.append("E\(episode)")
    }
    return parts.isEmpty ? nil : parts.joined(separator: "·")
  }

  private func markWatched(_ mediaItem: any UpNextMedia) {
    Task {
      let isAnime = mediaItem.type == "anime"
      guard
        let episodeSelection = validatedSimklEpisode(
          season: mediaItem.next_to_watch_info_season,
          episode: mediaItem.next_to_watch_info_episode,
          fallbackSeason: isAnime ? 1 : nil
        )
      else { return }

      invalidateUpNextCache(modelContainer: context.container)

      if isAnime {
        await AnimeDetailView.markEpisodeWatched(
          auth.simklAccessToken,
          mediaItem.title ?? "",
          mediaItem.simkl,
          episodeSelection.season,
          episodeSelection.episode
        )
      } else {
        await ShowDetailView.markEpisodeWatched(
          auth.simklAccessToken,
          mediaItem.title ?? "",
          mediaItem.simkl,
          episodeSelection.season,
          episodeSelection.episode
        )
      }
      await syncLatestActivities(
        auth.simklAccessToken,
        modelContainer: context.container,
        forceRefresh: true
      )
    }
  }

  @ViewBuilder
  private func contextMenu(for mediaItem: any UpNextMedia) -> some View {
    ShareLink(
      item: URL(string: "https://simkl.com/\(mediaItem.type)/\(mediaItem.simkl)")!,
      subject: Text(mediaItem.title ?? ""),
      message: Text("Check out \(mediaItem.title ?? "this")!")
    ) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }

  @Query(
    filter: #Predicate<V1.SDShows> {
      (($0.next_to_watch_info_title ?? "") != "") && (($0.status ?? "") == "watching")
    }) private var shows: [V1.SDShows]

  @Query(
    filter: #Predicate<V1.SDAnimes> {
      (($0.next_to_watch_info_title ?? "") != "") && (($0.status ?? "") == "watching") && (($0.anime_type ?? "") == "tv")
    }
  ) private var animes: [V1.SDAnimes]

  var filteredMedia: [any UpNextMedia] {
    let allMedia: [any UpNextMedia] = hideAnime ? Array(shows) : shows + animes
    if searchText.isEmpty {
      return allMedia
    } else {
      return allMedia.filter { media in
        media.title?.localizedStandardContains(searchText) ?? false
          || (media.next_to_watch_info_title?.localizedStandardContains(searchText) ?? false)
      }
    }
  }

  var body: some View {
    NavigationStack {
      if auth.simklAccessToken.isEmpty {
        ContentUnavailableView {
          Label("Sign in to Simkl", systemImage: "lock.shield")
        } description: {
          Text("Sign in to Simkl to view your Up Next items.")
        }
      } else {
        Group {
          if filteredMedia.isEmpty {
            ContentUnavailableView {
              Label(searchText.isEmpty ? "Nothing Up Next" : "No Results", systemImage: searchText.isEmpty ? "play.tv" : "magnifyingglass")
            } description: {
              Text(searchText.isEmpty ? "Episodes you are currently watching will appear here." : "Try searching for another show or episode.")
            }
          } else if layout == .grid {
            ScrollView {
              LazyVGrid(columns: posterGridColumns, spacing: 16) {
                ForEach(filteredMedia, id: \.simkl) { mediaItem in
                  NavigationLink(destination: destinationView(for: mediaItem)) {
                    PosterGridCell(
                      title: mediaItem.title ?? "",
                      poster: mediaItem.poster,
                      badge: nextEpisodeBadge(for: mediaItem)
                    )
                  }
                  .buttonStyle(.plain)
                  .contextMenu {
                    contextMenu(for: mediaItem)
                  } preview: {
                    UpNextPreviewCard(mediaItem: mediaItem)
                  }
                }
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
            }
          } else {
            List(filteredMedia, id: \.simkl) { mediaItem in
              NavigationLink(destination: destinationView(for: mediaItem)) {
                HStack {
                  if let poster = mediaItem.poster {
                    CustomKFImage(
                      imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
                      memoryCacheOnly: false,
                      height: 118,
                      width: 80
                    )
                  }

                  VStack(alignment: .leading) {
                    if let title = mediaItem.title {
                      Text(title)
                        .font(.headline)
                        .padding(.top, 8)
                    }
                    if let title = mediaItem.next_to_watch_info_title {
                      Text(title)
                        .font(.subheadline)
                    }
                    Spacer()
                    if let season = mediaItem.next_to_watch_info_season {
                      Text("Season \(season)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    if let episode = mediaItem.next_to_watch_info_episode {
                      Text("Episode \(episode)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                  }
                }
                // No optimistic clear here: the user is looking at this row,
                // so nulling next_to_watch_info_title would drop it from the
                // @Query and the sync upsert would slide it back in — a
                // disappear/reappear flicker. Leaving the row in place lets
                // SwiftData update the episode text in-place (S7E1 → S7E2).
                .swipeActions(edge: .trailing) {
                  Button {
                    markWatched(mediaItem)
                  } label: {
                    Label("Watched", systemImage: "checkmark.circle")
                  }
                  .tint(.green)
                }
              }
              .contextMenu {
                contextMenu(for: mediaItem)
              } preview: {
                UpNextPreviewCard(mediaItem: mediaItem)
              }
            }
            .listStyle(.inset)
          }
        }
        .searchable(text: $searchText, placement: .automatic)
        .navigationTitle("Up Next")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            LayoutToggleButton(layout: $layout)
          }
          ToolbarItem(placement: .topBarTrailing) {
            if globalLoadingIndicator.isSyncing {
              ProgressView()
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func destinationView(for mediaItem: any UpNextMedia) -> some View {
    switch mediaItem.type {
    case "tv":
      ShowDetailView(simkl_id: mediaItem.simkl)
    case "anime":
      AnimeDetailView(simkl_id: mediaItem.simkl)
    default:
      ShowDetailView(simkl_id: mediaItem.simkl)
    }
  }
}

// TODO: https://www.shutterstock.com/image-vector/s-letter-media-play-button-logo-1994243441
// TODO: https://www.logoground.com/logo.php?id=1027401

struct UpNextPreviewCard: View {
  let mediaItem: any UpNextMedia

  private var posterURL: String? {
    guard let poster = mediaItem.poster else { return nil }
    return "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg"
  }

  private var nextEpisodeText: String? {
    var parts: [String] = []
    if let season = mediaItem.next_to_watch_info_season {
      parts.append("S\(season)")
    }
    if let episode = mediaItem.next_to_watch_info_episode {
      parts.append("E\(episode)")
    }
    return parts.isEmpty ? nil : parts.joined(separator: " ")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      CustomKFImage(
        imageUrlString: posterURL,
        memoryCacheOnly: true,
        height: 225,
        width: 150
      )

      VStack(alignment: .leading, spacing: 8) {
        Text(mediaItem.title ?? "Unknown")
          .font(.title2)
          .fontWeight(.bold)
          .lineLimit(3)

        HStack(spacing: 4) {
          Image(systemName: mediaItem.type == "anime" ? "sparkles.tv" : "tv")
          Text(mediaItem.type == "anime" ? "Anime" : "TV Show")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        if let episodeTitle = mediaItem.next_to_watch_info_title {
          Text(episodeTitle)
            .font(.subheadline)
            .lineLimit(2)
        }

        if let nextEp = nextEpisodeText {
          HStack(spacing: 4) {
            Image(systemName: "play.circle")
              .foregroundStyle(.blue)
            Text("Next: \(nextEp)")
          }
          .font(.subheadline)
          .foregroundStyle(.secondary)
        }

        Text("Watching")
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.2))
          .clipShape(Capsule())

        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
    .padding(16)
    .frame(width: 350, height: 260)
    .background(Color(.systemBackground))
  }
}

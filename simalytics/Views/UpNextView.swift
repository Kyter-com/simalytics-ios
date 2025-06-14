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
  @EnvironmentObject private var auth: Auth
  @State private var searchText: String = ""
  @Environment(\.modelContext) private var context
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator

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
    let allMedia: [any UpNextMedia] = shows + animes
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
                    .foregroundColor(.secondary)
                }
                if let episode = mediaItem.next_to_watch_info_episode {
                  Text("Episode \(episode)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                Spacer()
              }
            }
            .swipeActions(edge: .trailing) {
              Button {
                Task {
                  await ShowDetailView.markEpisodeWatched(
                    auth.simklAccessToken,
                    mediaItem.title ?? "",
                    mediaItem.simkl,
                    mediaItem.next_to_watch_info_season ?? 0,
                    mediaItem.next_to_watch_info_episode ?? 0,
                  )
                  await syncLatestActivities(auth.simklAccessToken, modelContainer: context.container)
                }
              } label: {
                Label("Watched", systemImage: "checkmark.circle")
              }
              .tint(.green)
            }
          }
        }
        .listStyle(.inset)
        .searchable(text: $searchText, placement: .automatic)
        .navigationTitle("Up Next")
        .toolbar {
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
      AnimeDetailView(simkl_id: mediaItem.simkl)  // Replace with your actual anime detail view
    default:
      ShowDetailView(simkl_id: mediaItem.simkl)
    }
  }
}

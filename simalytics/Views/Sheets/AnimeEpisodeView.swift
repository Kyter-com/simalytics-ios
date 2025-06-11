//
//  AnimeEpisodeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 6/5/25.
//

import SwiftUI

struct AnimeEpisodeView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) var colorScheme
  @EnvironmentObject private var auth: Auth
  @Binding var episode: AnimeEpisodeModel?
  @Binding var animeEpisodes: [AnimeEpisodeModel]
  @Binding var animeWatchlist: AnimeWatchlistModel?
  @Binding var animeDetails: AnimeDetailsModel?
  var simklId: Int

  var body: some View {
    let hasWatched = hasWatchedEpisode(season: episode?.season ?? -1, episode: episode?.episode ?? -1)
    VStack {
      HStack {
        CustomKFImage(
          imageUrlString: episode?.img != nil ? "\(SIMKL_CDN_URL)/episodes/\(episode?.img! ?? "")_w.jpg" : NO_IMAGE_URL,
          memoryCacheOnly: true,
          height: 70.42,
          width: 125
        )

        Text(episode?.title ?? "Title Unavailable")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack {
        Text("S\(episode?.season ?? 0) E\(episode?.episode ?? 0)")
          .font(.caption)
          .bold()
        Text(episode?.date?.formattedEpisodeDate() ?? "")
          .font(.caption)
        Spacer()
      }
      .padding([.top, .bottom], 2)

      Button(action: {
        Task {
          if !hasWatched {
            await AnimeDetailView.markEpisodeWatched(
              auth.simklAccessToken,
              animeDetails?.title ?? "",
              simklId,
              episode?.season ?? 0,
              episode?.episode ?? 0
            )
            if let episode = episode {
              if let index = animeWatchlist?.seasons?.firstIndex(where: { $0.number == episode.season }) {
                if let episodeIndex = animeWatchlist?.seasons?[index].episodes?.firstIndex(where: { $0.number == episode.episode }) {
                  animeWatchlist?.seasons?[index].episodes?[episodeIndex].watched = true
                }
              }
            }
          } else {
            await AnimeDetailView.markEpisodeUnwatched(
              auth.simklAccessToken,
              animeDetails?.title ?? "",
              simklId,
              episode?.season ?? 0,
              episode?.episode ?? 0
            )
            if let episode = episode {
              if let index = animeWatchlist?.seasons?.firstIndex(where: { $0.number == episode.season }) {
                if let episodeIndex = animeWatchlist?.seasons?[index].episodes?.firstIndex(where: { $0.number == episode.episode }) {
                  animeWatchlist?.seasons?[index].episodes?[episodeIndex].watched = false
                }
              }
            }
          }
        }
      }) {
        Text(hasWatched ? "Watched" : "Watch")
          .frame(maxWidth: .infinity)
          .padding()
          .bold()
          .background(hasWatched ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
          .foregroundColor(
            hasWatched ? colorScheme == .dark ? Color.green : Color.green.darker() : colorScheme == .dark ? Color.gray : Color.gray.darker()
          )
          .cornerRadius(8)
      }

      if let description = episode?.description {
        Text(description)
          .font(.footnote)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding([.top], 6)
      }
    }
    .padding([.leading, .trailing, .top])
    Spacer()
  }

  func hasWatchedEpisode(season targetSeason: Int, episode targetEpisode: Int) -> Bool {
    guard let seasons = animeWatchlist?.seasons else { return false }
    for season in seasons {
      guard let episodes = season.episodes else { continue }
      if episodes.contains(where: {
        $0.number == targetEpisode && season.number == targetSeason && $0.watched == true
      }) {
        return true
      }
    }
    return false
  }
}

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
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var context
  @Binding var episode: AnimeEpisodeModel?
  @Binding var animeEpisodes: [AnimeEpisodeModel]
  @Binding var animeWatchlist: AnimeWatchlistModel?
  @Binding var animeDetails: AnimeDetailsModel?
  var simklId: Int

  var body: some View {
    let hasWatched = hasWatchedEpisode(season: episode?.type == "special" ? 0 : 1, episode: episode?.episode ?? -1)
    VStack {
      HStack {
        CustomKFImage(
          imageUrlString: episode?.img != nil ? "\(SIMKL_CDN_URL)/episodes/\(episode?.img! ?? "")_w.jpg" : nil,
          memoryCacheOnly: true,
          height: 70.42,
          width: 125
        )

        Text(episode?.title ?? "Title Unavailable")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if episode?.episode != nil && episode?.season != nil && episode?.season != 0 {
        HStack {
          Text("E\(episode?.episode ?? 0)")
            .font(.caption)
            .bold()
          Text(episode?.date?.formattedEpisodeDate() ?? "")
            .font(.caption)
          Spacer()
        }
        .padding([.top, .bottom], 2)
      }

      if episode?.episode != nil && episode?.season != nil && episode?.season != 0 {
        Button(action: {
          Task {
            guard let ep = episode, let epNum = ep.episode else { return }
            let seasonNum = ep.type == "special" ? 0 : 1
            let willMarkWatched = !hasWatched

            applyOptimisticAnimeWatchlistUpdate(
              season: seasonNum, episode: epNum, watched: willMarkWatched)

            if willMarkWatched {
              optimisticallyClearNextToWatch(
                simklId: simklId, season: seasonNum, episode: epNum,
                kind: .anime, modelContainer: context.container)
            }
            invalidateUpNextCache(modelContainer: context.container)

            let errorMessage: String?
            if willMarkWatched {
              errorMessage = await AnimeDetailView.markEpisodeWatched(
                auth.simklAccessToken,
                animeDetails?.title ?? "",
                simklId,
                seasonNum,
                epNum
              )
            } else {
              errorMessage = await AnimeDetailView.markEpisodeUnwatched(
                auth.simklAccessToken,
                animeDetails?.title ?? "",
                simklId,
                seasonNum,
                epNum
              )
            }

            if errorMessage != nil {
              applyOptimisticAnimeWatchlistUpdate(
                season: seasonNum, episode: epNum, watched: !willMarkWatched)
            }

            await syncLatestActivities(
              auth.simklAccessToken,
              modelContainer: context.container,
              forceRefresh: true
            )

            if let refreshed = await AnimeDetailView.getAnimeWatchlist(simklId, auth.simklAccessToken) {
              animeWatchlist = refreshed
            }
          }
        }) {
          Text(hasWatched ? "Watched" : "Watch")
            .frame(maxWidth: .infinity)
            .padding()
            .bold()
            .background(hasWatched ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
            .foregroundStyle(
              hasWatched ? colorScheme == .dark ? Color.green : Color.green.darker() : colorScheme == .dark ? Color.gray : Color.gray.darker()
            )
            .clipShape(.rect(cornerRadius: 8))
        }
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

  func applyOptimisticAnimeWatchlistUpdate(season targetSeason: Int, episode targetEpisode: Int, watched: Bool) {
    guard animeWatchlist != nil else { return }
    var working = animeWatchlist!
    var seasons = working.seasons ?? []

    if let seasonIdx = seasons.firstIndex(where: { $0.number == targetSeason }) {
      var season = seasons[seasonIdx]
      var episodes = season.episodes ?? []
      if let epIdx = episodes.firstIndex(where: { $0.number == targetEpisode }) {
        episodes[epIdx].watched = watched
      } else {
        episodes.append(
          WatchlistEpisode(number: targetEpisode, watched: watched, aired: true, last_watched_at: nil)
        )
      }
      season.episodes = episodes
      seasons[seasonIdx] = season
    } else {
      let newEpisode = WatchlistEpisode(
        number: targetEpisode, watched: watched, aired: true, last_watched_at: nil)
      let newSeason = WatchlistSeason(
        number: targetSeason, episodes_total: nil, episodes_aired: nil,
        episodes_to_be_aired: nil, episodes_watched: nil, episodes: [newEpisode])
      seasons.append(newSeason)
    }

    working.seasons = seasons
    animeWatchlist = working
  }
}

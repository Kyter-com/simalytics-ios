//
//  ShowEpisodeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 6/5/25.
//

import SwiftUI

struct ShowEpisodeView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.colorScheme) var colorScheme
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var context
  @Binding var episode: ShowEpisodeModel?
  @Binding var showEpisodes: [ShowEpisodeModel]
  @Binding var showWatchlist: ShowWatchlistModel?
  @Binding var showDetails: ShowDetailsModel?
  var simklId: Int
  @State private var mutationCoordinator = EpisodeMutationCoordinator()
  @State private var mutationTask: Task<Void, Never>?

  var body: some View {
    let hasWatched = hasWatchedEpisode(
      season: episode?.season ?? -1, episode: episode?.episode ?? -1)
    VStack {
      HStack {
        CustomKFImage(
          imageUrlString: episode?.img != nil
            ? "\(SIMKL_CDN_URL)/episodes/\(episode?.img! ?? "")_w.jpg" : nil,
          memoryCacheOnly: true,
          height: 70.42,
          width: 125
        )

        Text(episode?.title ?? "Title Unavailable")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if episode?.episode != nil && episode?.season != nil {
        HStack {
          Text("S\(episode?.season ?? 0) E\(episode?.episode ?? 0)")
            .font(.caption)
            .bold()
          Text(episode?.date?.formattedEpisodeDate() ?? "")
            .font(.caption)
          Spacer()
        }
        .padding([.top, .bottom], 2)
      }

      if episode?.episode != nil && episode?.season != nil {
        Button {
          startMutation(hasWatched: hasWatched)
        } label: {
          Group {
            if mutationCoordinator.isUpdating {
              ProgressView()
                .accessibilityLabel("Updating episode")
            } else {
              Text(hasWatched ? "Watched" : "Watch")
            }
          }
          .frame(maxWidth: .infinity)
          .padding()
          .bold()
          .background(hasWatched ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
          .foregroundStyle(
            hasWatched
              ? colorScheme == .dark ? Color.green : Color.green.darker()
              : colorScheme == .dark ? Color.gray : Color.gray.darker()
          )
          .clipShape(.rect(cornerRadius: 8))
        }
        .disabled(mutationCoordinator.isUpdating)
      }

      if let description = episode?.description {
        Text(description)
          .font(.footnote)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding([.top], 6)
      }
    }
    .padding([.leading, .trailing, .top])
    .onDisappear {
      mutationTask?.cancel()
    }
    Spacer()
  }

  private func startMutation(hasWatched: Bool) {
    guard mutationTask == nil,
      let ep = episode,
      let selection = validatedSimklEpisode(season: ep.season, episode: ep.episode)
    else { return }

    let originalWatchlist = showWatchlist
    let willMarkWatched = !hasWatched
    let accessToken = auth.simklAccessToken
    let title = showDetails?.title ?? ""
    let modelContainer = context.container

    mutationTask = Task { @MainActor in
      _ = await mutationCoordinator.run(
        optimisticUpdate: {
          applyOptimisticWatchlistUpdate(
            season: selection.season,
            episode: selection.episode,
            watched: willMarkWatched
          )
          invalidateUpNextCache(modelContainer: modelContainer)
        },
        rollback: {
          showWatchlist = originalWatchlist
        },
        mutation: {
          if willMarkWatched {
            await ShowDetailView.markEpisodeWatched(
              accessToken, title, simklId, selection.season, selection.episode)
          } else {
            await ShowDetailView.markEpisodeUnwatched(
              accessToken, title, simklId, selection.season, selection.episode)
          }
        },
        commit: {
          if willMarkWatched {
            optimisticallyClearNextToWatch(
              simklId: simklId,
              season: selection.season,
              episode: selection.episode,
              kind: .tv,
              modelContainer: modelContainer
            )
          }
        },
        reconcile: {
          await syncLatestActivities(
            accessToken,
            modelContainer: modelContainer,
            forceRefresh: true
          )
          guard !Task.isCancelled else { return }
          if let refreshed = await ShowDetailView.getShowWatchlist(simklId, accessToken),
            !Task.isCancelled
          {
            showWatchlist = refreshed
          }
        }
      )
      mutationTask = nil
    }
  }

  func hasWatchedEpisode(season targetSeason: Int, episode targetEpisode: Int) -> Bool {
    guard let seasons = showWatchlist?.seasons else { return false }
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

  // Updates showWatchlist in place. Synthesizes the season / episode entry
  // if it isn't already in the /sync/watched response (which happens on a
  // show with no prior watched episodes — the original code silently no-op'd).
  func applyOptimisticWatchlistUpdate(
    season targetSeason: Int, episode targetEpisode: Int, watched: Bool
  ) {
    guard showWatchlist != nil else { return }
    var working = showWatchlist!
    var seasons = working.seasons ?? []

    if let seasonIdx = seasons.firstIndex(where: { $0.number == targetSeason }) {
      var season = seasons[seasonIdx]
      var episodes = season.episodes ?? []
      if let epIdx = episodes.firstIndex(where: { $0.number == targetEpisode }) {
        episodes[epIdx].watched = watched
      } else {
        episodes.append(
          WatchlistEpisode(
            number: targetEpisode, watched: watched, aired: true, last_watched_at: nil)
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
    showWatchlist = working
  }
}

//
//  ShowDetailSeasonTests.swift
//  simalyticsTests
//
//  Tests for the default season selection in ShowDetailView: the episode
//  list opens on the first season with an unwatched episode so returning
//  viewers land where they left off.
//

import Testing

@testable import Simalytics

@Suite("ShowDetailSeason")
struct ShowDetailSeasonTests {

  // MARK: - Helpers

  private func episode(season: Int?, number: Int?, type: String? = nil) -> ShowEpisodeModel {
    ShowEpisodeModel(
      title: "Episode",
      description: nil,
      season: season,
      episode: number,
      type: type,
      date: nil,
      img: nil,
      aired: true,
      ids: ShowEpisodeModelIds(simkl_id: (season ?? 0) * 100 + (number ?? 0))
    )
  }

  private func seasonEpisodes(_ season: Int, count: Int) -> [ShowEpisodeModel] {
    (1...count).map { episode(season: season, number: $0) }
  }

  private func watchedSeason(_ season: Int, watchedEpisodes: [Int]) -> WatchlistSeason {
    WatchlistSeason(
      number: season,
      episodes_total: nil,
      episodes_aired: nil,
      episodes_to_be_aired: nil,
      episodes_watched: watchedEpisodes.count,
      episodes: watchedEpisodes.map {
        WatchlistEpisode(number: $0, watched: true, aired: true, last_watched_at: nil)
      }
    )
  }

  private func watchlist(seasons: [WatchlistSeason]?) -> ShowWatchlistModel {
    ShowWatchlistModel(
      list: "watching",
      last_watched_at: nil,
      simkl: 1,
      episodes_watched: nil,
      episodes_aired: nil,
      seasons: seasons
    )
  }

  // MARK: - defaultSeason

  @Test("Opens on season 1 when signed out")
  func signedOutOpensFirstSeason() {
    let episodes = seasonEpisodes(1, count: 3) + seasonEpisodes(2, count: 3)
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: nil) == 1)
  }

  @Test("Skips fully watched season 1")
  func skipsFullyWatchedFirstSeason() {
    let episodes = seasonEpisodes(1, count: 2) + seasonEpisodes(2, count: 2)
    let list = watchlist(seasons: [watchedSeason(1, watchedEpisodes: [1, 2])])
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: list) == 2)
  }

  @Test("Opens on season 3 when seasons 1 and 2 are fully watched")
  func opensOnFirstPartiallyWatchedSeason() {
    let episodes =
      seasonEpisodes(1, count: 2) + seasonEpisodes(2, count: 2) + seasonEpisodes(3, count: 2)
    let list = watchlist(seasons: [
      watchedSeason(1, watchedEpisodes: [1, 2]),
      watchedSeason(2, watchedEpisodes: [1, 2]),
      watchedSeason(3, watchedEpisodes: [1]),
    ])
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: list) == 3)
  }

  @Test("Falls back to the last season when everything is watched")
  func allWatchedFallsBackToLastSeason() {
    let episodes = seasonEpisodes(1, count: 2) + seasonEpisodes(2, count: 2)
    let list = watchlist(seasons: [
      watchedSeason(1, watchedEpisodes: [1, 2]),
      watchedSeason(2, watchedEpisodes: [1, 2]),
    ])
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: list) == 2)
  }

  @Test("Returns nil when there are no numbered seasons")
  func specialsOnlyReturnsNil() {
    let episodes = [
      episode(season: 0, number: 1, type: "special"),
      episode(season: nil, number: nil, type: "special"),
    ]
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: nil) == nil)
  }

  @Test("Season 0 is excluded from resume selection")
  func seasonZeroExcluded() {
    let episodes = [episode(season: 0, number: 1)] + seasonEpisodes(1, count: 2)
    let list = watchlist(seasons: [watchedSeason(1, watchedEpisodes: [1, 2])])
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: list) == 1)
  }

  @Test("Watchlist without seasons data opens on the first season")
  func emptyWatchlistOpensFirstSeason() {
    let episodes = seasonEpisodes(1, count: 2) + seasonEpisodes(2, count: 2)
    #expect(
      ShowDetailView.defaultSeason(episodes: episodes, watchlist: watchlist(seasons: nil)) == 1)
  }

  @Test("Scans seasons in ascending order across gaps")
  func scansAscendingAcrossGaps() {
    let episodes = seasonEpisodes(3, count: 1) + seasonEpisodes(1, count: 1)
    let list = watchlist(seasons: [watchedSeason(1, watchedEpisodes: [1])])
    #expect(ShowDetailView.defaultSeason(episodes: episodes, watchlist: list) == 3)
  }

  // MARK: - isEpisodeWatched

  @Test("Matches the row checkmark semantics")
  func watchedMatching() {
    let list = watchlist(seasons: [watchedSeason(2, watchedEpisodes: [4])])
    #expect(ShowDetailView.isEpisodeWatched(list, season: 2, episode: 4) == true)
    #expect(ShowDetailView.isEpisodeWatched(list, season: 2, episode: 5) == false)
    #expect(ShowDetailView.isEpisodeWatched(list, season: 1, episode: 4) == false)
    #expect(ShowDetailView.isEpisodeWatched(nil, season: 2, episode: 4) == false)
  }
}

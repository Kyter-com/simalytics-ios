//
//  AnimeDetailSeasonTests.swift
//  simalyticsTests
//
//  Tests for the default season selection in AnimeDetailView: the episode
//  list follows the highest watched group without revisiting older gaps.
//  Anime seasons are synthetic display
//  groups (episode / 100 + 1) while the watchlist tracks episodes flat.
//

import Testing

@testable import Simalytics

@Suite("AnimeDetailSeason")
struct AnimeDetailSeasonTests {

  // MARK: - Helpers

  private func episode(season: Int?, number: Int?, type: String? = nil) -> AnimeEpisodeModel {
    AnimeEpisodeModel(
      title: "Episode",
      description: nil,
      episode: number,
      type: type,
      aired: true,
      img: nil,
      date: nil,
      season: season,
      ids: AnimeEpisodeModelIds(simkl_id: (season ?? 0) * 100 + (number ?? 0))
    )
  }

  private func watchlist(seasons: [WatchlistSeason]?) -> AnimeWatchlistModel {
    AnimeWatchlistModel(
      list: "watching",
      last_watched_at: nil,
      simkl: 1,
      episodes_watched: nil,
      episodes_aired: nil,
      seasons: seasons
    )
  }

  private func watchedFlat(_ episodes: [Int], seasonNumber: Int = 1) -> WatchlistSeason {
    WatchlistSeason(
      number: seasonNumber,
      episodes_total: nil,
      episodes_aired: nil,
      episodes_to_be_aired: nil,
      episodes_watched: episodes.count,
      episodes: episodes.map {
        WatchlistEpisode(number: $0, watched: true, aired: true, last_watched_at: nil)
      }
    )
  }

  // MARK: - defaultSeason

  @Test("Opens on season 1 when signed out")
  func signedOutOpensFirstSeason() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 1, number: 2),
      episode(season: 2, number: 100),
    ]
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: nil) == 1)
  }

  @Test("Skips fully watched season 1 using flat watchlist numbering")
  func skipsFullyWatchedFirstSeason() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 1, number: 2),
      episode(season: 2, number: 100), episode(season: 2, number: 101),
    ]
    let list = watchlist(seasons: [watchedFlat([1, 2])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 2)
  }

  @Test("Opens on season 3 when seasons 1 and 2 are fully watched")
  func opensOnFirstPartiallyWatchedSeason() {
    let episodes = [
      episode(season: 1, number: 1),
      episode(season: 2, number: 100),
      episode(season: 3, number: 200), episode(season: 3, number: 201),
    ]
    let list = watchlist(seasons: [watchedFlat([1, 100, 200])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 3)
  }

  @Test("Falls back to the last season when everything is watched")
  func allWatchedFallsBackToLastSeason() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 2, number: 100),
    ]
    let list = watchlist(seasons: [watchedFlat([1, 100])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 2)
  }

  @Test("Returns nil when there are no numbered seasons")
  func specialsOnlyReturnsNil() {
    let episodes = [
      episode(season: 0, number: 1, type: "special"),
      episode(season: nil, number: nil, type: "special"),
    ]
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: nil) == nil)
  }

  @Test("Watchlist without seasons data opens on the first season")
  func emptyWatchlistOpensFirstSeason() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 2, number: 100),
    ]
    #expect(
      AnimeDetailView.defaultSeason(episodes: episodes, watchlist: watchlist(seasons: nil)) == 1)
  }

  @Test("Advances past a watched anime group even when earlier groups were skipped")
  func skipsOlderUnwatchedGroups() {
    let episodes = [
      episode(season: 13, number: 1200), episode(season: 1, number: 1),
      episode(season: 12, number: 1100), episode(season: 12, number: 1101),
    ]
    let list = watchlist(seasons: [watchedFlat([1100, 1101])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 13)
  }

  @Test("Keeps an unfinished latest anime group despite unwatched earlier groups")
  func staysOnPartiallyWatchedLatestGroup() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 12, number: 1100),
      episode(season: 12, number: 1101), episode(season: 13, number: 1200),
    ]
    let list = watchlist(seasons: [watchedFlat([1100])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 12)
  }

  @Test("Caught-up anime stays on its latest group instead of revisiting skipped groups")
  func caughtUpDoesNotRevisitSkippedGroups() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 12, number: 1100),
      episode(season: 12, number: 1101),
    ]
    let list = watchlist(seasons: [watchedFlat([1100, 1101])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 12)
  }

  @Test("Anime resume advances across gaps in displayed groups")
  func advancesAcrossMissingGroups() {
    let episodes = [
      episode(season: 14, number: 1300), episode(season: 1, number: 1),
      episode(season: 12, number: 1100),
    ]
    let list = watchlist(seasons: [watchedFlat([1100])])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 14)
  }

  @Test("Watched specials and unknown anime episodes do not advance regular groups")
  func ignoresUnrelatedWatchedEntries() {
    let episodes = [
      episode(season: 1, number: 1), episode(season: 12, number: 1100),
      episode(season: 14, number: 1300, type: "special"),
    ]
    let list = watchlist(seasons: [
      watchedFlat([1199]), watchedFlat([1300], seasonNumber: 0),
    ])
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 1)
  }

  // MARK: - watchlistSeason / isEpisodeWatched

  @Test("Specials resolve to watchlist season 0, episodes to season 1")
  func watchlistSeasonMapping() {
    #expect(
      AnimeDetailView.watchlistSeason(for: episode(season: 0, number: 1, type: "special")) == 0)
    #expect(AnimeDetailView.watchlistSeason(for: episode(season: 2, number: 100)) == 1)
  }

  @Test("Matches the row checkmark semantics")
  func watchedMatching() {
    let list = watchlist(seasons: [watchedFlat([100])])
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 1, episode: 100) == true)
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 1, episode: 101) == false)
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 2, episode: 100) == false)
    #expect(AnimeDetailView.isEpisodeWatched(nil, season: 1, episode: 100) == false)
  }

  @Test("Explicitly unwatched entries count as unwatched")
  func explicitUnwatchedEntries() {
    let season = WatchlistSeason(
      number: 1,
      episodes_total: nil,
      episodes_aired: nil,
      episodes_to_be_aired: nil,
      episodes_watched: 0,
      episodes: [
        WatchlistEpisode(number: 1, watched: false, aired: true, last_watched_at: nil),
        WatchlistEpisode(number: 2, watched: nil, aired: true, last_watched_at: nil),
        WatchlistEpisode(number: nil, watched: true, aired: true, last_watched_at: nil),
      ]
    )
    let list = watchlist(seasons: [season])
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 1, episode: 1) == false)
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 1, episode: 2) == false)
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 1, episode: 100) == false)
    // A number-less entry never matches, not even the nil-episode fallback.
    #expect(AnimeDetailView.isEpisodeWatched(list, season: 1, episode: -1) == false)
    let episodes = [episode(season: 1, number: 1), episode(season: 1, number: 2)]
    #expect(AnimeDetailView.defaultSeason(episodes: episodes, watchlist: list) == 1)
  }
}

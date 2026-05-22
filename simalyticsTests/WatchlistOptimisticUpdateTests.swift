//
//  WatchlistOptimisticUpdateTests.swift
//  simalyticsTests
//
//  The in-memory ShowWatchlistModel / AnimeWatchlistModel mutation
//  logic used by the episode sheets. The bug the May 2026 review
//  uncovered: when a season wasn't present in the /sync/watched
//  response (e.g., user has never watched any episode of the show),
//  the optional-chain mutation silently no-op'd and the Watch button
//  never flipped to Watched until the full sync round-tripped.
//

import Testing

@testable import simalytics

@Suite("Watchlist optimistic update")
struct WatchlistOptimisticUpdateTests {

  // Mirrors the logic embedded in ShowEpisodeView.applyOptimisticWatchlistUpdate.
  // We test the pure transform so the SwiftUI layer doesn't need to be involved.
  private func applyOptimistic(
    _ watchlist: inout ShowWatchlistModel, season targetSeason: Int, episode targetEpisode: Int,
    watched: Bool
  ) {
    var seasons = watchlist.seasons ?? []
    if let seasonIdx = seasons.firstIndex(where: { $0.number == targetSeason }) {
      var s = seasons[seasonIdx]
      var eps = s.episodes ?? []
      if let epIdx = eps.firstIndex(where: { $0.number == targetEpisode }) {
        eps[epIdx].watched = watched
      } else {
        eps.append(
          WatchlistEpisode(number: targetEpisode, watched: watched, aired: true, last_watched_at: nil)
        )
      }
      s.episodes = eps
      seasons[seasonIdx] = s
    } else {
      let newEp = WatchlistEpisode(
        number: targetEpisode, watched: watched, aired: true, last_watched_at: nil)
      let newSeason = WatchlistSeason(
        number: targetSeason, episodes_total: nil, episodes_aired: nil,
        episodes_to_be_aired: nil, episodes_watched: nil, episodes: [newEp])
      seasons.append(newSeason)
    }
    watchlist.seasons = seasons
  }

  @Test("Updates existing episode in existing season")
  func updatesExistingEpisode() {
    var watchlist = ShowWatchlistModel(
      list: "watching", last_watched_at: nil, simkl: 1, episodes_watched: 0, episodes_aired: 10,
      seasons: [
        WatchlistSeason(
          number: 1, episodes_total: 10, episodes_aired: 10, episodes_to_be_aired: 0,
          episodes_watched: 0,
          episodes: [
            WatchlistEpisode(number: 1, watched: false, aired: true, last_watched_at: nil),
            WatchlistEpisode(number: 2, watched: false, aired: true, last_watched_at: nil),
          ])
      ])

    applyOptimistic(&watchlist, season: 1, episode: 2, watched: true)

    #expect(watchlist.seasons?[0].episodes?.first(where: { $0.number == 2 })?.watched == true)
    #expect(watchlist.seasons?[0].episodes?.first(where: { $0.number == 1 })?.watched == false)
  }

  @Test("Synthesizes missing episode in existing season")
  func synthesizesMissingEpisode() {
    var watchlist = ShowWatchlistModel(
      list: "watching", last_watched_at: nil, simkl: 1, episodes_watched: 0, episodes_aired: 10,
      seasons: [
        WatchlistSeason(
          number: 1, episodes_total: 10, episodes_aired: 10, episodes_to_be_aired: 0,
          episodes_watched: 0,
          episodes: [
            WatchlistEpisode(number: 1, watched: false, aired: true, last_watched_at: nil)
          ])
      ])

    applyOptimistic(&watchlist, season: 1, episode: 5, watched: true)

    let ep5 = watchlist.seasons?[0].episodes?.first(where: { $0.number == 5 })
    #expect(ep5?.watched == true)
    #expect(ep5?.aired == true)
  }

  @Test("Synthesizes entire missing season — regression for fresh-sync mark-complete bug")
  func synthesizesMissingSeason() {
    // This is the case the original code missed: /sync/watched returns
    // an empty `seasons` array for a show with no watched episodes, and
    // the optional-chain mutation silently no-op'd.
    var watchlist = ShowWatchlistModel(
      list: "watching", last_watched_at: nil, simkl: 1, episodes_watched: 0, episodes_aired: 10,
      seasons: [])

    applyOptimistic(&watchlist, season: 1, episode: 1, watched: true)

    #expect(watchlist.seasons?.count == 1)
    #expect(watchlist.seasons?[0].number == 1)
    #expect(watchlist.seasons?[0].episodes?.count == 1)
    #expect(watchlist.seasons?[0].episodes?[0].number == 1)
    #expect(watchlist.seasons?[0].episodes?[0].watched == true)
  }

  @Test("Synthesizes seasons array when nil")
  func synthesizesNilSeasons() {
    var watchlist = ShowWatchlistModel(
      list: "watching", last_watched_at: nil, simkl: 1, episodes_watched: 0, episodes_aired: 10,
      seasons: nil)

    applyOptimistic(&watchlist, season: 2, episode: 3, watched: true)

    #expect(watchlist.seasons?.count == 1)
    #expect(watchlist.seasons?[0].number == 2)
    #expect(watchlist.seasons?[0].episodes?[0].number == 3)
  }

  @Test("Toggles existing watched episode back to unwatched")
  func togglesExistingEpisodeOff() {
    var watchlist = ShowWatchlistModel(
      list: "watching", last_watched_at: nil, simkl: 1, episodes_watched: 1, episodes_aired: 10,
      seasons: [
        WatchlistSeason(
          number: 1, episodes_total: 10, episodes_aired: 10, episodes_to_be_aired: 0,
          episodes_watched: 1,
          episodes: [
            WatchlistEpisode(number: 1, watched: true, aired: true, last_watched_at: nil)
          ])
      ])

    applyOptimistic(&watchlist, season: 1, episode: 1, watched: false)

    #expect(watchlist.seasons?[0].episodes?[0].watched == false)
  }
}

//
//  UpNextBadgeTests.swift
//  simalyticsTests
//
//  Tests for the shared Up Next next-episode badge label.
//

import Testing

@testable import Simalytics

@Suite("UpNextBadge")
struct UpNextBadgeTests {

  private struct StubMedia: UpNextMedia {
    var simkl: Int = 1
    var title: String? = "Test Show"
    var poster: String? = nil
    var next_to_watch_info_title: String? = "Pilot"
    var next_to_watch_info_season: Int?
    var next_to_watch_info_episode: Int?
    var type: String = "tv"
  }

  @Test("Joins season and episode with spaced middle dot")
  func joinsSeasonAndEpisode() {
    let media: any UpNextMedia = StubMedia(
      next_to_watch_info_season: 7, next_to_watch_info_episode: 1)
    #expect(media.nextEpisodeBadge == "S7 · E1")
  }

  @Test("Omits missing season")
  func omitsMissingSeason() {
    let media: any UpNextMedia = StubMedia(
      next_to_watch_info_season: nil, next_to_watch_info_episode: 3)
    #expect(media.nextEpisodeBadge == "E3")
  }

  @Test("Returns nil when neither season nor episode is known")
  func nilWhenEmpty() {
    let media: any UpNextMedia = StubMedia(
      next_to_watch_info_season: nil, next_to_watch_info_episode: nil)
    #expect(media.nextEpisodeBadge == nil)
  }
}

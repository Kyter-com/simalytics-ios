import Testing

@testable import Simalytics

@Suite("Watched percentage")
struct WatchedPercentageTests {
  static func season(_ number: Int, watched: Int) -> WatchlistSeason {
    WatchlistSeason(
      number: number, episodes_total: nil, episodes_aired: nil, episodes_to_be_aired: nil,
      episodes_watched: watched, episodes: nil)
  }

  /// SIMKL's `episodes_watched` for Adolescence on 2026-11-20 counted 8 specials
  /// beside its 4 episodes, so the header read 300%.
  @Test("Specials don't count toward a title's episodes")
  func specialsExcluded() {
    let seasons = [Self.season(0, watched: 8), Self.season(1, watched: 4)]
    #expect(watchedPercentage(seasons: seasons, episodesWatched: 12, total: 4) == 100)
  }

  @Test("Partial progress across seasons")
  func partialProgress() {
    let seasons = [Self.season(1, watched: 10), Self.season(2, watched: 2)]
    #expect(watchedPercentage(seasons: seasons, episodesWatched: 12, total: 24) == 50)
  }

  @Test("Without seasons the overall count is used, and nothing passes 100%")
  func fallbacksAndCap() {
    #expect(watchedPercentage(seasons: nil, episodesWatched: 3, total: 4) == 75)
    #expect(
      watchedPercentage(seasons: [Self.season(1, watched: 7)], episodesWatched: 7, total: 6) == 100)
    #expect(watchedPercentage(seasons: nil, episodesWatched: 5, total: 0) == 0)
    #expect(watchedPercentage(seasons: nil, episodesWatched: 5, total: nil) == 0)
  }
}

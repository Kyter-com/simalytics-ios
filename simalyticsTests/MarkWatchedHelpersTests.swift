//
//  MarkWatchedHelpersTests.swift
//  simalyticsTests
//
//  Tests for the optimistic SwiftData mutations and up-next cache
//  invalidation used by the mark-watched flow.
//

import SwiftData
import Testing

@testable import simalytics

@MainActor
@Suite("MarkWatchedHelpers")
struct MarkWatchedHelpersTests {

  // MARK: - Test container helper

  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      V1.SDLastSync.self, V1.SDMovies.self, V1.SDShows.self, V1.SDAnimes.self,
      V1.TrendingMovies.self, V1.TrendingShows.self, V1.TrendingAnimes.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
  }

  // MARK: - optimisticallyClearNextToWatch

  @Test("Clears SDShows next_to_watch when episode/season match")
  func clearsTVWhenEpisodeMatches() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let show = V1.SDShows(
      simkl: 4921,
      status: "watching",
      title: "Black Mirror",
      next_to_watch_info_title: "Common People",
      next_to_watch_info_season: 7,
      next_to_watch_info_episode: 1,
      next_to_watch_info_date: "2025-04-10T00:00:00-05:00"
    )
    context.insert(show)
    try context.save()

    optimisticallyClearNextToWatch(
      simklId: 4921, season: 7, episode: 1, kind: .tv, modelContainer: container)

    let fd = FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == 4921 })
    let refreshed = try ModelContext(container).fetch(fd).first
    #expect(refreshed?.next_to_watch_info_title == nil)
    #expect(refreshed?.next_to_watch_info_season == nil)
    #expect(refreshed?.next_to_watch_info_episode == nil)
    #expect(refreshed?.next_to_watch_info_date == nil)
  }

  @Test("Does NOT clear SDShows when marking a non-next episode")
  func noopWhenDifferentTVEpisode() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let show = V1.SDShows(
      simkl: 4921,
      status: "watching",
      title: "Black Mirror",
      next_to_watch_info_title: "Common People",
      next_to_watch_info_season: 7,
      next_to_watch_info_episode: 1
    )
    context.insert(show)
    try context.save()

    // Mark a future episode (5) — should NOT clear because next-to-watch is ep 1.
    optimisticallyClearNextToWatch(
      simklId: 4921, season: 7, episode: 5, kind: .tv, modelContainer: container)

    let fd = FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == 4921 })
    let refreshed = try ModelContext(container).fetch(fd).first
    #expect(refreshed?.next_to_watch_info_title == "Common People")
    #expect(refreshed?.next_to_watch_info_episode == 1)
  }

  @Test("Clears SDShows when season is unknown but episode matches")
  func clearsTVWhenSeasonUnknown() throws {
    // Some shows can have nil season in next_to_watch_info (older data).
    // We still clear if the episode number matches.
    let container = try makeContainer()
    let context = ModelContext(container)
    let show = V1.SDShows(
      simkl: 100,
      status: "watching",
      title: "Unknown-season show",
      next_to_watch_info_title: "Ep 3",
      next_to_watch_info_season: nil,
      next_to_watch_info_episode: 3
    )
    context.insert(show)
    try context.save()

    optimisticallyClearNextToWatch(
      simklId: 100, season: 1, episode: 3, kind: .tv, modelContainer: container)

    let fd = FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == 100 })
    let refreshed = try ModelContext(container).fetch(fd).first
    #expect(refreshed?.next_to_watch_info_episode == nil)
  }

  @Test("Clears SDAnimes next_to_watch ignoring season (anime is global)")
  func clearsAnimeIgnoringSeason() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let anime = V1.SDAnimes(
      simkl: 38636,
      status: "watching",
      anime_type: "tv",
      title: "One Piece",
      next_to_watch_info_title: "The Captains Square Off!",
      next_to_watch_info_episode: 217,
      next_to_watch_info_date: "2005-01-16T00:00:00+09:00"
    )
    context.insert(anime)
    try context.save()

    // Anime always uses season=1 in the POST body but the storage record
    // has no season field. Helper must match purely on episode.
    optimisticallyClearNextToWatch(
      simklId: 38636, season: 1, episode: 217, kind: .anime, modelContainer: container)

    let fd = FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.simkl == 38636 })
    let refreshed = try ModelContext(container).fetch(fd).first
    #expect(refreshed?.next_to_watch_info_title == nil)
    #expect(refreshed?.next_to_watch_info_episode == nil)
    #expect(refreshed?.next_to_watch_info_date == nil)
  }

  @Test("Anime helper does nothing when episode doesn't match")
  func noopWhenDifferentAnimeEpisode() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let anime = V1.SDAnimes(
      simkl: 38636,
      status: "watching",
      anime_type: "tv",
      title: "One Piece",
      next_to_watch_info_title: "Ep 217",
      next_to_watch_info_episode: 217
    )
    context.insert(anime)
    try context.save()

    optimisticallyClearNextToWatch(
      simklId: 38636, season: 1, episode: 100, kind: .anime, modelContainer: container)

    let fd = FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.simkl == 38636 })
    let refreshed = try ModelContext(container).fetch(fd).first
    #expect(refreshed?.next_to_watch_info_episode == 217)
  }

  @Test("Helper is a no-op when row doesn't exist")
  func missingRowIsNoop() throws {
    let container = try makeContainer()
    optimisticallyClearNextToWatch(
      simklId: 99999, season: 1, episode: 1, kind: .tv, modelContainer: container)
    // No throw, no crash, no side effects.
    let fd = FetchDescriptor<V1.SDShows>()
    let all = try ModelContext(container).fetch(fd)
    #expect(all.isEmpty)
  }

  // MARK: - invalidateUpNextCache

  @Test("Nulls out SDLastSync.changes_api")
  func invalidatesUpNextCache() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.changes_api = "2026-05-22T17:00:00Z"
    context.insert(sync)
    try context.save()

    invalidateUpNextCache(modelContainer: container)

    let fd = FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    let refreshed = try ModelContext(container).fetch(fd).first
    #expect(refreshed?.changes_api == nil)
  }

  @Test("Invalidate is safe when SDLastSync row doesn't exist")
  func invalidateMissingRowIsNoop() throws {
    let container = try makeContainer()
    invalidateUpNextCache(modelContainer: container)
    let fd = FetchDescriptor<V1.SDLastSync>()
    let all = try ModelContext(container).fetch(fd)
    #expect(all.isEmpty)
  }
}

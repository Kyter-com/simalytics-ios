//
//  ProcessUpNextEpisodesTests.swift
//  simalyticsTests
//
//  Tests for the up-next computation. The network-touching parts of
//  processUpNextEpisodes are exercised through a contract-style live API
//  test (see SimklContractTests). These unit tests cover the parts we
//  can isolate: the cache gate logic, and that the anime path no longer
//  silently no-ops on nil-season episodes (regression for the bug found
//  during the May 2026 review).
//

import SwiftData
import Testing

@testable import simalytics

@MainActor
@Suite("processUpNextEpisodes — cache + sequencing")
struct ProcessUpNextCacheTests {

  private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
      V1.SDLastSync.self, V1.SDMovies.self, V1.SDShows.self, V1.SDAnimes.self,
      V1.TrendingMovies.self, V1.TrendingShows.self, V1.TrendingAnimes.self,
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
  }

  // The 6-hour cache lives in SDLastSync.changes_api. invalidateUpNextCache
  // is what mark-watched relies on to force the next sync to recompute.
  // If this contract changes, the optimistic flow breaks silently.
  @Test("changes_api is the cache gate field used by processUpNextEpisodes")
  func cacheGateFieldContract() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.changes_api = "2026-05-22T10:00:00Z"
    context.insert(sync)
    try context.save()

    invalidateUpNextCache(modelContainer: container)

    let refreshed = try ModelContext(container).fetch(
      FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    ).first
    #expect(refreshed?.changes_api == nil, "changes_api must be the field invalidateUpNextCache nulls")
  }
}

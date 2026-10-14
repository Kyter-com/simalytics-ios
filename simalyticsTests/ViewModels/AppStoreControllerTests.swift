import Foundation
import SwiftData
import Testing

@testable import Simalytics

@MainActor
struct AppStoreControllerTests {
  @Test("A failed store open offers recovery and a later attempt preserves the store")
  func recoverAfterOpenFailure() async throws {
    let store = AppStoreController()
    await store.load { throw NSError(domain: "NSSQLiteErrorDomain", code: 13) }
    #expect(store.failure == .insufficientSpace)
    #expect(store.container == nil)
    #expect(store.isLoading == false)
    let container = try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.insert(V1.SDMovies(simkl: 42, title: "Preserved"))
    try context.save()
    await store.load { container }
    #expect(store.container === container)
    #expect(store.failure == nil)
    #expect(try container.mainContext.fetchCount(FetchDescriptor<V1.SDMovies>()) == 1)
    await store.load {
      Issue.record("An open store must not be recreated")
      return container
    }
  }

  @Test("Resetting a store that won't open deletes it, then opens a fresh one")
  func resetAfterOpenFailure() async throws {
    let store = AppStoreController()
    await store.load { throw NSError(domain: "NSSQLiteErrorDomain", code: 11) }
    #expect(store.failure == .unavailable)
    let container = try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    await confirmation("store deleted before reopening") { deleted in
      await store.resetAndLoad(reset: { deleted() }, open: { container })
    }
    #expect(store.container === container)
    #expect(store.failure == nil)
  }

  @Test("Store reset removes the database and its SQLite companions only")
  func deleteStoreFilesTest() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "AppStoreControllerTests.\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = directory.appending(path: "default.store")
    for name in ["default.store", "default.store-shm", "default.store-wal", "keep.txt"] {
      try Data("x".utf8).write(to: directory.appending(path: name))
    }
    try deleteStoreFiles(at: store)
    let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(remaining == ["keep.txt"])
    #expect(ModelConfiguration(schema: Schema(V1.models)).url.pathExtension == "store")
  }

  @Test("Cancelled opening does not display a storage error")
  func cancellation() async {
    let store = AppStoreController()
    await store.load { throw CancellationError() }
    #expect(store.failure == nil)
    #expect(store.isLoading == false)
  }

  @Test("Background library counts match the persisted statuses")
  func counts() async throws {
    let container = try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    context.insert(V1.SDMovies(simkl: 1, title: "Planned", status: "plantowatch"))
    context.insert(V1.SDMovies(simkl: 2, title: "Completed", status: "completed"))
    context.insert(V1.SDShows(simkl: 3, status: "watching"))
    context.insert(V1.SDAnimes(simkl: 4, status: "hold"))
    try context.save()
    let counts = try await LibraryCounts.fetch(from: container)
    #expect(counts.moviesPlanToWatchCount == 1)
    #expect(counts.moviesCompletedCount == 1)
    #expect(counts.showsWatchingCount == 1)
    #expect(counts.animeHoldCount == 1)
    #expect(counts.moviesDroppedCount == 0)
    #expect(counts.animeWatchingCount == 0)
  }
}

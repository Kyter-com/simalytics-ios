import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppStoreController {
  private(set) var container: ModelContainer?
  private(set) var failure: StorageFailure?
  private(set) var isLoading = false

  func load(
    open: @Sendable () async throws -> ModelContainer = openAppModelContainer
  ) async {
    guard container == nil, !isLoading else { return }
    isLoading = true
    failure = nil
    defer { isLoading = false }
    do {
      let opened = try await open()
      try Task.checkCancellation()
      container = opened
    } catch {
      guard !isSimklCancellationError(error) else { return }
      failure = StorageFailure.classify(error) ?? .unavailable
      reportError(error)
    }
  }

  /// Last resort when the store can't be opened at all: delete this device's
  /// copy so the next sync rebuilds it from Simkl. Nothing on Simkl changes.
  func resetAndLoad(
    reset: @Sendable () async throws -> Void = deleteAppModelStore,
    open: @Sendable () async throws -> ModelContainer = openAppModelContainer
  ) async {
    guard container == nil, !isLoading else { return }
    do {
      try await reset()
    } catch {
      reportError(error)
    }
    await load(open: open)
  }
}

@concurrent
func deleteAppModelStore() async throws {
  try deleteStoreFiles(at: ModelConfiguration(schema: Schema(V1.models)).url)
}

/// SQLite keeps write-ahead companions next to the store; remove them together.
nonisolated func deleteStoreFiles(at url: URL, fileManager: FileManager = .default) throws {
  for suffix in ["", "-shm", "-wal"] {
    let file = URL(fileURLWithPath: url.path + suffix)
    guard fileManager.fileExists(atPath: file.path) else { continue }
    try fileManager.removeItem(at: file)
  }
}

/// Opening/migrating the store can involve disk I/O. Keep it off the UI actor,
/// and pass only the container across; each caller creates its own context.
@concurrent
func openAppModelContainer() async throws -> ModelContainer {
  #if DEBUG
    if ScreenshotMode.isActive { return ScreenshotMode.makeSeededContainer() }
  #endif
  let schema = Schema(V1.models)
  return try ModelContainer(
    for: schema, migrationPlan: SimalyticsMigrationPlan.self,
    configurations: ModelConfiguration(schema: schema))
}

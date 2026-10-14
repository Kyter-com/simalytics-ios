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

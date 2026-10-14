import Foundation
import SwiftData

enum SyncOutcome: Equatable, Sendable {
  case succeeded
  case incomplete
  case cancelled
  case storageFailure(StorageFailure)

  var shouldDiscardPendingSync: Bool {
    switch self {
    case .storageFailure, .cancelled: true
    case .succeeded, .incomplete: false
    }
  }
}

/// A fresh monitor belongs to one sync attempt. Child enrichment tasks inherit
/// it; concurrent, unrelated requests cannot poison a later retry.
enum SyncFailureScope {
  @TaskLocal private static var monitor: Monitor?

  private actor Monitor {
    var outcome = SyncOutcome.succeeded

    func record(_ error: Error) -> Bool {
      if outcome.shouldDiscardPendingSync { return false }
      if let failure = StorageFailure.classify(error) {
        outcome = .storageFailure(failure)
      } else if isSimklCancellationError(error) {
        outcome = .cancelled
      } else {
        outcome = .incomplete
      }
      return true
    }

    func check() throws {
      if case .storageFailure(let failure) = outcome { throw failure }
      if case .cancelled = outcome { throw CancellationError() }
    }
  }

  static func perform(_ operation: () async throws -> Void) async -> SyncOutcome {
    let attempt = Monitor()
    return await $monitor.withValue(attempt) {
      do {
        try await operation()
        try await check()
      } catch {
        await report(error)
      }
      return await attempt.outcome
    }
  }

  static func report(_ error: Error) async {
    let shouldReport = await monitor?.record(error) ?? true
    if shouldReport { reportError(error) }
  }

  static func check() async throws {
    try Task.checkCancellation()
    try await monitor?.check()
  }

  static func step(_ operation: () async -> Void) async throws {
    try await check()
    await operation()
    try await check()
  }
}

func makeSyncContext(_ container: ModelContainer) -> ModelContext {
  let context = ModelContext(container)
  context.autosaveEnabled = false
  return context
}

/// Keep the last-sync cursor and its data in the same save. A failed write
/// rolls back both, so a subsequent attempt can download the missed changes.
func saveSyncContext(_ context: ModelContext, save: (() throws -> Void)? = nil) async throws {
  do {
    try await SyncFailureScope.check()
    if let save { try save() } else { try context.save() }
  } catch {
    context.rollback()
    throw error
  }
}

extension Notification.Name {
  static let syncStorageFailed = Notification.Name("SyncStorageFailed")
}

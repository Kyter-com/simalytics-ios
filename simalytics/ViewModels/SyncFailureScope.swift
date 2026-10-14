import Foundation
import SwiftData
import os

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
    let accessToken: String?

    init(accessToken: String?) {
      self.accessToken = accessToken
    }

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
      // Signing out discards local data; this attempt must not write it back.
      if let accessToken, !SyncAccount.isActive(accessToken) { throw CancellationError() }
    }
  }

  static func perform(
    accessToken: String? = nil, _ operation: () async throws -> Void
  ) async -> SyncOutcome {
    let attempt = Monitor(accessToken: accessToken)
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

/// The signed-in account that syncs may write for. Sign-out clears it, so a
/// sync already running, or one started later with the old token, stops at its
/// next check instead of restoring the previous account's library.
enum SyncAccount {
  private static let current = OSAllocatedUnfairLock<String?>(initialState: nil)

  static func update(_ accessToken: String) {
    current.withLock { $0 = accessToken.isEmpty ? nil : accessToken }
  }

  static func isActive(_ accessToken: String) -> Bool {
    current.withLock { $0 == accessToken }
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

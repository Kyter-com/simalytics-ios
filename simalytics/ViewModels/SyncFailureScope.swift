import Foundation
import SwiftData
import os

enum SyncOutcome: Equatable, Sendable {
  case succeeded
  case incomplete
  case cancelled
  case storageFailure(StorageFailure)
  /// Simkl stopped accepting the sign-in, or there isn't one. The rest of the
  /// attempt would only repeat the same rejection.
  case authenticationRequired
  /// Simkl's daily allowance is spent, so every remaining request would be
  /// refused too. Syncing waits for the reset.
  case dailyLimitReached

  var shouldDiscardPendingSync: Bool {
    switch self {
    case .storageFailure, .cancelled, .authenticationRequired, .dailyLimitReached: true
    case .succeeded, .incomplete: false
    }
  }
}

/// A fresh monitor belongs to one sync attempt. Child enrichment tasks inherit
/// it; concurrent, unrelated requests cannot poison a later retry.
enum SyncFailureScope {
  @TaskLocal private static var monitor: Monitor?

  /// The account the sync running on this task writes for. Its requests go out
  /// for that account only, so a switch mid-sync can't lend them a new token.
  static var account: UUID? { monitor?.account }

  private actor Monitor {
    var outcome = SyncOutcome.succeeded
    nonisolated let account: UUID?

    init(account: UUID?) {
      self.account = account
    }

    func record(_ error: Error) -> Bool {
      if outcome.shouldDiscardPendingSync { return false }
      if let failure = StorageFailure.classify(error) {
        outcome = .storageFailure(failure)
      } else if isSimklCancellationError(error) {
        outcome = .cancelled
      } else if error is SimklAuthError {
        outcome = .authenticationRequired
      } else {
        outcome = .incomplete
      }
      return true
    }

    func reachDailyLimit() {
      guard !outcome.shouldDiscardPendingSync else { return }
      outcome = .dailyLimitReached
    }

    func check() throws {
      if case .storageFailure(let failure) = outcome { throw failure }
      if case .cancelled = outcome { throw CancellationError() }
      if case .authenticationRequired = outcome { throw SimklAuthError.signedOut }
      if case .dailyLimitReached = outcome { throw CancellationError() }
      // Signing out (or replacing the library with another account) discards
      // local data; this attempt must not write it back.
      if let account, !SyncAccount.isActive(account) { throw CancellationError() }
    }
  }

  static func perform(
    account: UUID? = nil, _ operation: () async throws -> Void
  ) async -> SyncOutcome {
    let attempt = Monitor(account: account)
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

  /// Simkl's daily allowance ran out: the running sync stops at its next check.
  /// Requests report this themselves, since some read the response without throwing.
  static func noteDailyLimit() async {
    await monitor?.reachDailyLimit()
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

/// The account a sync may write for: `SimklSession`'s account session ID,
/// mirrored here so synchronous checks can read it. It survives token refreshes
/// and reconnecting as the same person. Signing out, or replacing the library
/// with another account, changes it, so a sync already running stops at its
/// next check instead of restoring the previous account's library.
enum SyncAccount {
  private static let current = OSAllocatedUnfairLock<UUID?>(initialState: nil)

  static var id: UUID? { current.withLock { $0 } }

  static func update(_ account: UUID?) {
    current.withLock { $0 = account }
  }

  static func isActive(_ account: UUID) -> Bool {
    current.withLock { $0 == account }
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

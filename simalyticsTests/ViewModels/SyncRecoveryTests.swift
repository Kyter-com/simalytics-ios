import Foundation
import SwiftData
import Testing

@testable import Simalytics

struct SyncRecoveryTests {
  @Test("A storage failure prevents the next sync section and a new attempt can succeed")
  func abortsAndRetries() async {
    let outcome = await SyncFailureScope.perform {
      try await SyncFailureScope.step {
        await SyncFailureScope.report(NSError(domain: "NSSQLiteErrorDomain", code: 13))
      }
      try await SyncFailureScope.step {
        Issue.record("A second section must not run after disk failure")
      }
    }
    #expect(outcome == .storageFailure(.insufficientSpace))
    let retried = await SyncFailureScope.perform { try await SyncFailureScope.step {} }
    #expect(retried == .succeeded)
  }

  @Test("Signing out stops a running sync before another section can write")
  func signOutStopsSync() async {
    let token = "sync-recovery-\(UUID())"
    SyncAccount.update(token)
    let outcome = await SyncFailureScope.perform(accessToken: token) {
      try await SyncFailureScope.step { SyncAccount.update("") }
      try await SyncFailureScope.step {
        Issue.record("No section may run after sign-out")
      }
    }
    #expect(outcome == .cancelled)
    #expect(!SyncAccount.isActive(token))
  }

  @Test("A malformed response leaves sync incomplete while unrelated sections can still run")
  func malformedResponse() async {
    await confirmation("next section ran") { nextSection in
      let outcome = await SyncFailureScope.perform {
        try await SyncFailureScope.step {
          await SyncFailureScope.report(SimklMutationError.invalidResponse)
        }
        try await SyncFailureScope.step { nextSection() }
      }
      #expect(outcome == .incomplete)
    }
  }

  @Test("Child tasks inherit storage failures without leaking them to another attempt")
  func inheritedScope() async {
    let outcome = await SyncFailureScope.perform {
      await withTaskGroup(of: Void.self) { group in
        group.addTask {
          await SyncFailureScope.report(NSError(domain: "NSSQLiteErrorDomain", code: 4618))
        }
      }
      try await SyncFailureScope.check()
    }
    #expect(outcome == .storageFailure(.unavailable))
    #expect(await SyncFailureScope.perform {} == .succeeded)
  }

  @Test("Cancellation stops queued sections")
  func cancellation() async {
    let outcome = await SyncFailureScope.perform {
      try await SyncFailureScope.step { await SyncFailureScope.report(CancellationError()) }
      Issue.record("Cancellation should abort the attempt")
    }
    #expect(outcome == .cancelled)
  }

  @Test("Late errors from a child task cannot restart a cancelled attempt")
  func cancellationPersists() async {
    let outcome = await SyncFailureScope.perform {
      await SyncFailureScope.report(CancellationError())
      await SyncFailureScope.report(URLError(.badServerResponse))
    }
    #expect(outcome == .cancelled)
  }

  @MainActor
  @Test("Finishing an overlapping operation keeps the library busy until both finish")
  func overlappingLoading() {
    let indicator = GlobalLoadingIndicator()
    indicator.startSync()
    indicator.startSync()
    indicator.stopSync()
    #expect(indicator.isSyncing)
    indicator.stopSync()
    #expect(indicator.isSyncing == false)
    indicator.stopSync()
    indicator.startSync()
    #expect(indicator.isSyncing)
    indicator.stopSync()
  }

  @Test("Storage abort drops automatic queued retries and releases the gate for a manual retry")
  func pendingSyncIsDiscarded() async {
    let gate = SyncLatestActivitiesGate()
    #expect(await gate.begin(forceRefresh: false))
    #expect(await gate.begin(forceRefresh: true) == false)
    #expect(await gate.finishCurrentRun(discardPending: true) == nil)
    #expect(await gate.begin(forceRefresh: false))
    #expect(await gate.finishCurrentRun() == nil)
  }

  @Test("Normal coalesced sync still preserves a forced refresh")
  func normalCoalescing() async {
    let gate = SyncLatestActivitiesGate()
    #expect(await gate.begin(forceRefresh: false))
    #expect(await gate.begin(forceRefresh: true) == false)
    #expect(await gate.finishCurrentRun() == true)
    #expect(await gate.finishCurrentRun() == nil)
  }

  @Test("A failed save rolls back both data and its last-sync timestamp")
  func saveFailurePreservesLibrary() async throws {
    let container = try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = makeSyncContext(container)
    context.insert(V1.SDMovies(simkl: 42, title: "Original"))
    let cursor = V1.SDLastSync(id: 1)
    cursor.movies_plantowatch = "2026-10-01T00:00:00Z"
    context.insert(cursor)
    try context.save()
    let row = try #require(context.fetch(FetchDescriptor<V1.SDMovies>()).first)
    row.title = "Unsaved change"
    cursor.movies_plantowatch = "2026-10-12T00:00:00Z"
    context.insert(V1.SDMovies(simkl: 43, title: "Unsaved row"))
    do {
      try await saveSyncContext(context) { throw NSError(domain: "NSSQLiteErrorDomain", code: 13) }
      Issue.record("The save must fail")
    } catch {
      #expect(StorageFailure.classify(error) == .insufficientSpace)
    }
    #expect(context.hasChanges == false)
    let persisted = try context.fetch(FetchDescriptor<V1.SDMovies>())
    #expect(persisted.count == 1)
    #expect(persisted.first?.title == "Original")
    #expect(
      try context.fetch(FetchDescriptor<V1.SDLastSync>()).first?.movies_plantowatch
        == "2026-10-01T00:00:00Z")
  }
}

import Foundation
import Testing

@testable import Simalytics

/// Which account a sync may write for, now keyed by the account session rather
/// than the access token, which AUTH V2 replaces every week.
struct SyncAccountTests {
  @Test("Signing out stops a running sync before another section can write")
  func signOutStopsSync() async {
    let account = UUID()
    SyncAccount.update(account)
    let outcome = await SyncFailureScope.perform(account: account) {
      try await SyncFailureScope.step { SyncAccount.update(nil) }
      try await SyncFailureScope.step {
        Issue.record("No section may run after sign-out")
      }
    }
    #expect(outcome == .cancelled)
    #expect(!SyncAccount.isActive(account))
  }

  @Test("A sign-in Simkl stopped accepting ends the attempt without retrying sections")
  func authenticationStopsSync() async {
    let outcome = await SyncFailureScope.perform {
      try await SyncFailureScope.step {
        await SyncFailureScope.report(SimklAuthError.reconnectRequired(.signInEnded))
      }
      try await SyncFailureScope.step {
        Issue.record("A rejected sign-in must not keep requesting")
      }
    }
    #expect(outcome == .authenticationRequired)
    #expect(outcome.shouldDiscardPendingSync)
  }

  @Test("Simkl's daily limit ends the attempt instead of failing every remaining section")
  func dailyLimitStopsSync() async {
    let outcome = await SyncFailureScope.perform {
      try await SyncFailureScope.step { await SyncFailureScope.noteDailyLimit() }
      try await SyncFailureScope.step {
        Issue.record("No section may run once the daily allowance is spent")
      }
    }
    #expect(outcome == .dailyLimitReached)
    #expect(outcome.shouldDiscardPendingSync)
  }

  @Test("Refreshing the token never looks like a sign-out to a running sync")
  func refreshKeepsSyncAccount() async throws {
    let store = SimklMemoryCredentialStore(
      SimklCredential(
        version: .v2, accessToken: "simkl_at_OLD", refreshToken: "simkl_rt_R",
        scope: "media:read media:write", account: SimklAccount(id: 7)))
    let session = SimklSession(store: store)
    let account = try #require(await session.syncAccountID())
    // Installing a refreshed credential for the same account keeps the session.
    var refreshed = try #require(store.saved)
    refreshed.accessToken = "simkl_at_NEW"
    try await session.install(refreshed, keepingLibrary: true)
    #expect(await session.syncAccountID() == account)
  }
}

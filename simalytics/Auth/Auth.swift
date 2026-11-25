//
//  Auth.swift
//  simalytics
//

import Foundation
import Observation

/// A sign-in that approved a different Simkl account than the one whose library
/// is on this device. Nothing is installed until the person decides.
struct SimklPendingAccountSwitch: Equatable, Sendable {
  let credential: SimklCredential
  let previous: SimklAccount
  let new: SimklAccount
}

/// The Simkl sign-in as the interface sees it, mirrored from `SimklSession`.
@Observable @MainActor
final class Auth {
  @ObservationIgnored let session: SimklSession
  @ObservationIgnored private let oauth: SimklOAuthClient
  @ObservationIgnored private var observation: Task<Void, Never>?

  private(set) var snapshot: SimklSessionSnapshot
  private(set) var isSigningIn = false
  /// Drives the sign-in error alert.
  var signInError: SimklSignInError?
  /// Drives the "switch accounts?" confirmation.
  var pendingAccountSwitch: SimklPendingAccountSwitch?
  /// Moves when a sign-in completes or a saved one becomes usable again, so
  /// the app starts a sync.
  private(set) var connectionGeneration = 0

  init(session: SimklSession = .shared, oauth: SimklOAuthClient = SimklOAuthClient()) {
    self.session = session
    self.oauth = oauth
    self.snapshot = session.initialSnapshot
    observation = Task { [weak self] in
      for await snapshot in await session.updates() {
        guard let self else { return }
        if self.snapshot != snapshot { self.snapshot = snapshot }
      }
    }
  }

  // MARK: State for views

  var status: SimklSessionStatus { snapshot.status }

  /// A Simkl account is attached, working or not: show its library.
  var hasAccount: Bool { status != .signedOut }

  /// The saved sign-in works: network features and edits are available.
  var isConnected: Bool {
    if case .connected = status { return true }
    return false
  }

  /// Identifies the account whose library is on this device. Compare it before
  /// and after an `await` to drop results that belong to a previous account.
  var accountSessionID: UUID? { snapshot.accountSessionID }

  var account: SimklAccount? {
    switch status {
    case .signedOut: nil
    case .connected(_, let account): account
    case .reconnectRequired(_, _, let account): account
    }
  }

  var authVersion: SimklAuthVersion? {
    switch status {
    case .signedOut: nil
    case .connected(let version, _): version
    case .reconnectRequired(_, let version, _): version
    }
  }

  /// Still on the AUTH V1 sign-in that Simkl is retiring.
  var usesLegacySignIn: Bool { isConnected && authVersion == .v1 }

  var reconnectReason: SimklReconnectReason? {
    if case .reconnectRequired(let reason, _, _) = status { return reason }
    return nil
  }

  var dailyLimitResetsAt: Date? { snapshot.dailyLimitResetsAt }

  // MARK: Actions

  /// Runs an AUTH V2 sign-in. Used to sign in, to reconnect, and to upgrade an
  /// AUTH V1 sign-in. The library stays only when the same account approves.
  /// `resetLibrary` clears this device's copy when it belongs to someone else
  /// or nobody can tell whose it is.
  func signIn(
    authenticate: SimklSignInFlow.Authenticate,
    resetLibrary: @MainActor () -> Void
  ) async {
    guard !isSigningIn else { return }
    isSigningIn = true
    defer { isSigningIn = false }
    // A switch left undecided (its dialog dismissed without a choice) ends here.
    if let stale = takePendingAccountSwitch() { await discardAccountSwitch(stale) }

    let previous = account
    let result: SimklSignInFlow.Result
    do {
      result = try await SimklSignInFlow(oauth: oauth).run(authenticate: authenticate)
    } catch .cancelled {
      return
    } catch {
      if error.isUnexpected { reportError(error) }
      signInError = error
      return
    }

    if let previous, previous.id != result.account.id {
      // Another account's changes must never merge into this library.
      pendingAccountSwitch = SimklPendingAccountSwitch(
        credential: result.credential, previous: previous, new: result.account)
      return
    }
    await install(result.credential, keepingLibrary: previous != nil, resetLibrary: resetLibrary)
  }

  /// Claims the pending switch so exactly one choice acts on it, whichever of a
  /// dialog button or its dismissal arrives first.
  func takePendingAccountSwitch() -> SimklPendingAccountSwitch? {
    defer { pendingAccountSwitch = nil }
    return pendingAccountSwitch
  }

  func confirmAccountSwitch(
    _ pending: SimklPendingAccountSwitch, resetLibrary: @MainActor () -> Void
  ) async {
    await install(pending.credential, keepingLibrary: false, resetLibrary: resetLibrary)
  }

  /// Keeps the current account and ends the grant the other one just created.
  func discardAccountSwitch(_ pending: SimklPendingAccountSwitch) async {
    if let token = pending.credential.refreshToken { await oauth.revoke(token) }
  }

  func signOut(resetLibrary: @MainActor () -> Void) async {
    await session.signOut()
    resetLibrary()
  }

  /// AUTH V1 sign-ins predate the saved account. Read it once, so a later
  /// upgrade can tell the same person apart from a different account.
  func backfillAccountIfNeeded() async {
    guard await session.needsAccountBackfill else { return }
    do {
      let settings = try await SimklAPI.$scopedSession.withValue(session) {
        try await fetchSimklUserSettings()
      }
      if let account = settings.simklAccount { await session.recordAccount(account) }
    } catch {
      reportError(error)
    }
  }

  /// Retries a Keychain read that failed at launch, and syncs if that brought
  /// a working sign-in back.
  func reloadIfNeeded() async {
    let wasConnected = isConnected
    await session.reloadIfNeeded()
    let snapshot = await session.currentSnapshot
    self.snapshot = snapshot
    if !wasConnected, isConnected { connectionGeneration += 1 }
  }

  private func install(
    _ credential: SimklCredential, keepingLibrary: Bool, resetLibrary: @MainActor () -> Void
  ) async {
    do {
      try await session.install(credential, keepingLibrary: keepingLibrary)
    } catch {
      reportError(error)
      signInError = .storageFailed
      if let token = credential.refreshToken { await oauth.revoke(token) }
      return
    }
    if !keepingLibrary { resetLibrary() }
    connectionGeneration += 1
  }
}

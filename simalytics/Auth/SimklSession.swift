//
//  SimklSession.swift
//  simalytics
//

import Foundation

/// Whether a request carries the signed-in person's token. Call sites mark the
/// request; the token itself is attached only as it's sent, so a refresh
/// between building and sending a request can't leave it holding a dead token.
enum SimklRequestAuth: String, Sendable {
  case none
  case user
}

extension URLRequest {
  private static let simklAuthKey = "com.kyter.simalytics.simkl-auth"

  /// Stored as a URLProtocol property, which is never sent over the network.
  var simklAuth: SimklRequestAuth {
    get {
      (URLProtocol.property(forKey: Self.simklAuthKey, in: self) as? String)
        .flatMap(SimklRequestAuth.init(rawValue:)) ?? .none
    }
    set {
      guard let mutable = (self as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
        return
      }
      if newValue == .none {
        URLProtocol.removeProperty(forKey: Self.simklAuthKey, in: mutable)
      } else {
        URLProtocol.setProperty(newValue.rawValue, forKey: Self.simklAuthKey, in: mutable)
      }
      self = mutable as URLRequest
    }
  }
}

/// Why the person needs to sign in to Simkl again. Copy branches on this, and
/// only claims what's known: a rejected token can mean the app was removed in
/// Simkl's Connected Apps, six months without use, or AUTH V1 retiring.
enum SimklReconnectReason: String, Codable, Sendable, Equatable {
  /// Simkl stopped accepting the AUTH V2 sign-in.
  case signInEnded
  /// Simkl stopped accepting the AUTH V1 token, which can't be refreshed.
  case legacySignInEnded
  /// The token can't write, so changes couldn't be saved.
  case missingWriteAccess
  /// This device has a library but no saved sign-in, as after restoring a
  /// backup to a new iPhone.
  case credentialMissing
}

enum SimklAuthError: Error, Equatable, Sendable, CustomNSError {
  /// The request needs a signed-in person and there isn't one.
  case signedOut
  /// Simkl won't accept the saved sign-in. Local data stays; syncing waits.
  case reconnectRequired(SimklReconnectReason)
  /// Simkl rejected a token it had just issued. Usually clears in a moment, so
  /// the sign-in isn't thrown away for it.
  case temporarilyRejected

  static var errorDomain: String { "Simalytics.SimklAuthError" }
  var errorCode: Int {
    switch self {
    case .signedOut: 1
    case .reconnectRequired: 2
    case .temporarilyRejected: 3
    }
  }
}

enum SimklSessionStatus: Equatable, Sendable {
  case signedOut
  case connected(version: SimklAuthVersion, account: SimklAccount?)
  case reconnectRequired(
    SimklReconnectReason, version: SimklAuthVersion?, account: SimklAccount?)
}

struct SimklSessionSnapshot: Equatable, Sendable {
  var status: SimklSessionStatus
  /// The account whose library is on this device, for this run of the app.
  /// Refreshing or reconnecting as the same person keeps it; signing out or
  /// replacing the library with another account changes it, which stops any
  /// sync still writing for the old one.
  var accountSessionID: UUID?
  /// When Simkl's daily request allowance for this person resets, while it's spent.
  var dailyLimitResetsAt: Date?
}

/// A request ready to send, and the token it carries.
struct PreparedSimklRequest: Sendable {
  var request: URLRequest
  var token: String?
  /// The account the token belongs to. A retry must never switch accounts.
  var account: UUID?
  /// Only Simkl's own 401 means "refresh". The Simalytics backend relays one
  /// when its own check fails, which a refresh here wouldn't fix.
  var refreshesOnUnauthorized: Bool
}

enum SimklAPI {
  /// A session bound for a scope, as tests do:
  /// `SimklAPI.$scopedSession.withValue(session) { … }`. Optional on purpose: a
  /// task-local's default is built as soon as it's first touched, and the live
  /// session reads the Keychain.
  @TaskLocal static var scopedSession: SimklSession?

  /// The session requests run against.
  static var session: SimklSession { scopedSession ?? .shared }
}

/// The single owner of the Simkl credential.
///
/// It attaches the token as each request is sent, refreshes an AUTH V2 token a
/// day before it expires or when Simkl rejects it, and runs one refresh for any
/// number of concurrent requests: a refresh invalidates the previous access
/// token at once, so two independent refreshes would cut each other off.
actor SimklSession {
  static let shared = SimklSession.live()

  /// The state at launch, read synchronously so the first frame is right.
  nonisolated let initialSnapshot: SimklSessionSnapshot
  /// Why the Keychain couldn't be read at launch, for reporting once crash
  /// reporting has started (the session is built before it).
  nonisolated let initialLoadFailure: String?

  private let store: any SimklCredentialStore
  private let ownerStore: SimklLibraryOwnerStore?
  private let oauth: SimklOAuthClient
  private let now: @Sendable () -> Date
  private let mirrorsSyncAccount: Bool

  private var credential: SimklCredential?
  private var owner: SimklAccount?
  private var loadFailed = false
  private var refreshTask: Task<SimklCredential, any Error>?
  private var lastRefreshAt: Date?
  /// When Simkl last answered a refresh with an error other than `invalid_grant`.
  private var lastRefreshFailureAt: Date?
  private var continuations: [UUID: AsyncStream<SimklSessionSnapshot>.Continuation] = [:]
  private var snapshot: SimklSessionSnapshot {
    didSet { if snapshot != oldValue { publish() } }
  }

  /// A rejection this soon after a refresh is more likely a token that hasn't
  /// reached every Simkl region yet than a dead grant; don't refresh again.
  static let refreshCooldown: TimeInterval = 120

  /// After Simkl fails a refresh (an outage, a proxy's error page), wait this
  /// long before asking again, so the requests in between don't each start one.
  static let refreshRetryDelay: TimeInterval = 60

  init(
    store: any SimklCredentialStore,
    ownerStore: SimklLibraryOwnerStore? = nil,
    oauth: SimklOAuthClient = SimklOAuthClient(),
    now: @escaping @Sendable () -> Date = { Date() },
    mirrorsSyncAccount: Bool = false
  ) {
    self.store = store
    self.ownerStore = ownerStore
    self.oauth = oauth
    self.now = now
    self.mirrorsSyncAccount = mirrorsSyncAccount

    var owner = ownerStore?.load()
    var credential: SimklCredential?
    var loadFailed = false
    var loadFailure: String?
    do {
      credential = try store.load()
    } catch {
      // A Keychain that can't be read right now is not a signed-out person.
      loadFailed = true
      let nsError = error as NSError
      loadFailure = "\(nsError.domain) \(nsError.code)"
    }
    // Deleting the app clears UserDefaults but not the Keychain, so a sign-in
    // can outlive the note of whose library this is. Write the note again, so
    // a restore to a new iPhone still asks to reconnect.
    if owner == nil, let account = credential?.account {
      ownerStore?.save(account)
      owner = account
    }
    let status =
      loadFailed
      ? SimklSessionStatus.reconnectRequired(.credentialMissing, version: nil, account: owner)
      : Self.status(for: credential, owner: owner)
    let snapshot = SimklSessionSnapshot(
      status: status, accountSessionID: status == .signedOut ? nil : UUID(),
      dailyLimitResetsAt: nil)

    self.credential = credential
    self.owner = owner
    self.loadFailed = loadFailed
    self.snapshot = snapshot
    self.initialSnapshot = snapshot
    self.initialLoadFailure = loadFailure
    if mirrorsSyncAccount { SyncAccount.update(snapshot.accountSessionID) }
  }

  static func live() -> SimklSession {
    #if DEBUG
      // The screenshot harness runs offline against seeded fixtures. Its
      // sentinel credential never reaches the network or the Keychain.
      if ScreenshotMode.isActive {
        return SimklSession(
          store: SimklMemoryCredentialStore(.screenshot), mirrorsSyncAccount: true)
      }
    #endif
    return SimklSession(
      store: SimklKeychainCredentialStore(), ownerStore: SimklLibraryOwnerStore(),
      mirrorsSyncAccount: true)
  }

  // MARK: State

  var currentSnapshot: SimklSessionSnapshot { snapshot }

  func updates() -> AsyncStream<SimklSessionSnapshot> {
    let (stream, continuation) = AsyncStream.makeStream(
      of: SimklSessionSnapshot.self, bufferingPolicy: .bufferingNewest(1))
    let id = UUID()
    continuations[id] = continuation
    continuation.yield(snapshot)
    continuation.onTermination = { [weak self] _ in
      Task { await self?.removeContinuation(id) }
    }
    return stream
  }

  /// The account a sync may write for, or nil when syncing should wait: signed
  /// out, waiting to reconnect, or out of Simkl's daily allowance.
  func syncAccountID() -> UUID? {
    guard case .connected = snapshot.status else { return nil }
    if let reset = snapshot.dailyLimitResetsAt {
      guard reset <= now() else { return nil }
      snapshot.dailyLimitResetsAt = nil
    }
    return snapshot.accountSessionID
  }

  /// Whether an AUTH V1 sign-in still needs its account recorded, so a later
  /// reconnect can recognize the same person.
  var needsAccountBackfill: Bool {
    guard case .connected = snapshot.status, let credential else { return false }
    return credential.account == nil && owner == nil
  }

  func recordAccount(_ account: SimklAccount) {
    guard var credential else { return }
    owner = account
    ownerStore?.save(account)
    if credential.version == .v2, credential.account?.id == account.id || credential.account == nil
    {
      credential.account = account
      self.credential = credential
      persist(credential)
    }
    snapshot.status = Self.status(for: credential, owner: owner)
  }

  /// Simkl answered a request made with `token` with a spent daily allowance:
  /// hold syncing until it resets. Returns false, changing nothing, when
  /// `token` is no longer in use. A late answer for a credential that's since
  /// been replaced, such as AUTH V1's shared allowance after an upgrade, says
  /// nothing about the new one; if that allowance is spent too, the next
  /// request says so.
  @discardableResult
  func noteDailyLimit(retryAfter: TimeInterval?, token: String) -> Bool {
    guard credential?.accessToken == token else { return false }
    let current = now()
    snapshot.dailyLimitResetsAt =
      retryAfter.map { current.addingTimeInterval(max(60, $0)) }
      ?? SimklDailyLimit.nextReset(after: current)
    return true
  }

  /// Try the Keychain again after a launch that couldn't read it.
  func reloadIfNeeded() {
    guard loadFailed else { return }
    do {
      credential = try store.load()
      loadFailed = false
      var next = snapshot
      next.status = Self.status(for: credential, owner: owner)
      next.accountSessionID = next.status == .signedOut ? nil : (next.accountSessionID ?? UUID())
      snapshot = next
    } catch {
      // Still locked; the next activation tries again.
    }
  }

  // MARK: Requests

  /// Identifies the app on Simkl's API and, for `.user` requests, attaches the
  /// person's access token, refreshing it first when it's about to expire.
  ///
  /// A `.user` request belongs to one account: `account` when given (a retry,
  /// or a sync's own), otherwise whoever is signed in now. If another account
  /// has replaced it, the request is cancelled rather than sent with that
  /// account's token, including after waiting on a refresh.
  func prepare(_ request: URLRequest, account pinned: UUID? = nil) async throws
    -> PreparedSimklRequest
  {
    let isSimklAPI = request.url?.host?.lowercased() == "api.simkl.com"
    guard request.simklAuth == .user else {
      return PreparedSimklRequest(
        request: isSimklAPI ? prepareSimklRequest(request, client: .anonymous) : request,
        token: nil, refreshesOnUnauthorized: false)
    }

    let account = pinned ?? snapshot.accountSessionID
    guard snapshot.accountSessionID == account else { throw CancellationError() }
    let credential = try await usableCredential()
    guard snapshot.accountSessionID == account else { throw CancellationError() }
    var prepared = isSimklAPI ? prepareSimklRequest(request, client: credential.client) : request
    prepared.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
    return PreparedSimklRequest(
      request: prepared, token: credential.accessToken, account: account,
      refreshesOnUnauthorized: isSimklAPI)
  }

  /// Simkl rejected `token` with a 401. Returns when a retry can work: another
  /// request already refreshed, or this one just did. Throws when it can't.
  func recover(afterUnauthorized token: String, account: UUID?) async throws {
    // Signed out or switched accounts while this request was out: it belonged
    // to the previous account, so it must not be retried as the new one.
    guard snapshot.accountSessionID == account else { throw CancellationError() }
    guard let credential else { throw SimklAuthError.signedOut }
    if case .reconnectRequired(let reason, _, _) = snapshot.status {
      throw SimklAuthError.reconnectRequired(reason)
    }
    // Replaced while this request was in flight: retry with the new token.
    guard credential.accessToken == token else { return }
    guard credential.canRefresh else {
      // AUTH V1 tokens never expire on their own; a 401 means Simkl ended it.
      let reason: SimklReconnectReason =
        credential.version == .v1 ? .legacySignInEnded : .signInEnded
      invalidate(credential, reason: reason)
      throw SimklAuthError.reconnectRequired(reason)
    }
    if refreshTask == nil, let lastRefreshAt,
      now().timeIntervalSince(lastRefreshAt) < Self.refreshCooldown
    {
      throw SimklAuthError.temporarilyRejected
    }
    if refreshTask == nil, isWaitingToRetryRefresh { throw SimklAuthError.temporarilyRejected }
    _ = try await refreshed(from: credential)
  }

  /// Simkl failed a refresh moments ago; asking again right away won't help.
  private var isWaitingToRetryRefresh: Bool {
    guard let lastRefreshFailureAt else { return false }
    return now().timeIntervalSince(lastRefreshFailureAt) < Self.refreshRetryDelay
  }

  private func usableCredential() async throws -> SimklCredential {
    if case .reconnectRequired(let reason, _, _) = snapshot.status {
      throw SimklAuthError.reconnectRequired(reason)
    }
    guard let credential else { throw SimklAuthError.signedOut }
    guard credential.needsRefresh(at: now()) else { return credential }
    if refreshTask == nil, isWaitingToRetryRefresh {
      // A token that hasn't expired still works until Simkl can refresh it.
      if !credential.isExpired(at: now()) { return credential }
      throw SimklAuthError.temporarilyRejected
    }
    do {
      return try await refreshed(from: credential)
    } catch SimklAuthError.reconnectRequired(let reason) {
      throw SimklAuthError.reconnectRequired(reason)
    } catch {
      // Couldn't refresh right now. A token that hasn't expired still works.
      if !credential.isExpired(at: now()) { return credential }
      throw error
    }
  }

  /// One refresh, however many requests ask for it at once.
  private func refreshed(from current: SimklCredential) async throws -> SimklCredential {
    if let refreshTask { return try await refreshTask.value }
    if let credential, credential.accessToken != current.accessToken { return credential }
    let task = Task { try await self.performRefresh(current) }
    refreshTask = task
    defer { refreshTask = nil }
    return try await task.value
  }

  private func performRefresh(_ current: SimklCredential) async throws -> SimklCredential {
    let fresh: SimklCredential
    do {
      fresh = try await oauth.refresh(current)
    } catch let error as SimklOAuthError {
      // Signed out, or a new sign-in replaced the credential, while waiting:
      // this grant no longer matters, and requests should use the current one.
      if let credential, credential.accessToken != current.accessToken { return credential }
      guard credential != nil else { throw SimklAuthError.signedOut }
      // Only `invalid_grant` means the grant is gone: revoked in Connected Apps,
      // or unused for 180 days. Anything else (a proxy's error page, a body that
      // won't parse, our own bad request) leaves a refresh token that may still
      // work, so keep it and let a later request try again.
      guard error.code == "invalid_grant" else {
        lastRefreshFailureAt = now()
        reportError(error)
        throw SimklAuthError.temporarilyRejected
      }
      invalidate(current, reason: .signInEnded)
      throw SimklAuthError.reconnectRequired(.signInEnded)
    }
    // Signed out, or a new sign-in replaced the credential, while waiting.
    guard credential?.accessToken == current.accessToken else {
      if let credential { return credential }
      throw SimklAuthError.signedOut
    }
    lastRefreshAt = now()
    lastRefreshFailureAt = nil
    credential = fresh
    persist(fresh)
    SimklAuthTelemetry.breadcrumb("Refreshed Simkl access token")
    return fresh
  }

  // MARK: Sign-in and sign-out

  /// Saves a credential from a completed sign-in. `keepingLibrary` is true only
  /// when it's the same account whose library is on this device.
  func install(_ new: SimklCredential, keepingLibrary: Bool) throws {
    let previous = credential
    try store.save(new)
    credential = new
    loadFailed = false
    lastRefreshAt = nil
    lastRefreshFailureAt = nil
    if let account = new.account {
      owner = account
      ownerStore?.save(account)
    }
    var next = snapshot
    next.status = Self.status(for: new, owner: owner)
    if !keepingLibrary || next.accountSessionID == nil { next.accountSessionID = UUID() }
    // A new sign-in can bring its own allowance: AUTH V1 shares one across the
    // app, while V2 counts per person. If it's spent too, the next request says so.
    next.dailyLimitResetsAt = nil
    snapshot = next
    SimklAuthTelemetry.breadcrumb("Installed Simkl \(new.version.rawValue) sign-in")

    // Every AUTH V2 sign-in is its own grant; end the one this replaces.
    if let previous, previous.version == .v2, let token = previous.refreshToken,
      token != new.refreshToken
    {
      let oauth = self.oauth
      Task { await oauth.revoke(token) }
    }
  }

  /// Forgets the credential, then ends its grant in the background. Simkl
  /// answers 200 whether or not the token still worked, so there's nothing to
  /// wait for or check.
  func signOut() {
    let previous = credential
    credential = nil
    owner = nil
    loadFailed = false
    lastRefreshAt = nil
    lastRefreshFailureAt = nil
    do {
      try store.delete()
    } catch {
      reportError(error)
    }
    ownerStore?.clear()
    snapshot = SimklSessionSnapshot(
      status: .signedOut, accountSessionID: nil, dailyLimitResetsAt: nil)
    SimklAuthTelemetry.breadcrumb("Signed out of Simkl")

    if let previous, previous.version == .v2, let token = previous.refreshToken {
      let oauth = self.oauth
      Task { await oauth.revoke(token) }
    }
  }

  // MARK: Helpers

  private func invalidate(_ current: SimklCredential, reason: SimklReconnectReason) {
    var dead = current
    dead.invalidatedAt = now()
    credential = dead
    persist(dead)
    snapshot.status = .reconnectRequired(
      reason, version: dead.version, account: dead.account ?? owner)
    SimklAuthTelemetry.breadcrumb("Simkl sign-in needs reconnecting: \(reason.rawValue)")
  }

  /// A failed write keeps the in-memory credential. The refresh token doesn't
  /// rotate, so the copy already saved can still refresh after a relaunch.
  private func persist(_ credential: SimklCredential) {
    do {
      try store.save(credential)
    } catch {
      reportError(error)
    }
  }

  private func publish() {
    if mirrorsSyncAccount { SyncAccount.update(snapshot.accountSessionID) }
    SimklAuthTelemetry.record(snapshot)
    for continuation in continuations.values { continuation.yield(snapshot) }
  }

  private func removeContinuation(_ id: UUID) {
    continuations[id] = nil
  }

  static func status(for credential: SimklCredential?, owner: SimklAccount?)
    -> SimklSessionStatus
  {
    guard let credential else {
      // A library on this device with no sign-in: reconnect, don't start over.
      return owner == nil
        ? .signedOut : .reconnectRequired(.credentialMissing, version: nil, account: owner)
    }
    let account = credential.account ?? owner
    if credential.invalidatedAt != nil {
      return .reconnectRequired(
        credential.version == .v1 ? .legacySignInEnded : .signInEnded,
        version: credential.version, account: account)
    }
    guard credential.canWrite else {
      return .reconnectRequired(
        .missingWriteAccess, version: credential.version, account: account)
    }
    return .connected(version: credential.version, account: account)
  }
}

extension SimklCredential {
  #if DEBUG
    /// The screenshot harness's sign-in: AUTH V2, so no upgrade prompt appears.
    static let screenshot = SimklCredential(
      version: .v2, accessToken: ScreenshotMode.sentinelToken, scope: "media:read media:write",
      account: SimklAccount(id: 0, name: "Simalytics"))
  #endif
}

/// Simkl's daily allowance resets at midnight US Eastern for everyone.
enum SimklDailyLimit {
  static func nextReset(after date: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar.nextDate(
      after: date, matching: DateComponents(hour: 0, minute: 0, second: 0),
      matchingPolicy: .nextTime) ?? date.addingTimeInterval(24 * 60 * 60)
  }

  /// "about 6 hours", for a reset that's still ahead.
  static func remainingDescription(until reset: Date, from now: Date) -> String {
    let hours = Int((reset.timeIntervalSince(now) / 3600).rounded(.up))
    if hours <= 1 { return "within the hour" }
    return "in about \(hours) hours"
  }
}

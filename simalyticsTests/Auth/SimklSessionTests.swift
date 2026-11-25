import Foundation
import Testing
import os

@testable import Simalytics

/// Everything that crosses the network through `SimklHTTPStub`, serialized
/// because the stub has one handler.
@Suite("Simkl sign-in over HTTP", .serialized)
@MainActor
struct SimklSessionTests {
  private let clock = SimklTestClock()

  private func makeSession(
    _ credential: SimklCredential?, transport: URLSession, owner: SimklAccount? = nil
  ) -> (SimklSession, SimklMemoryCredentialStore) {
    let store = SimklMemoryCredentialStore(credential)
    let ownerStore = SimklLibraryOwnerStore(suiteName: "simkl-owner-\(UUID())")
    if let owner { ownerStore.save(owner) }
    let clock = self.clock
    let oauth = SimklOAuthClient(client: .v2, transport: transport, now: { clock.now })
    let session = SimklSession(
      store: store, ownerStore: ownerStore, oauth: oauth, now: { clock.now })
    return (session, store)
  }

  private func v2(
    _ token: String = "simkl_at_OLD", expiresIn: TimeInterval = 5 * 24 * 60 * 60
  ) -> SimklCredential {
    SimklCredential(
      version: .v2, accessToken: token, refreshToken: "simkl_rt_R",
      accessTokenExpiresAt: clock.now.addingTimeInterval(expiresIn),
      scope: "media:read media:write", account: SimklAccount(id: 7, name: "pat"))
  }

  nonisolated private static func tokenResponse(
    _ access: String, scope: String = "media:read media:write"
  )
    -> SimklHTTPStub.Response
  {
    .json(
      200,
      #"{"access_token":"\#(access)","token_type":"Bearer","expires_in":604800,"refresh_token":"simkl_rt_R","scope":"\#(scope)"}"#
    )
  }

  private func userRequest(_ path: String = "sync/activities") -> URLRequest {
    var request = URLRequest(url: simklAPIURL(path: path))
    request.simklAuth = .user
    return request
  }

  private func send(_ request: URLRequest, on session: SimklSession, using transport: URLSession)
    async throws -> Int
  {
    try await SimklAPI.$scopedSession.withValue(session) {
      let (_, response) = try await transport.simklData(for: request)
      return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
  }

  // MARK: Identifying the app

  @Test("Catalog requests carry the V2 client ID and never a token")
  func anonymousRequest() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(SimklCredential(version: .v1, accessToken: "v1hex"), transport: transport)
    var request = URLRequest(
      url: URL(string: "https://api.simkl.com/movies/1?extended=full&client_id=stale")!)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let prepared = try await session.prepare(request)
    let query = SimklHTTPStub.Request(
      method: "GET", url: prepared.request.url!, headers: [:], body: Data()
    ).query
    #expect(query["client_id"] == SimklClient.v2.clientID)
    #expect(query["app-name"] == "simalytics-ios")
    #expect(query["extended"] == "full")
    #expect(prepared.request.value(forHTTPHeaderField: "simkl-api-key") == SimklClient.v2.clientID)
    #expect(prepared.request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(prepared.token == nil)
  }

  @Test(
    "A token always travels with its own registration's client ID",
    arguments: [SimklAuthVersion.v1, .v2])
  func clientIDMatchesToken(version: SimklAuthVersion) async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let credential =
      version == .v1 ? SimklCredential(version: .v1, accessToken: "v1hex") : v2("simkl_at_A")
    let (session, _) = makeSession(credential, transport: transport)
    let prepared = try await session.prepare(userRequest())
    let expected = SimklClient.client(for: version).clientID
    let query = URLComponents(url: prepared.request.url!, resolvingAgainstBaseURL: false)!
      .queryItems!
    #expect(query.filter { $0.name == "client_id" }.map(\.value) == [expected])
    #expect(prepared.request.value(forHTTPHeaderField: "simkl-api-key") == expected)
    #expect(
      prepared.request.value(forHTTPHeaderField: "Authorization")
        == "Bearer \(credential.accessToken)")
    #expect(prepared.refreshesOnUnauthorized)
  }

  @Test("The Simalytics backend gets the token but no Simkl parameters, and no refresh on 401")
  func backendRequest() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(v2("simkl_at_A"), transport: transport)
    var request = URLRequest(url: URL(string: "https://api.simalytics.kyter.com/tmdb-credits")!)
    request.simklAuth = .user
    let prepared = try await session.prepare(request)
    #expect(prepared.request.url?.query == nil)
    #expect(prepared.request.value(forHTTPHeaderField: "Authorization") == "Bearer simkl_at_A")
    #expect(!prepared.refreshesOnUnauthorized)
  }

  @Test("A user request without a sign-in fails before reaching the network")
  func signedOut() async {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(nil, transport: transport)
    await #expect(throws: SimklAuthError.signedOut) {
      _ = try await session.prepare(userRequest())
    }
    #expect(SimklHTTPStub.log.isEmpty)
  }

  // MARK: Refresh

  @Test("A token within a day of expiring is refreshed before it's sent")
  func proactiveRefresh() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token" ? Self.tokenResponse("simkl_at_NEW") : .json(200, "{}")
    }
    let (session, store) = makeSession(v2(expiresIn: 60 * 60), transport: transport)
    let prepared = try await session.prepare(userRequest())
    #expect(prepared.token == "simkl_at_NEW")
    let refresh = try #require(SimklHTTPStub.requests(to: "/oauth2/token").first)
    #expect(refresh.method == "POST")
    #expect(refresh.header("Content-Type") == "application/x-www-form-urlencoded")
    #expect(
      refresh.form == [
        "grant_type": "refresh_token", "client_id": SimklClient.v2.clientID,
        "refresh_token": "simkl_rt_R",
      ])
    #expect(store.saved?.accessToken == "simkl_at_NEW")
    #expect(store.saved?.account?.id == 7)
  }

  @Test("Offline, a token that hasn't expired is still used; an expired one fails")
  func refreshWhileOffline() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token" ? .failure(.notConnectedToInternet) : .json(200, "{}")
    }
    let (soon, _) = makeSession(v2(expiresIn: 60 * 60), transport: transport)
    #expect(try await soon.prepare(userRequest()).token == "simkl_at_OLD")

    let (expired, store) = makeSession(v2(expiresIn: -60), transport: transport)
    await #expect(throws: URLError.self) { _ = try await expired.prepare(userRequest()) }
    // A connection problem never ends the sign-in.
    #expect(store.saved?.invalidatedAt == nil)
    #expect(await expired.currentSnapshot.status == .connected(version: .v2, account: SimklAccount(id: 7, name: "pat")))
  }

  @Test("Concurrent 401s share one refresh, and every request is retried with the new token")
  func singleFlightRefresh() async throws {
    let transport = SimklHTTPStub.session { request in
      if request.path == "/oauth2/token" {
        Thread.sleep(forTimeInterval: 0.05)
        return Self.tokenResponse("simkl_at_NEW")
      }
      return request.bearer == "simkl_at_NEW"
        ? .json(200, "{}") : .json(401, #"{"error":"invalid_token","code":401}"#)
    }
    let (session, _) = makeSession(v2(), transport: transport)
    let request = userRequest()
    let statuses = try await SimklAPI.$scopedSession.withValue(session) {
      try await withThrowingTaskGroup(of: Int.self) { group in
        for _ in 0..<8 {
          group.addTask {
            let (_, response) = try await transport.simklData(for: request)
            return (response as? HTTPURLResponse)?.statusCode ?? 0
          }
        }
        var statuses: [Int] = []
        for try await status in group { statuses.append(status) }
        return statuses
      }
    }
    #expect(statuses == Array(repeating: 200, count: 8))
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 1)
  }

  @Test("A request that raced a refresh retries with the new token without refreshing again")
  func staleTokenRetries() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token" ? Self.tokenResponse("simkl_at_NEW") : .json(200, "{}")
    }
    let (session, _) = makeSession(v2(expiresIn: 60), transport: transport)
    _ = try await session.prepare(userRequest())  // Refreshes proactively.
    let account = await session.currentSnapshot.accountSessionID
    try await session.recover(afterUnauthorized: "simkl_at_OLD", account: account)
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 1)
  }

  @Test("A refused refresh ends the sign-in, keeps the library, and stops asking")
  func refusedRefresh() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token"
        ? .json(400, #"{"error":"invalid_grant","error_description":"Refresh token revoked"}"#)
        : .json(401, #"{"error":"invalid_token","code":401}"#)
    }
    let (session, store) = makeSession(v2(), transport: transport)
    let id = await session.currentSnapshot.accountSessionID
    await #expect(throws: SimklAuthError.reconnectRequired(.signInEnded)) {
      _ = try await send(userRequest(), on: session, using: transport)
    }
    let snapshot = await session.currentSnapshot
    #expect(
      snapshot.status
        == .reconnectRequired(.signInEnded, version: .v2, account: SimklAccount(id: 7, name: "pat")))
    #expect(snapshot.accountSessionID == id)
    #expect(store.saved?.invalidatedAt != nil)
    #expect(await session.syncAccountID() == nil)

    // A relaunch remembers it and doesn't ask Simkl again.
    let relaunched = SimklSession(store: store)
    #expect(
      relaunched.initialSnapshot.status
        == .reconnectRequired(.signInEnded, version: .v2, account: SimklAccount(id: 7, name: "pat")))
    let before = SimklHTTPStub.log.count
    await #expect(throws: SimklAuthError.reconnectRequired(.signInEnded)) {
      _ = try await relaunched.prepare(userRequest())
    }
    #expect(SimklHTTPStub.log.count == before)
  }

  @Test("Only invalid_grant ends the sign-in; other refresh failures leave it usable")
  func refreshFailuresThatAreNotFinal() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token"
        ? SimklHTTPStub.Response(
          status: 403, headers: ["Content-Type": "text/html"], body: Data("<html>blocked</html>".utf8))
        : .json(200, "{}")
    }
    // Still valid for an hour: the request goes out with the current token.
    let (soon, soonStore) = makeSession(v2(expiresIn: 60 * 60), transport: transport)
    #expect(try await soon.prepare(userRequest()).token == "simkl_at_OLD")
    #expect(soonStore.saved?.invalidatedAt == nil)

    // Already expired: this request fails for now, and the sign-in survives.
    let (expired, expiredStore) = makeSession(v2(expiresIn: -60), transport: transport)
    await #expect(throws: SimklAuthError.temporarilyRejected) {
      _ = try await expired.prepare(userRequest())
    }
    #expect(expiredStore.saved?.invalidatedAt == nil)
    #expect(await expired.syncAccountID() != nil)
  }

  @Test("A request is never retried as a different account")
  func retryStaysWithItsAccount() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(v2(), transport: transport)
    let original = await session.currentSnapshot.accountSessionID
    var other = v2("simkl_at_B")
    other.refreshToken = "simkl_rt_B"
    other.account = SimklAccount(id: 8)
    try await session.install(other, keepingLibrary: false)
    await #expect(throws: CancellationError.self) {
      try await session.recover(afterUnauthorized: "simkl_at_OLD", account: original)
    }
  }

  /// A second Simkl account's sign-in, for switching to.
  private func otherAccount() -> SimklCredential {
    var other = v2("simkl_at_B")
    other.refreshToken = "simkl_rt_B"
    other.account = SimklAccount(id: 8, name: "sam")
    return other
  }

  @Test("A request goes out only for the account it belongs to")
  func pinnedAccount() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(v2(), transport: transport)
    await #expect(throws: CancellationError.self) {
      _ = try await session.prepare(userRequest(), account: UUID())
    }
    let current = await session.currentSnapshot.accountSessionID
    #expect(try await session.prepare(userRequest(), account: current).account == current)
  }

  @Test("A sign-in that lands during a refresh doesn't lend its token to waiting requests")
  func accountSwitchDuringRefresh() async throws {
    let released = OSAllocatedUnfairLock(initialState: false)
    let transport = SimklHTTPStub.session { request in
      guard request.path == "/oauth2/token" else { return .json(200, "{}") }
      // Hold the refresh open until the other account has signed in.
      var waited = 0
      while !released.withLock({ $0 }), waited < 500 {
        Thread.sleep(forTimeInterval: 0.01)
        waited += 1
      }
      return Self.tokenResponse("simkl_at_NEW")
    }
    let (session, _) = makeSession(v2(expiresIn: 60 * 60), transport: transport)
    let request = userRequest()
    let waiting = Task { try await session.prepare(request) }
    #expect(await eventually { !SimklHTTPStub.requests(to: "/oauth2/token").isEmpty })
    try await session.install(otherAccount(), keepingLibrary: false)
    released.withLock { $0 = true }
    await #expect(throws: CancellationError.self) { _ = try await waiting.value }
  }

  @Test("A retry is never sent for an account that replaced the one it started with")
  func retryAfterAccountSwitch() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/sync/activities" ? .json(503, "{}") : .json(200, "{}")
    }
    let (session, _) = makeSession(v2(), transport: transport)
    let request = userRequest()
    let attempt = Task {
      try await SimklAPI.$scopedSession.withValue(session) {
        _ = try await performSimklRequest(request, session: transport)
      }
    }
    // The first attempt fails; another account signs in while it waits to retry.
    #expect(await eventually { SimklHTTPStub.requests(to: "/sync/activities").count == 1 })
    try await session.install(otherAccount(), keepingLibrary: false)
    await #expect(throws: CancellationError.self) { try await attempt.value }
    #expect(SimklHTTPStub.requests(to: "/sync/activities").count == 1)
  }

  @Test("A sync sends requests only for the account it started with")
  func syncRequestsStayWithTheirAccount() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(v2(), transport: transport)
    // A sync that began for an account another sign-in has since replaced.
    _ = await sendDuringSync(userRequest(), account: UUID(), session: session, transport: transport)
    #expect(SimklHTTPStub.requests(to: "/sync/activities").isEmpty)

    let current = try #require(await session.currentSnapshot.accountSessionID)
    _ = await sendDuringSync(userRequest(), account: current, session: session, transport: transport)
    #expect(SimklHTTPStub.requests(to: "/sync/activities").count == 1)
  }

  @Test("A new sign-in starts with a fresh daily allowance")
  func installClearsDailyLimit() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "") }
    let (session, _) = makeSession(
      SimklCredential(version: .v1, accessToken: "v1hex"), transport: transport,
      owner: SimklAccount(id: 7))
    await session.noteDailyLimit(retryAfter: 3600, token: "v1hex")
    #expect(await session.syncAccountID() == nil)
    var upgraded = v2()
    upgraded.account = SimklAccount(id: 7)
    try await session.install(upgraded, keepingLibrary: true)
    #expect(await session.syncAccountID() != nil)
  }

  @Test("A rejected AUTH V1 token asks to reconnect without trying to refresh")
  func legacyRejected() async {
    let transport = SimklHTTPStub.session { _ in
      .json(401, #"{"error":"user_token_failed","code":401}"#)
    }
    let (session, _) = makeSession(
      SimklCredential(version: .v1, accessToken: "v1hex"), transport: transport)
    await #expect(throws: SimklAuthError.reconnectRequired(.legacySignInEnded)) {
      _ = try await send(userRequest(), on: session, using: transport)
    }
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").isEmpty)
  }

  @Test("A missing-token 401 is a bug to report, not a reason to refresh")
  func userTokenRequired() async throws {
    let transport = SimklHTTPStub.session { _ in
      .json(401, #"{"error":"user_token_required","code":401}"#)
    }
    let (session, _) = makeSession(v2(), transport: transport)
    #expect(try await send(userRequest(), on: session, using: transport) == 401)
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").isEmpty)
    #expect(await session.syncAccountID() != nil)
  }

  @Test("A token rejected right after a refresh isn't refreshed again until a cooldown")
  func refreshCooldown() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token"
        ? Self.tokenResponse("simkl_at_NEW")
        : .json(401, #"{"error":"invalid_token","code":401}"#)
    }
    let (session, _) = makeSession(v2(), transport: transport)
    await #expect(throws: SimklAuthError.temporarilyRejected) {
      _ = try await send(userRequest(), on: session, using: transport)
    }
    await #expect(throws: SimklAuthError.temporarilyRejected) {
      _ = try await send(userRequest(), on: session, using: transport)
    }
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 1)
    #expect(await session.syncAccountID() != nil)

    clock.advance(SimklSession.refreshCooldown + 1)
    await #expect(throws: SimklAuthError.temporarilyRejected) {
      _ = try await send(userRequest(), on: session, using: transport)
    }
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 2)
  }

  @Test("After Simkl fails a refresh, requests keep the current token instead of each asking again")
  func failedRefreshWaitsBeforeRetrying() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token"
        ? .json(503, #"{"error":"temporarily_unavailable"}"#) : .json(200, "{}")
    }
    let (session, store) = makeSession(v2(expiresIn: 60 * 60), transport: transport)
    for _ in 0..<3 {
      #expect(try await session.prepare(userRequest()).token == "simkl_at_OLD")
    }
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 1)
    #expect(store.saved?.invalidatedAt == nil)

    clock.advance(SimklSession.refreshRetryDelay + 1)
    _ = try await session.prepare(userRequest())
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 2)
  }

  @Test("An expired token fails fast while a failed refresh waits")
  func expiredTokenWaitsAfterFailedRefresh() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token" ? .json(500, "{}") : .json(200, "{}")
    }
    let (session, _) = makeSession(v2(expiresIn: -60), transport: transport)
    for _ in 0..<2 {
      await #expect(throws: SimklAuthError.temporarilyRejected) {
        _ = try await session.prepare(userRequest())
      }
    }
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 1)
  }

  @Test("A rejected token doesn't ask Simkl again while a failed refresh waits")
  func unauthorizedWaitsAfterFailedRefresh() async throws {
    let transport = SimklHTTPStub.session { request in
      request.path == "/oauth2/token"
        ? .json(500, "{}") : .json(401, #"{"error":"invalid_token","code":401}"#)
    }
    let (session, store) = makeSession(v2(), transport: transport)
    for _ in 0..<2 {
      await #expect(throws: SimklAuthError.temporarilyRejected) {
        _ = try await send(userRequest(), on: session, using: transport)
      }
    }
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").count == 1)
    #expect(store.saved?.invalidatedAt == nil)
    #expect(await session.syncAccountID() != nil)
  }

  // MARK: Sign-in lifecycle

  @Test("Signing out forgets the credential and revokes its grant")
  func signOutRevokes() async {
    let transport = SimklHTTPStub.session { _ in .json(200, "") }
    let (session, store) = makeSession(v2(), transport: transport)
    await session.signOut()
    #expect(store.saved == nil)
    #expect(await session.currentSnapshot == SimklSessionSnapshot(status: .signedOut))
    #expect(
      await eventually { !SimklHTTPStub.requests(to: "/oauth2/revoke").isEmpty })
    let revoke = SimklHTTPStub.requests(to: "/oauth2/revoke").first
    #expect(revoke?.form == ["client_id": SimklClient.v2.clientID, "token": "simkl_rt_R"])
  }

  @Test("A sign-in that outlived a reinstall notes whose library this is again")
  func ownerNotedAgainAfterReinstall() {
    let ownerStore = SimklLibraryOwnerStore(suiteName: "simkl-owner-\(UUID())")
    // Reinstalled: the Keychain kept the sign-in, UserDefaults lost the note.
    _ = SimklSession(store: SimklMemoryCredentialStore(v2()), ownerStore: ownerStore)
    #expect(ownerStore.load() == SimklAccount(id: 7, name: "pat"))
    // Later restored to a new iPhone, which gets the note but not the sign-in.
    let restored = SimklSession(store: SimklMemoryCredentialStore(nil), ownerStore: ownerStore)
    #expect(
      restored.initialSnapshot.status
        == .reconnectRequired(
          .credentialMissing, version: nil, account: SimklAccount(id: 7, name: "pat")))
  }

  @Test("Reconnecting as the same account keeps the library; another account replaces it")
  func installKeepsOrReplaces() async {
    let transport = SimklHTTPStub.session { _ in .json(200, "") }
    let (session, store) = makeSession(
      SimklCredential(version: .v1, accessToken: "v1hex"), transport: transport,
      owner: SimklAccount(id: 7, name: "pat"))
    let original = await session.currentSnapshot.accountSessionID

    var upgraded = v2("simkl_at_A")
    upgraded.refreshToken = "simkl_rt_A"
    try? await session.install(upgraded, keepingLibrary: true)
    #expect(await session.currentSnapshot.accountSessionID == original)
    #expect(store.saved?.version == .v2)
    // Replacing a V1 token has no grant to revoke.
    #expect(SimklHTTPStub.requests(to: "/oauth2/revoke").isEmpty)

    var other = v2("simkl_at_B")
    other.refreshToken = "simkl_rt_B"
    other.account = SimklAccount(id: 8, name: "sam")
    try? await session.install(other, keepingLibrary: false)
    #expect(await session.currentSnapshot.accountSessionID != original)
    // The replaced V2 grant is ended.
    #expect(
      await eventually {
        SimklHTTPStub.requests(to: "/oauth2/revoke").first?.form["token"] == "simkl_rt_A"
      })
  }

  // MARK: Limits

  @Test("A spent daily allowance isn't retried and pauses syncing until it resets")
  func dailyLimit() async throws {
    let transport = SimklHTTPStub.session { _ in
      .json(
        429, #"{"error":"user_limit_exceeded","code":429}"#, headers: ["Retry-After": "3600"])
    }
    let (session, _) = makeSession(v2(), transport: transport)
    await #expect(throws: SimklMutationError.self) {
      try await SimklAPI.$scopedSession.withValue(session) {
        _ = try await performSimklRequest(userRequest(), session: transport)
      }
    }
    #expect(SimklHTTPStub.requests(to: "/sync/activities").count == 1)
    #expect(
      await session.currentSnapshot.dailyLimitResetsAt == clock.now.addingTimeInterval(3600))
    #expect(await session.syncAccountID() == nil)
    clock.advance(3601)
    #expect(await session.syncAccountID() != nil)
  }

  @Test("A daily limit for a sign-in that's since been replaced doesn't pause the new one")
  func staleDailyLimitIgnored() async throws {
    let transport = SimklHTTPStub.session { _ in .json(200, "{}") }
    let (session, _) = makeSession(
      SimklCredential(version: .v1, accessToken: "v1hex"), transport: transport,
      owner: SimklAccount(id: 7))
    var upgraded = v2()
    upgraded.account = SimklAccount(id: 7)
    try await session.install(upgraded, keepingLibrary: true)
    // An AUTH V1 request still in flight comes back with V1's spent allowance.
    #expect(await session.noteDailyLimit(retryAfter: 3600, token: "v1hex") == false)
    #expect(await session.syncAccountID() != nil)
    #expect(await session.noteDailyLimit(retryAfter: 3600, token: upgraded.accessToken))
    #expect(await session.syncAccountID() == nil)
  }

  @Test("A spent daily allowance ends a running sync")
  func dailyLimitEndsSync() async throws {
    let transport = SimklHTTPStub.session { _ in
      .json(
        429, #"{"error":"user_limit_exceeded","code":429}"#, headers: ["Retry-After": "3600"])
    }
    let (session, _) = makeSession(v2(), transport: transport)
    let account = try #require(await session.currentSnapshot.accountSessionID)
    let outcome = await sendDuringSync(
      userRequest(), account: account, session: session, transport: transport)
    #expect(outcome == .dailyLimitReached)
  }

  @Test("The per-second limit is retried")
  func burstLimit() async throws {
    let calls = OSAllocatedUnfairLock(initialState: 0)
    let transport = SimklHTTPStub.session { _ in
      let call = calls.withLock { value -> Int in
        value += 1
        return value
      }
      return call == 1 ? .json(429, #"{"error":"rate_limit","code":429}"#) : .json(200, "{}")
    }
    let (session, _) = makeSession(v2(), transport: transport)
    let (_, response) = try await SimklAPI.$scopedSession.withValue(session) {
      try await performSimklRequest(userRequest(), session: transport)
    }
    #expect(response.statusCode == 200)
    #expect(SimklHTTPStub.requests(to: "/sync/activities").count == 2)
  }

  // MARK: Signing in through Auth

  nonisolated private static let iss = "iss=https%3A%2F%2Fsimkl.com"

  private struct Approval: Sendable {
    var code = "good"
    var forgedState: String?
  }

  /// Plays Simkl's consent page: approves and redirects back with a code.
  private func approve(_ approval: Approval = Approval(), challenge: OSAllocatedUnfairLock<String?>)
    -> SimklSignInFlow.Authenticate
  {
    { url in
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      let state = items.first { $0.name == "state" }?.value ?? ""
      challenge.withLock { $0 = items.first { $0.name == "code_challenge" }?.value }
      return URL(
        string:
          "simalytics://auth/simkl?code=\(approval.code)&state=\(approval.forgedState ?? state)&\(Self.iss)"
      )!
    }
  }

  private func simklServer(accountID: Int) -> URLSession {
    SimklHTTPStub.session { request in
      switch request.path {
      case "/oauth2/token":
        guard request.form["code"] != "readonly" else {
          return Self.tokenResponse("simkl_at_RO", scope: "media:read")
        }
        return Self.tokenResponse("simkl_at_NEW")
      case "/users/settings":
        return request.bearer == "simkl_at_NEW"
          ? .json(200, #"{"user":{"name":"user\#(accountID)"},"account":{"id":\#(accountID),"type":"vip"}}"#)
          : .json(401, #"{"error":"invalid_token","code":401}"#)
      default:
        return .json(200, "")
      }
    }
  }

  private func makeAuth(
    _ credential: SimklCredential?, owner: SimklAccount? = nil, transport: URLSession
  ) -> (Auth, SimklSession, SimklMemoryCredentialStore) {
    let (session, store) = makeSession(credential, transport: transport, owner: owner)
    let clock = self.clock
    let auth = Auth(
      session: session, oauth: SimklOAuthClient(client: .v2, transport: transport, now: { clock.now }))
    return (auth, session, store)
  }

  @Test("A first sign-in exchanges the code with PKCE and saves a V2 credential")
  func freshSignIn() async throws {
    let transport = simklServer(accountID: 7)
    let (auth, session, store) = makeAuth(nil, transport: transport)
    let challenge = OSAllocatedUnfairLock<String?>(initialState: nil)
    var resets = 0
    await auth.signIn(authenticate: approve(challenge: challenge), resetLibrary: { resets += 1 })

    #expect(auth.signInError == nil)
    #expect(auth.connectionGeneration == 1)
    #expect(store.saved?.version == .v2)
    #expect(store.saved?.account == SimklAccount(id: 7, name: "user7"))
    #expect(
      await session.currentSnapshot.status
        == .connected(version: .v2, account: SimklAccount(id: 7, name: "user7")))
    #expect(await eventually { auth.isConnected })

    let exchange = try #require(SimklHTTPStub.requests(to: "/oauth2/token").first)
    #expect(exchange.form["grant_type"] == "authorization_code")
    #expect(exchange.form["client_id"] == SimklClient.v2.clientID)
    #expect(exchange.form["code"] == "good")
    #expect(exchange.form["redirect_uri"] == "simalytics://auth/simkl")
    #expect(exchange.form["client_secret"] == nil)
    let verifier = try #require(exchange.form["code_verifier"])
    // The verifier proves this app started the sign-in the code came from.
    #expect(SimklPKCE.challenge(for: verifier) == challenge.withLock { $0 })
    #expect(resets == 1)
  }

  @Test("Upgrading from AUTH V1 as the same account keeps the library")
  func sameAccountUpgrade() async {
    let transport = simklServer(accountID: 7)
    let (auth, session, store) = makeAuth(
      SimklCredential(version: .v1, accessToken: "v1hex"),
      owner: SimklAccount(id: 7, name: "pat"), transport: transport)
    #expect(auth.usesLegacySignIn)
    let before = await session.currentSnapshot.accountSessionID
    var resets = 0
    await auth.signIn(
      authenticate: approve(challenge: OSAllocatedUnfairLock(initialState: nil)),
      resetLibrary: { resets += 1 })

    #expect(resets == 0)
    #expect(store.saved?.version == .v2)
    #expect(await session.currentSnapshot.accountSessionID == before)
    #expect(await eventually { auth.authVersion == .v2 && !auth.usesLegacySignIn })
  }

  @Test("Another account asks before replacing the library, then replaces it")
  func differentAccountConfirmed() async {
    let transport = simklServer(accountID: 8)
    let (auth, session, store) = makeAuth(
      SimklCredential(version: .v1, accessToken: "v1hex"),
      owner: SimklAccount(id: 7, name: "pat"), transport: transport)
    let before = await session.currentSnapshot.accountSessionID
    var resets = 0
    await auth.signIn(
      authenticate: approve(challenge: OSAllocatedUnfairLock(initialState: nil)),
      resetLibrary: { resets += 1 })

    let pending = auth.pendingAccountSwitch
    #expect(pending?.previous.id == 7)
    #expect(pending?.new.id == 8)
    #expect(store.saved?.version == .v1)
    #expect(resets == 0)

    let claimed = auth.takePendingAccountSwitch()
    #expect(auth.pendingAccountSwitch == nil)
    if let claimed {
      await auth.confirmAccountSwitch(claimed, resetLibrary: { resets += 1 })
    }
    #expect(resets == 1)
    #expect(store.saved?.account?.id == 8)
    #expect(await session.currentSnapshot.accountSessionID != before)
  }

  @Test("Keeping the current account ends the other account's new grant")
  func differentAccountDeclined() async {
    let transport = simklServer(accountID: 8)
    let (auth, _, store) = makeAuth(
      SimklCredential(version: .v1, accessToken: "v1hex"),
      owner: SimklAccount(id: 7, name: "pat"), transport: transport)
    await auth.signIn(
      authenticate: approve(challenge: OSAllocatedUnfairLock(initialState: nil)), resetLibrary: {})
    if let pending = auth.takePendingAccountSwitch() {
      await auth.discardAccountSwitch(pending)
    }
    #expect(store.saved?.version == .v1)
    #expect(SimklHTTPStub.requests(to: "/oauth2/revoke").first?.form["token"] == "simkl_rt_R")
  }

  @Test("A read-only grant is refused and revoked")
  func readOnlyGrant() async {
    let transport = simklServer(accountID: 7)
    let (auth, _, store) = makeAuth(nil, transport: transport)
    await auth.signIn(
      authenticate: approve(Approval(code: "readonly"), challenge: OSAllocatedUnfairLock(initialState: nil)),
      resetLibrary: {})
    #expect(auth.signInError == .missingWriteAccess)
    #expect(store.saved == nil)
    #expect(SimklHTTPStub.requests(to: "/oauth2/revoke").first?.form["token"] == "simkl_rt_R")
  }

  @Test("A forged callback is never exchanged")
  func forgedCallback() async {
    let transport = simklServer(accountID: 7)
    let (auth, _, store) = makeAuth(nil, transport: transport)
    await auth.signIn(
      authenticate: approve(Approval(forgedState: "forged"), challenge: OSAllocatedUnfairLock(initialState: nil)),
      resetLibrary: {})
    #expect(auth.signInError == .untrustedCallback)
    #expect(SimklHTTPStub.requests(to: "/oauth2/token").isEmpty)
    #expect(store.saved == nil)
  }

  @Test("Closing the sheet is quiet")
  func cancelled() async {
    let transport = simklServer(accountID: 7)
    let (auth, _, store) = makeAuth(nil, transport: transport)
    await auth.signIn(authenticate: { _ in throw SimklSignInError.cancelled }, resetLibrary: {})
    #expect(auth.signInError == nil)
    #expect(store.saved == nil)
    #expect(SimklHTTPStub.log.isEmpty)
  }
}

extension SimklSessionSnapshot {
  init(status: SimklSessionStatus) {
    self.init(status: status, accountSessionID: nil, dailyLimitResetsAt: nil)
  }
}

/// Sends one request from inside a sync attempt that writes for `account`.
private func sendDuringSync(
  _ request: URLRequest, account: UUID, session: SimklSession, transport: URLSession
) async -> SyncOutcome {
  await SimklAPI.$scopedSession.withValue(session) {
    await SyncFailureScope.perform(account: account) {
      do {
        _ = try await performSimklRequest(request, session: transport)
      } catch {
        await SyncFailureScope.report(error)
      }
    }
  }
}

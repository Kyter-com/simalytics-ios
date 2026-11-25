import Foundation
import Testing

@testable import Simalytics

@Suite("Simkl AUTH V2 building blocks")
struct SimklOAuthTests {
  private let oauth = SimklOAuthClient()

  // MARK: PKCE

  @Test("The challenge matches RFC 7636's worked example")
  func pkceVector() {
    let pkce = SimklPKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    #expect(pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
  }

  @Test("Generated verifiers are 43 unreserved characters and never repeat")
  func pkceGeneration() throws {
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    let first = try SimklPKCE.generate()
    let second = try SimklPKCE.generate()
    #expect(first.verifier.count == 43)
    #expect(first.verifier.allSatisfy(allowed.contains))
    #expect(first.challenge == SimklPKCE.challenge(for: first.verifier))
    #expect(!first.challenge.contains("="))
    #expect(first.verifier != second.verifier)
  }

  // MARK: Authorize URL

  @Test("The consent URL asks for write access with PKCE on simkl.com")
  func authorizationURL() throws {
    let pkce = SimklPKCE(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    let url = oauth.authorizationURL(state: "state-123", pkce: pkce)
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "https")
    #expect(components.host == "simkl.com")
    #expect(components.path == "/oauth2/authorize")
    let query = Dictionary(
      uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(
      query == [
        "response_type": "code",
        "client_id": SimklClient.v2.clientID,
        "redirect_uri": "simalytics://auth/simkl",
        "scope": "media:read media:write",
        "state": "state-123",
        "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
        "code_challenge_method": "S256",
      ])
    // Spaces and reserved characters are percent-encoded, never left as `+`.
    let raw = try #require(components.percentEncodedQuery)
    #expect(raw.contains("scope=media%3Aread%20media%3Awrite"))
    #expect(raw.contains("redirect_uri=simalytics%3A%2F%2Fauth%2Fsimkl"))
  }

  // MARK: Callback

  private func callback(_ query: String, base: String = "simalytics://auth/simkl") -> URL {
    URL(string: "\(base)?\(query)")!
  }

  private let iss = "iss=https%3A%2F%2Fsimkl.com"

  @Test("A matching state and issuer yield the code")
  func callbackSuccess() throws {
    let code = try oauth.authorizationCode(
      from: callback("code=abc123&state=S&\(iss)"), expectedState: "S")
    #expect(code == "abc123")
  }

  @Test(
    "Untrusted callbacks are rejected before anything in them is used",
    arguments: [
      "code=abc&state=other&iss=https%3A%2F%2Fsimkl.com",
      "code=abc&state=S",
      "code=abc&state=S&iss=https%3A%2F%2Fevil.example",
      "code=abc&state=S&iss=https%3A%2F%2Fsimkl.com.evil.example",
      "error=access_denied&state=other&iss=https%3A%2F%2Fsimkl.com",
    ])
  func untrustedCallback(query: String) {
    #expect(throws: SimklSignInError.untrustedCallback) {
      try oauth.authorizationCode(from: callback(query), expectedState: "S")
    }
  }

  @Test("A callback for another path or app is rejected")
  func wrongRedirect() {
    for base in ["simalytics://evil/simkl", "simalytics://auth/other", "otherapp://auth/simkl"] {
      #expect(throws: SimklSignInError.untrustedCallback) {
        try oauth.authorizationCode(
          from: callback("code=abc&state=S&\(iss)", base: base), expectedState: "S")
      }
    }
  }

  @Test("Choosing Don't Allow reads as a cancel, other errors as rejections")
  func callbackErrors() {
    #expect(throws: SimklSignInError.cancelled) {
      try oauth.authorizationCode(
        from: callback("error=access_denied&state=S&\(iss)"), expectedState: "S")
    }
    #expect(throws: SimklSignInError.authorizationRejected(code: "invalid_request")) {
      try oauth.authorizationCode(
        from: callback("error=invalid_request&state=S&\(iss)"), expectedState: "S")
    }
    #expect(throws: SimklSignInError.authorizationRejected(code: "other")) {
      try oauth.authorizationCode(
        from: callback("error=something_new&state=S&\(iss)"), expectedState: "S")
    }
    #expect(throws: SimklSignInError.missingCode) {
      try oauth.authorizationCode(from: callback("state=S&\(iss)"), expectedState: "S")
    }
  }

  // MARK: Token response

  private func decode(_ json: String) throws -> SimklTokenResponse {
    try JSONDecoder().decode(SimklTokenResponse.self, from: Data(json.utf8))
  }

  @Test("A V2 token response becomes a refreshable, writable credential")
  func tokenResponse() throws {
    let issued = Date(timeIntervalSince1970: 1_800_000_000)
    let credential = try decode(
      #"{"access_token":"simkl_at_A","token_type":"Bearer","expires_in":604800,"refresh_token":"simkl_rt_R","scope":"media:read media:write"}"#
    ).credential(issuedAt: issued)
    #expect(credential.version == .v2)
    #expect(credential.accessToken == "simkl_at_A")
    #expect(credential.refreshToken == "simkl_rt_R")
    #expect(credential.accessTokenExpiresAt == issued.addingTimeInterval(604_800))
    #expect(credential.refreshTokenExpiresAt == issued.addingTimeInterval(180 * 24 * 60 * 60))
    #expect(credential.canWrite)
    #expect(credential.canRefresh)
    #expect(!credential.needsRefresh(at: issued.addingTimeInterval(5 * 24 * 60 * 60)))
    #expect(credential.needsRefresh(at: issued.addingTimeInterval(6.5 * 24 * 60 * 60)))
  }

  @Test("token_type is compared without case, and only Bearer is accepted")
  func tokenType() throws {
    for type in ["Bearer", "bearer", "BEARER"] {
      #expect(throws: Never.self) {
        try decode(
          #"{"access_token":"a","token_type":"\#(type)","refresh_token":"r","scope":"media:read media:write"}"#
        ).credential(issuedAt: .now)
      }
    }
    #expect(throws: SimklOAuthError.invalidResponse) {
      try decode(#"{"access_token":"a","token_type":"mac","refresh_token":"r"}"#)
        .credential(issuedAt: .now)
    }
  }

  @Test("A refresh keeps what the response doesn't repeat; an exchange must include it")
  func refreshCarriesOver() throws {
    let previous = SimklCredential(
      version: .v2, accessToken: "old", refreshToken: "simkl_rt_R", scope: "media:read media:write",
      account: SimklAccount(id: 7, name: "pat"))
    let refreshed = try decode(#"{"access_token":"new","expires_in":"604800"}"#)
      .credential(issuedAt: .now, replacing: previous)
    #expect(refreshed.refreshToken == "simkl_rt_R")
    #expect(refreshed.account == previous.account)
    #expect(refreshed.canWrite)
    #expect(throws: SimklOAuthError.invalidResponse) {
      try decode(#"{"access_token":"new"}"#).credential(issuedAt: .now)
    }
  }

  @Test(
    "Only the exact media:write token grants write",
    arguments: [
      ("media:read media:write", true), ("media:read,media:write", true), ("media:write", true),
      ("media:read", false), ("MEDIA:WRITE", false), ("media:wrote", false), ("", false),
    ])
  func scopes(scope: String, writes: Bool) {
    #expect(SimklScope.grantsWrite(scope) == writes)
  }

  @Test("Credentials never print their tokens")
  func redaction() {
    let credential = SimklCredential(
      version: .v2, accessToken: "simkl_at_SECRET", refreshToken: "simkl_rt_SECRET")
    for text in [String(describing: credential), String(reflecting: credential), "\(credential)"] {
      #expect(!text.contains("SECRET"))
    }
  }

  // MARK: Session status

  @Test("Status follows the credential, and a library without one asks to reconnect")
  func status() {
    let owner = SimklAccount(id: 7, name: "pat")
    #expect(SimklSession.status(for: nil, owner: nil) == .signedOut)
    #expect(
      SimklSession.status(for: nil, owner: owner)
        == .reconnectRequired(.credentialMissing, version: nil, account: owner))
    let v1 = SimklCredential(version: .v1, accessToken: "hex")
    #expect(SimklSession.status(for: v1, owner: owner) == .connected(version: .v1, account: owner))
    var dead = v1
    dead.invalidatedAt = .now
    #expect(
      SimklSession.status(for: dead, owner: owner)
        == .reconnectRequired(.legacySignInEnded, version: .v1, account: owner))
    let readOnly = SimklCredential(
      version: .v2, accessToken: "a", refreshToken: "r", scope: "media:read")
    #expect(
      SimklSession.status(for: readOnly, owner: nil)
        == .reconnectRequired(.missingWriteAccess, version: .v2, account: nil))
  }

  // MARK: Migration schedule

  private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

  @Test("The upgrade prompt starts quiet, repeats every two weeks, then stays")
  func migrationSchedule() {
    let early = date("2026-12-01T12:00:00Z")
    #expect(SimklMigrationSchedule.stage(at: early) == .settingsOnly)
    #expect(!SimklMigrationSchedule.showsBanner(at: early, lastDismissed: nil))

    let middle = date("2027-02-01T12:00:00Z")
    #expect(SimklMigrationSchedule.stage(at: middle) == .dismissibleBanner)
    #expect(SimklMigrationSchedule.showsBanner(at: middle, lastDismissed: nil))
    #expect(
      !SimklMigrationSchedule.showsBanner(
        at: middle, lastDismissed: middle.addingTimeInterval(-3 * 24 * 60 * 60)))
    #expect(
      SimklMigrationSchedule.showsBanner(
        at: middle, lastDismissed: middle.addingTimeInterval(-15 * 24 * 60 * 60)))

    let late = date("2027-03-02T12:00:00Z")
    #expect(SimklMigrationSchedule.stage(at: late) == .persistentBanner)
    #expect(
      SimklMigrationSchedule.showsBanner(at: late, lastDismissed: late.addingTimeInterval(-60)))
  }

  // MARK: Errors

  @Test("The daily limit isn't retried; the per-second limit and write lock are")
  func limits() throws {
    let daily = try #require(
      parseSimklServerErrorReason(
        from: Data(#"{"error":"user_limit_exceeded","code":429}"#.utf8)))
    #expect(daily.isDailyLimit)
    #expect(!SimklMutationError.httpStatusCode(429, reason: daily).isRetryable)

    let appDaily = parseSimklServerErrorReason(
      from: Data(#"{"error":"app_limit_exceeded","code":429}"#.utf8))
    #expect(appDaily?.isDailyLimit == true)

    let burst = parseSimklServerErrorReason(from: Data(#"{"error":"rate_limit","code":429}"#.utf8))
    #expect(SimklMutationError.httpStatusCode(429, reason: burst).isRetryable)

    let writeLock = parseSimklServerErrorReason(
      from: Data(#"{"error":"RATE_LIMIT","code":400}"#.utf8))
    #expect(SimklMutationError.httpStatusCode(400, reason: writeLock).isRetryable)
    #expect(!SimklMutationError.httpStatusCode(400, reason: nil).isRetryable)
  }

  @Test("Retry-After rides along with a daily-limit answer")
  func retryAfter() throws {
    let response = try #require(
      HTTPURLResponse(
        url: URL(string: "https://api.simkl.com/sync/activities")!, statusCode: 429,
        httpVersion: nil, headerFields: ["Retry-After": "21600"]))
    let reason = parseSimklServerErrorReason(
      from: Data(#"{"error":"user_limit_exceeded","code":429}"#.utf8), response: response)
    #expect(reason?.retryAfter == 21_600)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let message = simklMutationUserMessage(
      for: SimklMutationError.httpStatusCode(429, reason: reason), now: now)
    #expect(message.contains("in about 6 hours"))
  }

  @Test("Sign-in identifiers are kept so the pipeline can branch on them")
  func authErrorCodes() {
    for code in ["user_token_required", "invalid_token", "user_token_failed", "insufficient_scope"] {
      let reason = parseSimklServerErrorReason(from: Data(#"{"error":"\#(code)","code":401}"#.utf8))
      #expect(reason?.code == code)
    }
  }

  @Test("The account-switch dialog never names an account it doesn't know")
  func accountSwitchCopy() {
    let pat = SimklAccount(id: 7, name: "pat")
    let sam = SimklAccount(id: 8, name: "sam")
    let unnamed = SimklAccount(id: 9, name: nil)
    let blank = SimklAccount(id: 10, name: "  ")
    #expect(SimklAccountCopy.useAccountButton(sam) == "Use sam")
    #expect(SimklAccountCopy.keepAccountButton(pat) == "Keep pat")
    #expect(SimklAccountCopy.useAccountButton(unnamed) == "Use New Account")
    #expect(SimklAccountCopy.keepAccountButton(blank) == "Keep Current Account")
    #expect(
      SimklAccountCopy.switchMessage(new: sam, previous: pat)
        .hasPrefix("You approved Simalytics as sam, but this device has pat's library."))
    #expect(
      SimklAccountCopy.switchMessage(new: unnamed, previous: blank)
        .hasPrefix(
          "You approved Simalytics with a different Simkl account, but this device has another account's library."
        ))
  }

  @Test("On AUTH V1 the daily-limit card points to upgrading, since the allowance is shared")
  func dailyLimitCopy() {
    let legacy = SimklAccountCopy.dailyLimitMessage(resumes: "in about 6 hours", legacy: true)
    #expect(legacy.contains("everyone using Simalytics") && legacy.contains("Upgrade"))
    let own = SimklAccountCopy.dailyLimitMessage(resumes: "in about 6 hours", legacy: false)
    #expect(own.hasPrefix("Syncing resumes in about 6 hours.") && own.contains("Connected Apps"))
  }

  @Test("The daily allowance resets at the next midnight in New York")
  func dailyReset() {
    // 2026-11-23 10:00 New York (EST, UTC-5) resets at 2026-11-24 05:00 UTC.
    let reset = SimklDailyLimit.nextReset(after: date("2026-11-23T15:00:00Z"))
    #expect(reset == date("2026-11-24T05:00:00Z"))
    // In summer (EDT, UTC-4) the same rule lands an hour earlier in UTC.
    #expect(SimklDailyLimit.nextReset(after: date("2026-07-01T15:00:00Z")) == date("2026-07-02T04:00:00Z"))
  }
}

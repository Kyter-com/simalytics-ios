//
//  SimklOAuthClient.swift
//  simalytics
//

import Foundation

/// Why a browser sign-in didn't produce a credential. Messages are written for
/// people; nothing here carries a token or code.
enum SimklSignInError: Error, Equatable, Sendable {
  /// Closed the sheet, or chose "Don't allow" on simkl.com. Not an error to show.
  case cancelled
  /// The callback's `state` or `iss` didn't match this sign-in, or it wasn't our
  /// redirect at all: the response is ignored and its code never exchanged.
  case untrustedCallback
  /// Simkl redirected back with an `error` other than `access_denied`.
  case authorizationRejected(code: String)
  case missingCode
  /// The token request failed. A code is single-use, even when the exchange
  /// fails, so this always means starting over.
  case exchangeFailed(SimklOAuthError)
  case network
  /// Simkl issued a token that can't write, so Simalytics couldn't save changes.
  case missingWriteAccess
  /// Couldn't read which Simkl account approved the sign-in.
  case accountLookupFailed
  case storageFailed
  case randomGenerationFailed

  var title: String {
    switch self {
    case .missingWriteAccess: "Simkl Didn't Allow Changes"
    default: "Couldn't Sign In to Simkl"
    }
  }

  var message: String {
    switch self {
    case .cancelled:
      "Sign-in was cancelled."
    case .network:
      "Simalytics couldn't reach Simkl. Check your connection and try again."
    case .missingWriteAccess:
      "Simalytics needs permission to update your Simkl library. Sign in again and allow access to keep your lists in sync."
    case .storageFailed:
      "Simalytics couldn't save your sign-in on this iPhone. Try again."
    case .untrustedCallback, .authorizationRejected, .missingCode, .exchangeFailed,
      .accountLookupFailed, .randomGenerationFailed:
      "Something went wrong while signing in. Try again. If it keeps happening, let us know from Settings."
    }
  }

  /// Worth a crash report: everything but the person's own choice or connection.
  var isUnexpected: Bool {
    switch self {
    case .cancelled, .network: false
    default: true
    }
  }
}

/// An `/oauth2/*` failure, in RFC 6749's envelope: an `error` and an optional
/// description, with no `code` field.
struct SimklOAuthError: Error, Equatable, Sendable, CustomNSError {
  let status: Int
  /// The `error` value, kept only when it's one of the documented ones.
  let code: String?

  static let invalidResponse = SimklOAuthError(status: 0, code: "invalid_response")

  static var errorDomain: String { "Simalytics.SimklOAuthError" }
  var errorCode: Int { status }
  var errorUserInfo: [String: Any] {
    [NSLocalizedDescriptionKey: "Simkl OAuth request failed (HTTP \(status); \(code ?? "no code"))."]
  }

  private static let knownCodes: Set<String> = [
    "invalid_request", "invalid_client", "invalid_grant", "invalid_scope", "unauthorized_client",
    "unsupported_grant_type", "access_denied", "server_error", "temporarily_unavailable",
    "invalid_response",
  ]

  static func sanitized(_ code: String?) -> String? {
    guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
      return nil
    }
    return knownCodes.contains(code) ? code : "other"
  }

  static func parse(status: Int, data: Data) -> SimklOAuthError {
    let object = data.count <= 64 * 1024 ? try? JSONSerialization.jsonObject(with: data) : nil
    let error = (object as? [String: Any])?["error"] as? String
    return SimklOAuthError(status: status, code: sanitized(error))
  }
}

/// Talks to Simkl's AUTH V2 endpoints for this app's public client. Requests are
/// built here rather than through the API request pipeline, which adds query
/// parameters meant for API calls.
struct SimklOAuthClient: Sendable {
  var client: SimklClient = .v2
  var transport: URLSession = .shared
  var now: @Sendable () -> Date = { Date() }
  /// Sent on the consent URL and the code exchange, and required of the
  /// callback. A loopback address stands in for the app in end-to-end checks.
  var redirectURI = SimklOAuthConfig.redirectURI

  // MARK: Authorization

  /// The consent page to open in `ASWebAuthenticationSession`.
  func authorizationURL(state: String, pkce: SimklPKCE) -> URL {
    var components = URLComponents(url: SimklOAuthConfig.authorizeURL, resolvingAgainstBaseURL: false)!
    components.percentEncodedQuery = SimklFormEncoding.query([
      ("response_type", "code"),
      ("client_id", client.clientID),
      ("redirect_uri", redirectURI),
      ("scope", SimklOAuthConfig.requestedScope),
      ("state", state),
      ("code_challenge", pkce.challenge),
      ("code_challenge_method", "S256"),
    ])
    return components.url!
  }

  /// The authorization code from Simkl's redirect. The issuer and `state` are
  /// checked first, on the error path too, so a forged or mixed-up response is
  /// rejected before anything in it is trusted.
  func authorizationCode(from callback: URL, expectedState: String) throws(SimklSignInError)
    -> String
  {
    guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
      let expected = URLComponents(string: redirectURI),
      components.scheme?.lowercased() == expected.scheme,
      components.host?.lowercased() == expected.host,
      components.path == expected.path
    else { throw .untrustedCallback }

    let items = components.queryItems ?? []
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

    // RFC 9207: a plain equality check, never a prefix test. Simkl's discovery
    // document promises `iss` on every response.
    guard value("iss") == SimklOAuthConfig.issuer,
      let state = value("state"), constantTimeEquals(state, expectedState)
    else { throw .untrustedCallback }

    if let error = value("error") {
      // Treat an unknown error like a refusal, as Simkl recommends, but keep
      // the code for diagnostics.
      if error == "access_denied" { throw .cancelled }
      throw .authorizationRejected(code: SimklOAuthError.sanitized(error) ?? "other")
    }
    guard let code = value("code"), !code.isEmpty else { throw .missingCode }
    return code
  }

  // MARK: Tokens

  /// Exchanges the code once. Simkl destroys a code on any attempt that passes
  /// client authentication, so a retry could only ever fail.
  func exchange(code: String, verifier: String) async throws(SimklSignInError) -> SimklCredential {
    let issuedAt = now()
    do {
      let response = try await tokenRequest([
        ("grant_type", "authorization_code"),
        ("client_id", client.clientID),
        ("code", code),
        ("redirect_uri", redirectURI),
        ("code_verifier", verifier),
      ])
      return try response.credential(issuedAt: issuedAt)
    } catch let error as SimklOAuthError {
      throw .exchangeFailed(error)
    } catch {
      throw isTransientNetworkError(error) ? .network : .exchangeFailed(.invalidResponse)
    }
  }

  /// A fresh access token for the same grant. The previous access token stops
  /// working the moment this succeeds. Throws `SimklOAuthError` when Simkl
  /// answers with an error (`invalid_grant` means the grant is gone) and the
  /// transport's error when it couldn't ask.
  func refresh(_ credential: SimklCredential) async throws -> SimklCredential {
    guard credential.version == .v2, let refreshToken = credential.refreshToken else {
      throw SimklOAuthError(status: 400, code: "invalid_grant")
    }
    let issuedAt = now()
    let response = try await tokenRequest([
      ("grant_type", "refresh_token"),
      ("client_id", client.clientID),
      ("refresh_token", refreshToken),
    ])
    return try response.credential(issuedAt: issuedAt, replacing: credential)
  }

  /// Ends the grant behind `token` (either half revokes both). Simkl answers
  /// 200 whether or not the token still worked, so there's no result to act on.
  func revoke(_ token: String) async {
    var request = URLRequest(url: SimklOAuthConfig.revokeURL, timeoutInterval: 10)
    request.httpMethod = "POST"
    configureFormRequest(&request)
    request.httpBody = SimklFormEncoding.body([("client_id", client.clientID), ("token", token)])
    _ = try? await transport.data(for: request)
  }

  /// The account behind a credential that isn't installed yet.
  func fetchAccount(for credential: SimklCredential) async throws -> SimklAccountSettings {
    var request = URLRequest(url: URL(string: "https://api.simkl.com/users/settings")!)
    request = prepareSimklRequest(request, client: credential.client)
    request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
    let (data, response) = try await transport.data(for: request)
    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      throw SimklSignInError.accountLookupFailed
    }
    guard let settings = try? JSONDecoder().decode(SimklUserSettingsModel.self, from: data),
      let account = settings.simklAccount
    else { throw SimklSignInError.accountLookupFailed }
    return SimklAccountSettings(account: account, plan: settings.account?.type?.lowercased())
  }

  private func tokenRequest(_ form: [(String, String)]) async throws -> SimklTokenResponse {
    var request = URLRequest(url: SimklOAuthConfig.tokenURL, timeoutInterval: 30)
    request.httpMethod = "POST"
    configureFormRequest(&request)
    request.httpBody = SimklFormEncoding.body(form)
    let (data, response) = try await transport.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw SimklOAuthError.invalidResponse }
    guard (200...299).contains(http.statusCode) else {
      throw SimklOAuthError.parse(status: http.statusCode, data: data)
    }
    do {
      return try JSONDecoder().decode(SimklTokenResponse.self, from: data)
    } catch {
      throw SimklOAuthError.invalidResponse
    }
  }

  private func configureFormRequest(_ request: inout URLRequest) {
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(SIMKL_USER_AGENT, forHTTPHeaderField: "User-Agent")
  }

  private func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
    let a = Array(lhs.utf8)
    let b = Array(rhs.utf8)
    guard a.count == b.count else { return false }
    return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
  }
}

/// Who approved a sign-in, and their plan.
struct SimklAccountSettings: Sendable, Equatable {
  let account: SimklAccount
  let plan: String?
}

/// Percent-encoding for OAuth form bodies and the authorize query. Only RFC 3986
/// unreserved characters pass through, so `+`, `/`, `:` and spaces in a value
/// can never be misread.
enum SimklFormEncoding {
  private static let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

  static func encode(_ value: String) -> String {
    value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
  }

  static func query(_ pairs: [(String, String)]) -> String {
    pairs.map { "\(encode($0.0))=\(encode($0.1))" }.joined(separator: "&")
  }

  static func body(_ pairs: [(String, String)]) -> Data { Data(query(pairs).utf8) }
}

func isTransientNetworkError(_ error: Error) -> Bool {
  if isExpectedTransientNetworkError(error) { return true }
  if let urlError = error as? URLError {
    switch urlError.code {
    case .secureConnectionFailed, .resourceUnavailable, .internationalRoamingOff,
      .dataNotAllowed, .callIsActive:
      return true
    default:
      return false
    }
  }
  return false
}

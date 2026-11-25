//
//  SimklMutationRequest.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/14/26.
//

import Foundation
import Sentry

struct SimklServerErrorReason: Equatable, Sendable {
  let code: String?
  let message: String?
  /// Seconds until a spent daily allowance resets, from `Retry-After`.
  var retryAfter: TimeInterval? = nil

  /// Simkl's per-user (AUTH V2) or per-app (AUTH V1) daily allowance is spent.
  /// It resets at midnight US Eastern, so retrying sooner can't help.
  var isDailyLimit: Bool { code == "daily_limit" }
}

enum SimklMutationError: Error, Equatable, Sendable, CustomNSError {
  case invalidResponse
  case invalidEpisode
  case episodeNotFound
  case mediaNotFound
  case invalidRating
  case httpStatusCode(Int, reason: SimklServerErrorReason?)

  static var errorDomain: String { "Simalytics.SimklMutationError" }

  var errorCode: Int {
    switch self {
    case .invalidResponse: 1
    case .invalidEpisode: 2
    case .episodeNotFound: 3
    case .mediaNotFound: 4
    case .invalidRating: 5
    case .httpStatusCode(let statusCode, _): statusCode
    }
  }

  var errorUserInfo: [String: Any] {
    [NSLocalizedDescriptionKey: diagnosticDescription]
  }

  private var diagnosticDescription: String {
    switch self {
    case .invalidResponse:
      return "Simkl returned an invalid response."
    case .invalidEpisode:
      return "Episode mutation rejected before request: invalid season or episode."
    case .episodeNotFound:
      return "Simkl could not resolve the requested episode."
    case .mediaNotFound:
      return "Simkl could not resolve the requested title."
    case .invalidRating:
      return "The rating must be a whole number from 0 to 10."
    case .httpStatusCode(let statusCode, let reason):
      var details = ["HTTP \(statusCode)"]
      if let code = reason?.code {
        details.append("code \(code)")
      }
      if let message = reason?.message {
        details.append(message)
      }
      return "Simkl rejected update (\(details.joined(separator: "; ")))."
    }
  }

  var isRetryable: Bool {
    switch self {
    case .invalidResponse:
      return true
    case .invalidEpisode, .episodeNotFound, .mediaNotFound, .invalidRating:
      return false
    case .httpStatusCode(let statusCode, let reason):
      // Simkl's per-second limit clears in about a second; the daily one only
      // at midnight US Eastern.
      if statusCode == 429 { return !(reason?.isDailyLimit ?? false) }
      // `400 RATE_LIMIT` is a short per-user write lock, not a quota.
      if statusCode == 400 { return reason?.code == "rate_limited" }
      return (500...599).contains(statusCode)
    }
  }
}

enum SimklMutationResult: Equatable, Sendable {
  case succeeded
  case cancelled
  case failed(userMessage: String)
}

/// An api.simkl.com URL. The app's `client_id`, `app-name` and `app-version`
/// are added when the request is sent, from the credential it carries.
func simklAPIURL(path: String, queryItems: [URLQueryItem] = []) -> URL {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "api.simkl.com"
  components.path = path.hasPrefix("/") ? path : "/\(path)"
  components.queryItems = queryItems.isEmpty ? nil : queryItems
  return components.url!
}

/// Identifies the app on an api.simkl.com request: `client_id`, `app-name` and
/// `app-version`, plus the headers Simkl requires. The client ID always comes
/// from `client`, replacing any already on the request, because Simkl rejects a
/// token sent with another registration's client ID.
func prepareSimklRequest(_ request: URLRequest, client: SimklClient) -> URLRequest {
  var preparedRequest = request
  guard let url = preparedRequest.url, url.host?.lowercased() == "api.simkl.com" else {
    return preparedRequest
  }
  if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
    var queryItems = (components.queryItems ?? []).filter {
      $0.name.caseInsensitiveCompare("client_id") != .orderedSame
    }
    queryItems.append(URLQueryItem(name: "client_id", value: client.clientID))
    appendQueryItemIfMissing(URLQueryItem(name: "app-name", value: SIMKL_APP_NAME), to: &queryItems)
    appendQueryItemIfMissing(
      URLQueryItem(name: "app-version", value: SIMKL_APP_VERSION), to: &queryItems)
    components.queryItems = queryItems
    preparedRequest.url = components.url
  }
  preparedRequest.cachePolicy = .reloadIgnoringLocalCacheData
  configureSimklHeaders(on: &preparedRequest, client: client)
  return preparedRequest
}

/// Sends a request through the current `SimklSession`: it attaches the token a
/// `.user` request needs as it goes out, and when Simkl answers 401 it refreshes
/// once, shared with any other request that hit the same expiry, and retries.
///
/// A `.user` request goes out for one account only: `account` when given, the
/// running sync's, or whoever is signed in when it's sent.
func sendSimklRequest(
  _ request: URLRequest, using transport: URLSession, account: UUID? = nil
) async throws -> (Data, URLResponse) {
  let simkl = SimklAPI.session
  let prepared = try await simkl.prepare(request, account: account ?? SyncFailureScope.account)
  let (data, response) = try await transport.data(for: prepared.request)
  let status = (response as? HTTPURLResponse)?.statusCode

  // Only a request that carried the person's token speaks for their allowance.
  if status == 429, let http = response as? HTTPURLResponse, let token = prepared.token {
    let reason = parseSimklServerErrorReason(from: data, response: http)
    if reason?.isDailyLimit == true,
      await simkl.noteDailyLimit(retryAfter: reason?.retryAfter, token: token)
    {
      // A sync that's running stops instead of failing every remaining step.
      await SyncFailureScope.noteDailyLimit()
    }
  }

  guard status == 401, let token = prepared.token, prepared.refreshesOnUnauthorized else {
    return (data, response)
  }
  // No token arrived at all: a missing header, which a refresh can't fix.
  if parseSimklServerErrorReason(from: data)?.code == "user_token_required" {
    return (data, response)
  }

  try await simkl.recover(afterUnauthorized: token, account: prepared.account)
  // Cancelled instead if another account replaced this one meanwhile.
  let retry = try await simkl.prepare(request, account: prepared.account)
  let (retryData, retryResponse) = try await transport.data(for: retry.request)
  if (retryResponse as? HTTPURLResponse)?.statusCode == 401, retry.token != nil {
    throw SimklAuthError.temporarilyRejected
  }
  return (retryData, retryResponse)
}

func validatedSimklEpisode(
  season: Int?,
  episode: Int?,
  fallbackSeason: Int? = nil
) -> (season: Int, episode: Int)? {
  guard let episode, episode > 0 else { return nil }
  guard let season = season ?? fallbackSeason, season >= 0 else { return nil }
  return (season, episode)
}

extension URLSession {
  /// Like `data(for:)`, through the Simkl pipeline: right client ID, the
  /// current token for `.user` requests, and one refresh on an expired token.
  func simklData(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await sendSimklRequest(request, using: self)
  }
}

func performSimklRequest(
  _ request: URLRequest, retryCount: Int = 2, session: URLSession = .shared
) async throws -> (
  Data, HTTPURLResponse
) {
  var attempt = 0
  var retryDelay = Duration.milliseconds(500)
  // Every attempt goes out for the account this request started with, or not
  // at all: a retry must never land in an account that replaced it.
  let account = await simklRequestAccount(for: request)

  while true {
    do {
      let (data, response) = try await sendSimklRequest(request, using: session, account: account)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw SimklMutationError.invalidResponse
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        throw SimklMutationError.httpStatusCode(
          httpResponse.statusCode,
          reason: parseSimklServerErrorReason(from: data, response: httpResponse)
        )
      }

      return (data, httpResponse)
    } catch {
      let retryableRead = (request.httpMethod ?? "GET").uppercased() == "GET"
        && (error as? URLError)?.code == .resourceUnavailable
      if attempt >= retryCount || !(retryableRead || shouldRetrySimklMutation(error)) {
        throw error
      }

      try await Task.sleep(for: retryDelay)
      retryDelay += retryDelay
      attempt += 1
    }
  }
}

/// The account a `.user` request made now belongs to: the running sync's, or
/// whoever is signed in. Nil for requests that carry no token.
func simklRequestAccount(for request: URLRequest) async -> UUID? {
  guard request.simklAuth == .user else { return nil }
  if let account = SyncFailureScope.account { return account }
  return await SimklAPI.session.currentSnapshot.accountSessionID
}

func performSimklMutationRequest(_ request: URLRequest, retryCount: Int = 2) async throws {
  _ = try await performSimklRequest(request, retryCount: retryCount)
}

func simklMutationUserMessage(for error: Error, now: Date = Date()) -> String {
  if let authError = error as? SimklAuthError {
    switch authError {
    case .signedOut:
      return "Sign in to Simkl in Settings to save changes."
    case .reconnectRequired:
      return "Reconnect to Simkl to save changes. Your library on this device is still here."
    case .temporarilyRejected:
      return "Simkl didn't accept your sign-in just now. Try again in a moment."
    }
  }

  if let simklError = error as? SimklMutationError {
    switch simklError {
    case .invalidResponse:
      return "Could not read Simkl's response. Please try again."
    case .invalidEpisode:
      return "This episode has invalid season or episode information."
    case .episodeNotFound:
      return "Simkl couldn’t find this episode. Refresh your list and try again."
    case .mediaNotFound:
      return "Simkl couldn’t find this title. Refresh your list and try again."
    case .invalidRating:
      return "Choose a rating from 1 to 10, or remove your rating."
    case .httpStatusCode(let statusCode, let reason):
      if statusCode == 401 {
        return "Simkl didn't accept your sign-in. Try again in a moment."
      }
      if statusCode == 403, reason?.code == "insufficient_scope" {
        return "Simkl isn't letting Simalytics change your library. Reconnect to Simkl and allow access."
      }
      if statusCode == 429, let reason, reason.isDailyLimit {
        let reset = reason.retryAfter.map { now.addingTimeInterval($0) }
          ?? SimklDailyLimit.nextReset(after: now)
        // Not "you": on AUTH V1 the allowance is shared by everyone on Simalytics.
        return
          "Simkl's daily request limit has been reached. It resets \(SimklDailyLimit.remainingDescription(until: reset, from: now))."
      }
      if statusCode == 429 {
        return "Too many requests to Simkl. Please wait a moment and try again."
      }
      if (500...599).contains(statusCode) {
        return "Simkl is currently unavailable. Please try again in a moment."
      }
      return "Simkl rejected this update (HTTP \(statusCode)). Please try again."
    }
  }

  if let urlError = error as? URLError {
    switch urlError.code {
    case .notConnectedToInternet:
      return "You're offline. Check your connection and try again."
    case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost:
      return "Connection to Simkl failed. Please try again."
    default:
      break
    }
  }

  return "Couldn't update your list. Please try again."
}

func parseSimklServerErrorReason(from data: Data, response: HTTPURLResponse) -> SimklServerErrorReason? {
  var reason = parseSimklServerErrorReason(from: data)
  // `Retry-After` is a duration in seconds, sent only with a daily-limit 429.
  if let header = response.value(forHTTPHeaderField: "Retry-After"),
    let seconds = TimeInterval(header.trimmingCharacters(in: .whitespaces)), seconds >= 0
  {
    reason = reason ?? SimklServerErrorReason(code: nil, message: nil)
    reason?.retryAfter = seconds
  }
  return reason
}

func parseSimklServerErrorReason(from data: Data) -> SimklServerErrorReason? {
  guard data.count <= 64 * 1024,
    let object = try? JSONSerialization.jsonObject(with: data),
    let root = object as? [String: Any]
  else { return nil }

  let nestedError = root["error"] as? [String: Any]
  // Simkl's machine-readable identifier is `error` (its `code` echoes the
  // status). Prefer it when it names a known category.
  let identifier = sanitizedSimklErrorCode(root["error"] as? String)
  let rawCode =
    stringValue(root["code"])
    ?? stringValue(root["error_code"])
    ?? stringValue(nestedError?["code"])
  let rawMessage =
    stringValue(root["message"])
    ?? stringValue(root["error_description"])
    ?? (root["error"] as? String)
    ?? stringValue(nestedError?["message"])

  let reason = SimklServerErrorReason(
    code: identifier ?? sanitizedSimklErrorCode(rawCode),
    message: classifiedSimklErrorMessage(rawMessage)
  )
  return reason.code == nil && reason.message == nil ? nil : reason
}

private func stringValue(_ value: Any?) -> String? {
  switch value {
  case let string as String:
    return string
  case let number as NSNumber:
    return number.stringValue
  default:
    return nil
  }
}

private func sanitizedSimklErrorCode(_ rawCode: String?) -> String? {
  guard let rawCode else { return nil }
  let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  guard !code.isEmpty, code.count <= 48 else { return nil }

  let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
  guard code.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
  if code.allSatisfy(\.isNumber) {
    return code.count <= 4 ? code : nil
  }

  // Never retain an arbitrary server string, even when it looks code-like:
  // a title or account identifier can also be short and alphanumeric.
  // Normalize only known diagnostic categories to fixed values.
  switch code {
  // Sign-in states the request pipeline branches on.
  case "user_token_required", "invalid_token", "user_token_failed", "insufficient_scope",
    "oauth2_token_required":
    return code
  // A spent daily allowance: per user on AUTH V2, per app on AUTH V1.
  case "user_limit_exceeded", "app_limit_exceeded":
    return "daily_limit"
  default:
    break
  }
  if code.contains("auth") || code.contains("token") || code.contains("unauthor") {
    return "authentication_rejected"
  }
  if code.contains("rate") || code.contains("limit") {
    return "rate_limited"
  }
  if code.contains("episode") || code.contains("season") {
    return "invalid_episode"
  }
  if code.contains("not_found") || code.contains("not-found") || code.contains("notfound") {
    return "not_found"
  }
  if code.contains("invalid") || code.contains("bad_request") || code.contains("validation") {
    return "invalid_request"
  }
  if code.contains("duplicate") || code.contains("already") {
    return "duplicate"
  }
  return nil
}

private func classifiedSimklErrorMessage(_ rawMessage: String?) -> String? {
  guard let message = rawMessage?.lowercased() else { return nil }

  if message.contains("unauthor") || message.contains("forbidden")
    || message.contains("access token") || message.contains("authentication")
  {
    return "Authentication was rejected."
  }
  if message.contains("rate limit") || message.contains("too many request") {
    return "Simkl rate-limited the request."
  }
  if (message.contains("episode") || message.contains("season"))
    && (message.contains("invalid") || message.contains("missing")
      || message.contains("required") || message.contains("unknown"))
  {
    return "Episode selection was rejected."
  }
  if message.contains("not found") || message.contains("not_found") {
    return "The requested item was not found."
  }
  if message.contains("invalid request") || message.contains("bad request")
    || message.contains("malformed") || message.contains("validation")
  {
    return "Simkl reported an invalid request."
  }
  if message.contains("duplicate") || message.contains("already") {
    return "Simkl reported a duplicate update."
  }
  return nil
}

func isSimklCancellationError(_ error: Error) -> Bool {
  if error is CancellationError {
    return true
  }

  if let urlError = error as? URLError, urlError.code == .cancelled {
    return true
  }

  let nsError = error as NSError
  if nsError.domain == NSURLErrorDomain, nsError.code == URLError.cancelled.rawValue {
    return true
  }

  return false
}

/// Reports an error to Sentry unless it's a user-initiated cancellation or expected network failure.
/// Cancellations happen routinely during navigation (users tapping away
/// before a fetch completes) and are not real errors.
func reportError(_ error: Error) {
  if isSimklCancellationError(error) || isExpectedTransientNetworkError(error) { return }
  // Expected states, not bugs: signed out, waiting to reconnect, or out of
  // Simkl's daily allowance. The interface already explains them.
  if error is SimklAuthError { return }
  if case .httpStatusCode(429, let reason) = error as? SimklMutationError, reason?.isDailyLimit == true {
    return
  }
  SentrySDK.capture(error: error)
}

func isExpectedTransientNetworkError(_ error: Error) -> Bool {
  let code: URLError.Code?
  if let urlError = error as? URLError {
    code = urlError.code
  } else {
    let nsError = error as NSError
    code = nsError.domain == NSURLErrorDomain ? URLError.Code(rawValue: nsError.code) : nil
  }

  switch code {
  case .timedOut, .networkConnectionLost, .notConnectedToInternet,
    .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
    return true
  default:
    return false
  }
}

private func shouldRetrySimklMutation(_ error: Error) -> Bool {
  if let simklError = error as? SimklMutationError {
    return simklError.isRetryable
  }

  if let urlError = error as? URLError {
    switch urlError.code {
    case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
      .notConnectedToInternet:
      return true
    default:
      return false
    }
  }

  return false
}

private func appendQueryItemIfMissing(
  _ queryItem: URLQueryItem, to queryItems: inout [URLQueryItem]
) {
  guard
    !queryItems.contains(where: { $0.name.caseInsensitiveCompare(queryItem.name) == .orderedSame })
  else {
    return
  }
  queryItems.append(queryItem)
}

private func configureSimklHeaders(on request: inout URLRequest, client: SimklClient) {
  request.setValue(SIMKL_USER_AGENT, forHTTPHeaderField: "User-Agent")
  if request.value(forHTTPHeaderField: "Accept") == nil {
    request.setValue("application/json", forHTTPHeaderField: "Accept")
  }

  let method = request.httpMethod?.uppercased() ?? "GET"
  if method != "GET",
    request.value(forHTTPHeaderField: "Content-Type") == nil
  {
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
  }

  // Always the credential's own client ID, matching the `client_id` parameter.
  request.setValue(client.clientID, forHTTPHeaderField: "simkl-api-key")
}

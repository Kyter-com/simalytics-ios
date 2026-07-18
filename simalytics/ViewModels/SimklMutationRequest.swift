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
}

enum SimklMutationError: Error, Equatable, Sendable, CustomNSError {
  case invalidResponse
  case invalidEpisode
  case httpStatusCode(Int, reason: SimklServerErrorReason?)

  static var errorDomain: String { "Simalytics.SimklMutationError" }

  var errorCode: Int {
    switch self {
    case .invalidResponse: 1
    case .invalidEpisode: 2
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
    case .invalidEpisode:
      return false
    case .httpStatusCode(let statusCode, _):
      return statusCode == 429 || (500...599).contains(statusCode)
    }
  }
}

enum SimklMutationResult: Equatable, Sendable {
  case succeeded
  case cancelled
  case failed(userMessage: String)
}

func simklAPIURL(path: String, queryItems: [URLQueryItem] = []) -> URL {
  var components = URLComponents()
  components.scheme = "https"
  components.host = "api.simkl.com"
  components.path = path.hasPrefix("/") ? path : "/\(path)"
  components.queryItems = queryItems
  appendSimklRequiredQueryItems(to: &components)
  return components.url!
}

func prepareSimklRequest(_ request: URLRequest) -> URLRequest {
  var preparedRequest = request
  if let url = preparedRequest.url,
    url.host?.lowercased() == "api.simkl.com",
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
  {
    appendSimklRequiredQueryItems(to: &components)
    preparedRequest.url = components.url
    preparedRequest.cachePolicy = .reloadIgnoringLocalCacheData
  }

  configureSimklHeaders(on: &preparedRequest)
  return preparedRequest
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
  func simklData(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await data(for: prepareSimklRequest(request))
  }
}

func performSimklRequest(_ request: URLRequest, retryCount: Int = 2) async throws -> (
  Data, HTTPURLResponse
) {
  var attempt = 0
  var retryDelayNanoseconds: UInt64 = 500_000_000

  while true {
    do {
      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw SimklMutationError.invalidResponse
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        throw SimklMutationError.httpStatusCode(
          httpResponse.statusCode,
          reason: parseSimklServerErrorReason(from: data)
        )
      }

      return (data, httpResponse)
    } catch {
      if attempt >= retryCount || !shouldRetrySimklMutation(error) {
        throw error
      }

      try await Task.sleep(nanoseconds: retryDelayNanoseconds)
      retryDelayNanoseconds *= 2
      attempt += 1
    }
  }
}

func performSimklMutationRequest(_ request: URLRequest, retryCount: Int = 2) async throws {
  _ = try await performSimklRequest(request, retryCount: retryCount)
}

func simklMutationUserMessage(for error: Error) -> String {
  if let simklError = error as? SimklMutationError {
    switch simklError {
    case .invalidResponse:
      return "Could not read Simkl's response. Please try again."
    case .invalidEpisode:
      return "This episode has invalid season or episode information."
    case .httpStatusCode(let statusCode, _):
      if statusCode == 401 {
        return "Your Simkl session has expired. Please sign in again."
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

func parseSimklServerErrorReason(from data: Data) -> SimklServerErrorReason? {
  guard data.count <= 64 * 1024,
    let object = try? JSONSerialization.jsonObject(with: data),
    let root = object as? [String: Any]
  else { return nil }

  let nestedError = root["error"] as? [String: Any]
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
    code: sanitizedSimklErrorCode(rawCode),
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

private func appendSimklRequiredQueryItems(to components: inout URLComponents) {
  var queryItems = components.queryItems ?? []
  appendQueryItemIfMissing(URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID), to: &queryItems)
  appendQueryItemIfMissing(URLQueryItem(name: "app-name", value: SIMKL_APP_NAME), to: &queryItems)
  appendQueryItemIfMissing(
    URLQueryItem(name: "app-version", value: SIMKL_APP_VERSION), to: &queryItems)
  components.queryItems = queryItems
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

private func configureSimklHeaders(on request: inout URLRequest, accessToken: String? = nil) {
  guard request.url?.host?.lowercased() == "api.simkl.com" else { return }

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

  if request.value(forHTTPHeaderField: "simkl-api-key") == nil {
    request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
  }

  if let accessToken,
    !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  {
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  }
}

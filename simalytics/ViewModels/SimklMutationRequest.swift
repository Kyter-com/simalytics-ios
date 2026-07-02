//
//  SimklMutationRequest.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/14/26.
//

import Foundation
import Sentry

enum SimklMutationError: Error {
  case invalidResponse
  case httpStatusCode(Int)

  var isRetryable: Bool {
    switch self {
    case .invalidResponse:
      return true
    case .httpStatusCode(let statusCode):
      return statusCode == 429 || (500...599).contains(statusCode)
    }
  }
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

func performSimklRequest(_ request: URLRequest, retryCount: Int = 2) async throws -> (Data, HTTPURLResponse) {
  var attempt = 0
  var retryDelayNanoseconds: UInt64 = 500_000_000

  while true {
    do {
      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw SimklMutationError.invalidResponse
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        throw SimklMutationError.httpStatusCode(httpResponse.statusCode)
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
    case .httpStatusCode(let statusCode):
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

func isSimklCancellationError(_ error: Error) -> Bool {
  if error is CancellationError {
    return true
  }

  if let urlError = error as? URLError, urlError.code == .cancelled {
    return true
  }

  return false
}

/// Reports an error to Sentry unless it's a user-initiated cancellation.
/// Cancellations happen routinely during navigation (users tapping away
/// before a fetch completes) and are not real errors.
func reportError(_ error: Error) {
  if isSimklCancellationError(error) { return }
  SentrySDK.capture(error: error)
}

private func shouldRetrySimklMutation(_ error: Error) -> Bool {
  if let simklError = error as? SimklMutationError {
    return simklError.isRetryable
  }

  if let urlError = error as? URLError {
    switch urlError.code {
    case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
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
  appendQueryItemIfMissing(URLQueryItem(name: "app-version", value: SIMKL_APP_VERSION), to: &queryItems)
  components.queryItems = queryItems
}

private func appendQueryItemIfMissing(_ queryItem: URLQueryItem, to queryItems: inout [URLQueryItem]) {
  guard !queryItems.contains(where: { $0.name.caseInsensitiveCompare(queryItem.name) == .orderedSame }) else {
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

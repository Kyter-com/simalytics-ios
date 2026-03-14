//
//  SimklMutationRequest.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/14/26.
//

import Foundation

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

func performSimklMutationRequest(_ request: URLRequest, retryCount: Int = 2) async throws {
  var attempt = 0
  var retryDelayNanoseconds: UInt64 = 500_000_000

  while true {
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw SimklMutationError.invalidResponse
      }

      guard (200...299).contains(httpResponse.statusCode) else {
        throw SimklMutationError.httpStatusCode(httpResponse.statusCode)
      }

      return
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

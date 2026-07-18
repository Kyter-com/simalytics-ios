//
//  SimklWatchedBatch.swift
//  simalytics
//
//  Shared batched POST helper for /sync/watched. The show and anime callers
//  only differ in the `type` field they put in the request body and the
//  model they decode the response into — everything else (chunking, auth
//  headers, status reporting, hadFailures bookkeeping) is identical.
//

import Foundation

// Result of a batched /sync/watched lookup. `hadFailures` lets callers
// decide whether the data is complete enough to stamp a "fresh" cache.
struct SimklWatchedBatch<T: Decodable & Sendable>: Sendable {
  let items: [T]
  let hadFailures: Bool
  let terminalRejectionCount: Int
}

struct SimklWatchedDecodedResponse<T: Decodable & Sendable>: Sendable {
  let items: [T]
  let terminalRejectionCount: Int
  let malformedItemCount: Int
}

private enum SimklWatchedElementDisposition<T> {
  case item(T)
  case terminalRejection
  case malformed
}

private struct SimklWatchedResponseElement<T: Decodable>: Decodable {
  private enum CodingKeys: String, CodingKey {
    case result, simkl, ids
  }

  private enum IDKeys: String, CodingKey {
    case simkl
  }

  let disposition: SimklWatchedElementDisposition<T>

  init(from decoder: Decoder) throws {
    do {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let topLevelID = try container.decodeIfPresent(Int.self, forKey: .simkl)
      let nestedID = try? container.nestedContainer(keyedBy: IDKeys.self, forKey: .ids)
        .decode(Int.self, forKey: .simkl)
      let hasIdentifier = topLevelID != nil || nestedID != nil

      if container.contains(.result) {
        if let result = try? container.decode(Bool.self, forKey: .result) {
          guard result else {
            disposition = .malformed
            return
          }
        } else if let result = try? container.decode(String.self, forKey: .result) {
          if result == "not_found", hasIdentifier {
            disposition = .terminalRejection
          } else {
            disposition = .malformed
          }
          return
        } else {
          disposition = .malformed
          return
        }
      }

      disposition = .item(try T(from: decoder))
    } catch {
      // The wrapper deliberately never throws for an individual element.
      // That lets valid siblings survive while the aggregate decoder records
      // a privacy-safe malformed count for telemetry and cache semantics.
      disposition = .malformed
    }
  }
}

func decodeSimklWatchedResponse<T: Decodable & Sendable>(
  _ type: T.Type,
  from data: Data
) throws -> SimklWatchedDecodedResponse<T> {
  let elements = try JSONDecoder().decode([SimklWatchedResponseElement<T>].self, from: data)
  var items: [T] = []
  var terminalRejectionCount = 0
  var malformedItemCount = 0

  for element in elements {
    switch element.disposition {
    case .item(let item):
      items.append(item)
    case .terminalRejection:
      terminalRejectionCount += 1
    case .malformed:
      malformedItemCount += 1
    }
  }

  return SimklWatchedDecodedResponse(
    items: items,
    terminalRejectionCount: terminalRejectionCount,
    malformedItemCount: malformedItemCount
  )
}

// POSTs `simklIDs` to /sync/watched in 100-item chunks (Simkl's documented
// cap when extended=episodes is set) and decodes each chunk into `[T]`.
// Non-200 chunks are flagged via `hadFailures` rather than thrown so a
// partial result is still usable. Deterministic client/auth failures are
// reported; transient Simkl/rate-limit responses are not app exceptions.
func simklWatchedBatch<T: Decodable & Sendable>(
  simklIDs: [Int],
  type: String,
  accessToken: String
) async -> SimklWatchedBatch<T> {
  guard !simklIDs.isEmpty else {
    return SimklWatchedBatch(items: [], hadFailures: false, terminalRejectionCount: 0)
  }
  let chunkSize = 100
  let chunks = stride(from: 0, to: simklIDs.count, by: chunkSize).map {
    Array(simklIDs[$0..<min($0 + chunkSize, simklIDs.count)])
  }

  var combined: [T] = []
  var hadFailures = false
  var terminalRejectionCount = 0
  for chunk in chunks {
    do {
      let url = URL(string: "https://api.simkl.com/sync/watched?extended=episodes,specials")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue(SIMKL_CLIENT_ID, forHTTPHeaderField: "simkl-api-key")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [[String: Any]] = chunk.map { ["ids": ["simkl": $0], "type": type] }
      request.httpBody = try JSONSerialization.data(withJSONObject: body)

      let (data, response) = try await URLSession.shared.simklData(for: request)
      if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
        if shouldReportWatchedLookupStatus(status) {
          reportError(
            NSError(
              domain: "Simkl", code: status,
              userInfo: [
                NSLocalizedDescriptionKey:
                  "Batched /sync/watched (\(type)) returned HTTP \(status) for \(chunk.count) ids"
              ]
            ))
        }
        hadFailures = true
        continue
      }
      let decoded = try decodeSimklWatchedResponse(T.self, from: data)
      combined.append(contentsOf: decoded.items)
      terminalRejectionCount += decoded.terminalRejectionCount
      if decoded.malformedItemCount > 0 {
        reportSimklWatchedSchemaIssue(
          type: type,
          malformedItemCount: decoded.malformedItemCount,
          responseItemCount: decoded.items.count + decoded.terminalRejectionCount
            + decoded.malformedItemCount
        )
        hadFailures = true
      }
    } catch {
      if error is DecodingError {
        reportSimklWatchedSchemaIssue(type: type, malformedItemCount: nil, responseItemCount: nil)
      } else {
        reportError(error)
      }
      hadFailures = true
    }
  }
  return SimklWatchedBatch(
    items: combined,
    hadFailures: hadFailures,
    terminalRejectionCount: terminalRejectionCount
  )
}

private func shouldReportWatchedLookupStatus(_ status: Int) -> Bool {
  status != 429 && !(500...599).contains(status)
}

func reportSimklWatchedSchemaIssue(
  type: String,
  malformedItemCount: Int?,
  responseItemCount: Int?
) {
  let detail: String
  if let malformedItemCount, let responseItemCount {
    detail =
      "preserved valid siblings; malformed items: \(malformedItemCount) of \(responseItemCount)"
  } else {
    detail = "response was not a decodable item array"
  }

  reportError(
    NSError(
      domain: "SimklWatchedResponse",
      code: 1,
      userInfo: [
        NSLocalizedDescriptionKey: "Batched /sync/watched (\(type)) schema mismatch; \(detail)"
      ]
    ))
}

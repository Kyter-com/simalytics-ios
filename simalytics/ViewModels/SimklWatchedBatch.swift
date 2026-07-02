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
  guard !simklIDs.isEmpty else { return SimklWatchedBatch(items: [], hadFailures: false) }
  let chunkSize = 100
  let chunks = stride(from: 0, to: simklIDs.count, by: chunkSize).map {
    Array(simklIDs[$0..<min($0 + chunkSize, simklIDs.count)])
  }

  var combined: [T] = []
  var hadFailures = false
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
          reportError(NSError(
            domain: "Simkl", code: status,
            userInfo: [NSLocalizedDescriptionKey: "Batched /sync/watched (\(type)) returned HTTP \(status) for \(chunk.count) ids"]
          ))
        }
        hadFailures = true
        continue
      }
      combined.append(contentsOf: try JSONDecoder().decode([T].self, from: data))
    } catch {
      reportError(error)
      hadFailures = true
    }
  }
  return SimklWatchedBatch(items: combined, hadFailures: hadFailures)
}

private func shouldReportWatchedLookupStatus(_ status: Int) -> Bool {
  status != 429 && !(500...599).contains(status)
}

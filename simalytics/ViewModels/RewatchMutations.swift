//
//  RewatchMutations.swift
//  simalytics
//

import Foundation

enum RewatchStartResult: Equatable, Sendable {
  /// `reused` is true when the title already had an active session, which
  /// SIMKL returns instead of opening another; its episodes are already there.
  case started(rewatchID: Int, reused: Bool)
  case cancelled
  case failed(userMessage: String)
}

struct RewatchLogResult: Equatable, Sendable {
  let result: SimklMutationResult
  /// SIMKL finished the rewatch: it now covers every aired regular episode.
  var completed = false
}

struct RewatchRemovalResult: Equatable, Sendable {
  let result: SimklMutationResult
  /// SIMKL deletes a session when its last episode is removed.
  let sessionEnded: Bool
}

enum MovieRewatchLogResult: Equatable, Sendable {
  case logged(rewatchID: Int)
  case cancelled
  case failed(userMessage: String)
}

enum MovieRewatchRemovalResult: Equatable, Sendable {
  case removed
  /// SIMKL no longer had it, such as one deleted on simkl.com.
  case gone
  case cancelled
  case failed(userMessage: String)
}

/// Writes for one rewatch session. Each comes from an explicit user action and
/// pins the session's `rewatch_id`; none are retried automatically, because
/// SIMKL warns that retried rewatch writes create phantom sessions.
/// See https://api.simkl.org/guides/rewatches
enum RewatchMutation {
  static let notLoggedMessage =
    "Simkl didn't log this rewatch. It skips an episode watched again within 2 days of the last time."
  static let notStartedMessage =
    "Simkl didn't start a rewatch. Rewatch tracking needs Simkl PRO or VIP, and each title can be rewatched up to 50 times."
  static let notStoppedMessage = "Simkl didn't stop this rewatch. Please try again."
  static let sessionGoneMessage = "This rewatch is no longer on Simkl, so it's been removed here."
  static let movieNotLoggedMessage =
    "Simkl didn't log this rewatch. It skips a movie watched again within 2 days of the last time."

  /// Logs a rewatch of a movie the user completed. SIMKL marks it complete
  /// right away; a reply that adds no movie means it was ignored, such as a
  /// second viewing within 2 days.
  static func logMovie(
    _ accessToken: String, simkl: Int, title: String?, session: URLSession = .shared
  ) async -> MovieRewatchLogResult {
    guard simkl > 0 else {
      let error = SimklMutationError.mediaNotFound
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }

    do {
      var item: [String: Any] = [
        "ids": ["simkl": simkl], "is_rewatch": true,
        "watched_at": ISO8601DateFormatter().string(from: Date()),
      ]
      if let title { item["title"] = title }
      let request = try historyRequest(accessToken, key: "movies", item: item)
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      let acknowledgement = try parseRewatchHistoryResponse(data, singleEpisode: false)
      guard acknowledgement.addedMovies == 1, let rewatchID = acknowledgement.rewatchID,
        rewatchID > 0
      else { return .failed(userMessage: movieNotLoggedMessage) }
      return .logged(rewatchID: rewatchID)
    } catch {
      switch await failure(error) {
      case .failed(let message): return .failed(userMessage: message)
      case .cancelled, .succeeded: return .cancelled
      }
    }
  }

  /// Deletes one movie rewatch; the first watch is untouched.
  static func removeMovieRewatch(
    _ accessToken: String, simkl: Int, rewatchID: Int, session: URLSession = .shared
  ) async -> MovieRewatchRemovalResult {
    guard simkl > 0, rewatchID > 0 else {
      let error = SimklMutationError.mediaNotFound
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }

    do {
      var request = URLRequest(url: simklAPIURL(path: "sync/history/remove"))
      request.httpMethod = "POST"
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "movies": [["ids": ["simkl": simkl], "rewatch_id": rewatchID]]
      ])
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      guard try validateRewatchRemovalResponse(data) else { throw SimklMutationError.mediaNotFound }
      return .removed
    } catch {
      if isSimklCancellationError(error) { return .cancelled }
      if error as? SimklMutationError == .mediaNotFound { return .gone }
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }
  }

  static func markEpisodeWatched(
    _ accessToken: String, _ rewatch: RewatchSession, _ episode: RewatchEpisode,
    session: URLSession = .shared
  ) async -> RewatchLogResult {
    guard rewatch.id > 0, rewatch.simkl > 0,
      validatedSimklEpisode(season: episode.season, episode: episode.episode) != nil
    else {
      let error = SimklMutationError.invalidEpisode
      reportError(error)
      return RewatchLogResult(result: .failed(userMessage: simklMutationUserMessage(for: error)))
    }

    do {
      let watchedAt = ISO8601DateFormatter().string(from: Date())
      let episodes: [[String: Any]] = [["number": episode.episode, "watched_at": watchedAt]]
      let seasons: [[String: Any]] = [["number": episode.season, "episodes": episodes]]
      let request = try historyRequest(
        accessToken, kind: rewatch.kind,
        item: item(for: rewatch, ["rewatch_id": rewatch.id, "seasons": seasons]))
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      let acknowledgement = try parseRewatchHistoryResponse(data, singleEpisode: true)
      try await undoFork(acknowledgement, of: rewatch, accessToken: accessToken, session: session)
      // Zero means SIMKL ignored it: too soon after the last watch of this
      // episode, or a date that matches the first watch.
      guard acknowledgement.addedEpisodes == 1 else {
        return RewatchLogResult(result: .failed(userMessage: notLoggedMessage))
      }
      return RewatchLogResult(
        result: .succeeded, completed: acknowledgement.rewatchStatus == "completed")
    } catch {
      return RewatchLogResult(result: await failure(error, rewatch: rewatch))
    }
  }

  /// Removes the episode from this session only; the first watch is untouched.
  static func markEpisodeUnwatched(
    _ accessToken: String, _ rewatch: RewatchSession, _ episode: RewatchEpisode,
    session: URLSession = .shared
  ) async -> RewatchRemovalResult {
    guard rewatch.id > 0, rewatch.simkl > 0,
      validatedSimklEpisode(season: episode.season, episode: episode.episode) != nil
    else {
      let error = SimklMutationError.invalidEpisode
      reportError(error)
      return RewatchRemovalResult(
        result: .failed(userMessage: simklMutationUserMessage(for: error)), sessionEnded: false)
    }

    do {
      var request = URLRequest(url: simklAPIURL(path: "sync/history/remove"))
      request.httpMethod = "POST"
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      let body: [String: Any] = [
        "shows": [
          [
            "title": rewatch.title ?? "",
            "ids": ["simkl": rewatch.simkl],
            "rewatch_id": rewatch.id,
            "seasons": [["number": episode.season, "episodes": [["number": episode.episode]]]],
          ]
        ]
      ]
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      let sessionEnded = try validateRewatchRemovalResponse(data)
      return RewatchRemovalResult(result: .succeeded, sessionEnded: sessionEnded)
    } catch {
      return RewatchRemovalResult(
        result: await failure(error, rewatch: rewatch), sessionEnded: false)
    }
  }

  /// Opens an empty session. Only offered for Completed titles: a show posted
  /// without episodes is otherwise auto-filled as watched, which is also why
  /// `skip_auto_watching=yes` rides along.
  static func start(
    _ accessToken: String, simkl: Int, kind: RewatchKind, title: String?,
    session: URLSession = .shared
  ) async -> RewatchStartResult {
    guard simkl > 0 else {
      let error = SimklMutationError.mediaNotFound
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }

    do {
      var item: [String: Any] = [
        "ids": ["simkl": simkl], "is_rewatch": true, "rewatch_status": "active",
      ]
      if let title { item["title"] = title }
      let request = try historyRequest(accessToken, kind: kind, item: item, skipAutoWatching: true)
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      let acknowledgement = try parseRewatchHistoryResponse(data, singleEpisode: false)
      guard let rewatchID = acknowledgement.rewatchID, rewatchID > 0,
        acknowledgement.rewatchStatus == "active"
      else { return .failed(userMessage: notStartedMessage) }
      return .started(rewatchID: rewatchID, reused: acknowledgement.addedShows == 0)
    } catch {
      switch await failure(error) {
      case .failed(let message): return .failed(userMessage: message)
      case .cancelled, .succeeded: return .cancelled
      }
    }
  }

  /// Closes the session. SIMKL keeps its progress, so it stays resumable there.
  static func stop(
    _ accessToken: String, _ rewatch: RewatchSession, session: URLSession = .shared
  ) async -> SimklMutationResult {
    guard rewatch.id > 0, rewatch.simkl > 0 else {
      let error = SimklMutationError.mediaNotFound
      reportError(error)
      return .failed(userMessage: simklMutationUserMessage(for: error))
    }

    do {
      let request = try historyRequest(
        accessToken, kind: rewatch.kind,
        item: item(for: rewatch, ["rewatch_id": rewatch.id, "rewatch_status": "closed"]),
        skipAutoWatching: true)
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      let acknowledgement = try parseRewatchHistoryResponse(data, singleEpisode: false)
      try await undoFork(acknowledgement, of: rewatch, accessToken: accessToken, session: session)
      // Closing a session SIMKL already completed is a no-op that reports `completed`.
      return ["closed", "completed"].contains(acknowledgement.rewatchStatus)
        ? .succeeded : .failed(userMessage: notStoppedMessage)
    } catch {
      return await failure(error, rewatch: rewatch)
    }
  }

  /// A write pinned to a session SIMKL no longer has, such as one deleted on
  /// simkl.com, doesn't fail: SIMKL opens a new session for it and reports
  /// that one's `rewatch_id`. Unless the pinned session still exists (SIMKL
  /// splits a session when an episode is written again days apart), the new
  /// one is a phantom, so it's deleted and the pinned session is reported gone.
  private static func undoFork(
    _ acknowledgement: RewatchHistoryAcknowledgement, of rewatch: RewatchSession,
    accessToken: String, session: URLSession
  ) async throws {
    guard let forkedID = acknowledgement.rewatchID, forkedID > 0, forkedID != rewatch.id,
      let membership = try await fetchRewatchMembership(
        rewatch.kind, accessToken: accessToken, session: session),
      membership.titles[rewatch.id] == nil,
      membership.titles[forkedID] == rewatch.simkl
    else { return }
    do {
      var request = URLRequest(url: simklAPIURL(path: "sync/history/remove"))
      request.httpMethod = "POST"
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.httpBody = try JSONSerialization.data(withJSONObject: [
        "shows": [["ids": ["simkl": rewatch.simkl], "rewatch_id": forkedID]]
      ])
      let (data, _) = try await performSimklRequest(request, retryCount: 0, session: session)
      _ = try validateRewatchRemovalResponse(data)
    } catch {
      if isSimklCancellationError(error) { throw error }
      reportError(error)
    }
    throw SimklMutationError.mediaNotFound
  }

  private static func item(for rewatch: RewatchSession, _ fields: [String: Any]) -> [String: Any] {
    var item: [String: Any] = ["ids": ["simkl": rewatch.simkl], "is_rewatch": true]
    if let title = rewatch.title { item["title"] = title }
    return item.merging(fields) { _, new in new }
  }

  private static func historyRequest(
    _ accessToken: String, kind: RewatchKind, item: [String: Any], skipAutoWatching: Bool = false
  ) throws -> URLRequest {
    try historyRequest(
      accessToken, key: kind.libraryKey, item: item, skipAutoWatching: skipAutoWatching)
  }

  /// `key` is the body's list: `shows`, `anime`, or `movies`.
  private static func historyRequest(
    _ accessToken: String, key: String, item: [String: Any], skipAutoWatching: Bool = false
  ) throws -> URLRequest {
    var queryItems = [URLQueryItem(name: "allow_rewatch", value: "yes")]
    if skipAutoWatching {
      queryItems.append(URLQueryItem(name: "skip_auto_watching", value: "yes"))
    }
    var request = URLRequest(url: simklAPIURL(path: "sync/history", queryItems: queryItems))
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONSerialization.data(withJSONObject: [key: [item]])
    return request
  }

  /// SIMKL answers `not_found` for the title when the `rewatch_id` is no
  /// longer this user's session for it, such as one deleted on simkl.com, so
  /// the local copy goes too.
  private static func failure(_ error: Error, rewatch: RewatchSession? = nil) async
    -> SimklMutationResult
  {
    if isSimklCancellationError(error) { return .cancelled }
    if let rewatch, error as? SimklMutationError == .mediaNotFound {
      await RewatchStore.shared.removeSession(id: rewatch.id)
      return .failed(userMessage: sessionGoneMessage)
    }
    reportError(error)
    return .failed(userMessage: simklMutationUserMessage(for: error))
  }
}

// MARK: - Responses

struct RewatchHistoryAcknowledgement: Equatable, Sendable {
  let addedEpisodes: Int
  /// Sessions the write created. Zero on a Start means SIMKL returned the
  /// title's existing active session.
  var addedShows = 0
  /// Movie rewatches the write created; zero means SIMKL ignored it.
  var addedMovies = 0
  let rewatchID: Int?
  let rewatchStatus: String?

  init(
    addedEpisodes: Int, addedShows: Int = 0, addedMovies: Int = 0, rewatchID: Int?,
    rewatchStatus: String?
  ) {
    self.addedEpisodes = addedEpisodes
    self.addedShows = addedShows
    self.addedMovies = addedMovies
    self.rewatchID = rewatchID
    self.rewatchStatus = rewatchStatus
  }
}

/// Rewatch writes answer like any `/sync/history` write, plus the session's
/// `rewatch_id` and `rewatch_status` in `added.statuses[].response`.
func parseRewatchHistoryResponse(_ data: Data, singleEpisode: Bool) throws
  -> RewatchHistoryAcknowledgement
{
  let response: RewatchHistoryResponse
  do {
    response = try JSONDecoder().decode(RewatchHistoryResponse.self, from: data)
  } catch {
    throw SimklMutationError.invalidResponse
  }
  let addedEpisodes = response.added.episodes ?? 0
  guard (0...1).contains(addedEpisodes), !singleEpisode || response.added.episodes != nil else {
    throw SimklMutationError.invalidResponse
  }
  if let rejection = response.notFound.error { throw rejection }
  let outcome = response.added.statuses?.lazy.compactMap(\.response).first {
    $0.rewatch_id != nil || $0.rewatch_status != nil
  }
  return RewatchHistoryAcknowledgement(
    addedEpisodes: addedEpisodes,
    addedShows: (response.added.shows ?? 0) + (response.added.anime ?? 0),
    addedMovies: response.added.movies ?? 0,
    rewatchID: outcome?.rewatch_id, rewatchStatus: outcome?.rewatch_status)
}

/// True when SIMKL deleted the session along with its last episode. A
/// response that unmarked the first watch, which a `rewatch_id` must never
/// touch, is rejected.
func validateRewatchRemovalResponse(_ data: Data) throws -> Bool {
  let response: RewatchRemovalResponse
  do {
    response = try JSONDecoder().decode(RewatchRemovalResponse.self, from: data)
  } catch {
    throw SimklMutationError.invalidResponse
  }
  if let rejection = response.notFound.error { throw rejection }
  let deleted = response.deleted
  guard deleted.values.allSatisfy({ $0 >= 0 }),
    deleted["movies", default: 0] == 0, deleted["shows", default: 0] == 0,
    deleted["episodes", default: 0] == 0,
    (0...1).contains(deleted["rewatch_episodes", default: 0])
  else { throw SimklMutationError.invalidResponse }
  return deleted["rewatches", default: 0] > 0
}

private struct RewatchHistoryResponse: Decodable {
  let added: Added
  let notFound: RewatchRejections

  enum CodingKeys: String, CodingKey {
    case added
    case notFound = "not_found"
  }

  struct Added: Decodable {
    let episodes: Int?
    let shows: Int?
    let anime: Int?
    let movies: Int?
    let statuses: [Status]?
  }

  struct Status: Decodable {
    let response: Outcome?
  }

  /// `response.status` is a number on show rewatch writes and a string
  /// everywhere else, so only the rewatch fields are read.
  struct Outcome: Decodable {
    let rewatch_id: Int?
    let rewatch_status: String?

    private enum CodingKeys: String, CodingKey {
      case rewatch_id, rewatch_status
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      rewatch_id = try? container.decodeIfPresent(Int.self, forKey: .rewatch_id)
      rewatch_status = try? container.decodeIfPresent(String.self, forKey: .rewatch_status)
    }
  }
}

private struct RewatchRemovalResponse: Decodable {
  let deleted: [String: Int]
  let notFound: RewatchRejections

  enum CodingKeys: String, CodingKey {
    case deleted
    case notFound = "not_found"
  }
}

private struct RewatchRejections: Decodable {
  let movies: [Rejected]?
  let shows: [Rejected]?
  let episodes: [Rejected]?
  let anime: [Rejected]?

  struct Rejected: Decodable {}

  /// A rejected title means it, or its `rewatch_id`, didn't match; a rejected
  /// episode is one the matched title doesn't have.
  var error: SimklMutationError? {
    if [movies, shows, anime].contains(where: { !($0?.isEmpty ?? true) }) { return .mediaNotFound }
    if !(episodes?.isEmpty ?? true) { return .episodeNotFound }
    return nil
  }
}

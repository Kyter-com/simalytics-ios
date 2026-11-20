import Foundation
import Testing
import os

@testable import Simalytics

/// Requests and responses follow what SIMKL's live API returned for a VIP
/// account on 2026-11-20, where it differs from the Rewatches guide: deltas
/// list only changed rows, deleted sessions never appear in one, and a write
/// pinned to a deleted session opens a new session instead of failing.
@Suite("Rewatch request/response contract")
struct RewatchContractTests {
  static let show = RewatchSession(
    id: 7482, simkl: 17465, kind: .tv, title: "Game of Thrones",
    episodes: (1...4).map { RewatchEpisode(season: 1, episode: $0) })
  static let anime = RewatchSession(
    id: 7484, simkl: 37089, kind: .anime, title: "Cowboy Bebop", animeType: "tv",
    episodes: (1...2).map { RewatchEpisode(season: 1, episode: $0) })

  private func fixtureSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RewatchFixtureProtocol.self]
    return URLSession(configuration: config)
  }

  @Test(
    "Logging an episode pins the session and accepts SIMKL's numeric show status",
    arguments: [RewatchKind.tv, .anime])
  func logsEpisode(kind: RewatchKind) async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let rewatch = kind == .tv ? Self.show : Self.anime
    let result = await RewatchMutation.markEpisodeWatched(
      "logged", rewatch, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result == RewatchLogResult(result: .succeeded))
  }

  @Test("Logging the last episode reports that SIMKL completed the rewatch")
  func completes() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "completes", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result == RewatchLogResult(result: .succeeded, completed: true))
  }

  @Test("A rewatch SIMKL ignored, like one within 2 days, is not reported as logged")
  func ignoredRewatch() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "ignored", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result.result == .failed(userMessage: RewatchMutation.notLoggedMessage))
  }

  @Test("A session SIMKL no longer has is reported as gone, not logged")
  func unknownSession() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "not-found", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result.result == .failed(userMessage: RewatchMutation.sessionGoneMessage))
  }

  @Test("An episode the title doesn't have is not reported as logged")
  func unknownEpisode() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "missing-episode", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(
      result.result
        == .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.episodeNotFound)))
  }

  @Test("Logging to a session deleted on simkl.com deletes the session SIMKL opened instead")
  func forkedLog() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "forked", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result.result == .failed(userMessage: RewatchMutation.sessionGoneMessage))
    #expect(RewatchFixtureProtocol.requests(for: "forked").contains("POST remove rewatch 9100"))
  }

  @Test("A session SIMKL split, which still exists, keeps the new one")
  func splitLog() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "split", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result == RewatchLogResult(result: .succeeded))
    #expect(!RewatchFixtureProtocol.requests(for: "split").contains { $0.hasPrefix("POST remove") })
  }

  @Test(
    "Unmarking removes the episode from the session and never the first watch",
    arguments: [
      ("removed", RewatchRemovalResult(result: .succeeded, sessionEnded: false)),
      ("last-episode", RewatchRemovalResult(result: .succeeded, sessionEnded: true)),
      (
        "first-watch-touched",
        RewatchRemovalResult(
          result: .failed(
            userMessage: simklMutationUserMessage(for: SimklMutationError.invalidResponse)),
          sessionEnded: false)
      ),
    ])
  func unmarks(scenario: String, expected: RewatchRemovalResult) async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeUnwatched(
      scenario, Self.show, RewatchEpisode(season: 1, episode: 4), session: session)
    #expect(result == expected)
  }

  @Test("Starting opens an empty session without auto-filling episodes")
  func starts() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let started = await RewatchMutation.start(
      "started", simkl: 17465, kind: .tv, title: "Game of Thrones", session: session)
    #expect(started == .started(rewatchID: 9001, reused: false))
    let reused = await RewatchMutation.start(
      "start-reused", simkl: 17465, kind: .tv, title: "Game of Thrones", session: session)
    #expect(reused == .started(rewatchID: 7482, reused: true))
    let refused = await RewatchMutation.start(
      "free-plan", simkl: 17465, kind: .tv, title: "Game of Thrones", session: session)
    #expect(refused == .failed(userMessage: RewatchMutation.notStartedMessage))
  }

  @Test(
    "Stopping closes the pinned session, or finds it already complete",
    arguments: ["closed", "completed"])
  func stops(scenario: String) async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    #expect(await RewatchMutation.stop(scenario, Self.show, session: session) == .succeeded)
  }

  @Test("Stopping a session deleted on simkl.com deletes the closed one SIMKL opened")
  func forkedStop() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.stop("forked-stop", Self.show, session: session)
    #expect(result == .failed(userMessage: RewatchMutation.sessionGoneMessage))
    #expect(
      RewatchFixtureProtocol.requests(for: "forked-stop").contains("POST remove rewatch 9102"))
  }

  @Test("The plan comes from account.type, and a missing plan reads as free")
  func plan() async throws {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    #expect(try await fetchSimklAccountType("vip", session: session) == "vip")
    #expect(try await fetchSimklAccountType("no-account", session: session) == "free")
  }

  @Test("One full pull, then only changes, even days later")
  func pulls() async throws {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let firstSync = Date(timeIntervalSince1970: 1_800_000_000)

    let fullPull = try await pullRewatchSessions(
      .tv, accessToken: "full", activity: "2026-11-17T10:00:00Z", cached: [], cachedCounts: [:],
      cursor: RewatchStore.Cursor(), refreshUpNext: false, session: session, now: firstSync)
    let full = try #require(fullPull)
    #expect(
      full.cursor == RewatchStore.Cursor(activity: "2026-11-17T10:00:00Z", baselineAt: firstSync))
    #expect(full.sessionCounts == [17465: 2])
    let pulled = try #require(full.sessions.first)
    #expect(full.sessions.count == 1)
    #expect(pulled.id == 7482)
    #expect(
      pulled.next
        == RewatchNextEpisode(
          season: 1, episode: 5, title: "The Wolf and the Lion", date: "2011-05-08T21:00:00-04:00"))
    #expect(pulled.nextResolvedAt == firstSync)

    // The fixture rejects a pull without date_from here, so this proves no
    // full pull repeats however long ago the first one was.
    let laterSync = firstSync.addingTimeInterval(2 * 24 * 60 * 60)
    let deltaPull = try await pullRewatchSessions(
      .tv, accessToken: "delta", activity: "2026-11-17T11:00:00Z", cached: full.sessions,
      cachedCounts: full.sessionCounts, cursor: full.cursor, refreshUpNext: false,
      session: session, now: laterSync)
    let delta = try #require(deltaPull)
    #expect(
      delta.cursor == RewatchStore.Cursor(activity: "2026-11-17T11:00:00Z", baselineAt: firstSync))
    #expect(delta.sessions.first?.watchedCount == 5)
    #expect(delta.sessions.first?.next?.episode == 6)

    let idle = try await pullRewatchSessions(
      .tv, accessToken: "unexpected", activity: "2026-11-17T11:00:00Z", cached: delta.sessions,
      cachedCounts: delta.sessionCounts, cursor: delta.cursor, refreshUpNext: false,
      session: session, now: laterSync)
    #expect(idle == nil)

    // A write elsewhere in the app forces Up Next, and with it the sessions.
    let forced = try await pullRewatchSessions(
      .tv, accessToken: "delta-forced", activity: "2026-11-17T11:00:00Z",
      cached: delta.sessions, cachedCounts: delta.sessionCounts, cursor: delta.cursor,
      refreshUpNext: true, session: session, now: laterSync)
    #expect(forced?.sessions.first?.watchedCount == 5)

    // A delta that lists only another title's first watch keeps the session.
    let unrelated = try await pullRewatchSessions(
      .tv, accessToken: "delta-unrelated", activity: "2026-11-17T12:00:00Z",
      cached: delta.sessions, cachedCounts: delta.sessionCounts, cursor: delta.cursor,
      refreshUpNext: false, session: session, now: laterSync)
    #expect(unrelated?.sessions == delta.sessions)
    #expect(unrelated?.sessionCounts == [17465: 2])

    // Deleted on simkl.com: no delta lists it, so the membership list drops it.
    let deleted = try await pullRewatchSessions(
      .tv, accessToken: "delta-deleted", activity: "2026-11-17T12:00:00Z",
      cached: delta.sessions, cachedCounts: delta.sessionCounts, cursor: delta.cursor,
      refreshUpNext: false, session: session, now: laterSync)
    #expect(deleted?.sessions.isEmpty == true)
    #expect(deleted?.sessionCounts == [17465: 1])
  }

  @Test("An active session that no delta described is read in full")
  func missingSessionIsRead() async throws {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let pull = try await pullRewatchSessions(
      .tv, accessToken: "delta-missing", activity: "2026-11-17T12:00:00Z",
      cached: [], cachedCounts: [:],
      cursor: RewatchStore.Cursor(activity: "2026-11-17T11:00:00Z", baselineAt: Date()),
      refreshUpNext: false, session: session, now: Date())
    #expect(pull?.sessions.map(\.id) == [7482])
    #expect(pull?.sessions.first?.watchedCount == 4)
  }

  @Test("A library too large for one call is read list by list")
  func splitsLargeLibraries() async throws {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let pull = try await pullRewatchSessions(
      .tv, accessToken: "full-too-big", activity: "2026-11-17T10:00:00Z", cached: [],
      cachedCounts: [:], cursor: RewatchStore.Cursor(), refreshUpNext: false, session: session,
      now: Date())
    #expect(pull?.sessions.map(\.id) == [7482])
    let paths = RewatchFixtureProtocol.requests(for: "full-too-big")
    for status in ["completed", "watching", "hold", "dropped"] {
      #expect(paths.contains("GET /sync/all-items/shows/\(status) full"))
    }
    #expect(!paths.contains("GET /sync/all-items/shows/plantowatch full"))
  }
}

/// No live writes: a request that doesn't match the documented rewatch shape
/// gets a 400, so each success proves the method, path, flags, and body.
private final class RewatchFixtureProtocol: URLProtocol, @unchecked Sendable {
  private static let log = OSAllocatedUnfairLock<[(scenario: String, entry: String)]>(
    initialState: [])

  /// What a scenario's requests did, in order, such as "POST remove rewatch 9100".
  static func requests(for scenario: String) -> [String] {
    log.withLock { $0.filter { $0.scenario == scenario }.map(\.entry) }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let scenario =
      request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(
        of: "Bearer ", with: "") ?? ""
    let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
    let query = Dictionary(
      (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") },
      uniquingKeysWith: { first, _ in first })
    let hasAppParameters =
      ["client_id", "app-name", "app-version"].allSatisfy { query[$0] != nil }
      && request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("simalytics-ios/") == true
      && request.value(forHTTPHeaderField: "simkl-api-key") != nil

    let method = request.httpMethod ?? "GET"
    let path = components?.path ?? ""
    let reply: (Int, String)
    switch (method, path) {
    case ("POST", "/sync/history"): reply = history(scenario, query)
    case ("POST", "/sync/history/remove"):
      let removedID = payload?.item["rewatch_id"] as? Int
      Self.log.withLock { $0.append((scenario, "POST remove rewatch \(removedID ?? 0)")) }
      reply = removal(scenario, query)
    case ("GET", let library) where library.hasPrefix("/sync/all-items/shows"):
      let status = library.dropFirst("/sync/all-items/shows".count).trimmingCharacters(
        in: CharacterSet(charactersIn: "/"))
      Self.log.withLock {
        $0.append((scenario, "GET \(library) \(query["extended"] ?? "")"))
      }
      reply = self.library(scenario, query, status: status.isEmpty ? nil : status)
    case ("GET", "/tv/episodes/17465"): reply = (200, Self.catalog)
    case ("GET", "/users/settings"):
      reply = (
        200,
        scenario == "vip"
          ? #"{"user":{"name":"andy"},"account":{"id":1,"timezone":"UTC","type":"vip"}}"#
          : #"{"user":{"name":"andy"}}"#
      )
    default: reply = (500, "{}")
    }
    let status = hasAppParameters ? reply.0 : 400
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data((status == reply.0 ? reply.1 : "{}").utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private var body: [String: Any]? {
    var data = request.httpBody
    if data == nil, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var collected = Data()
      var bytes = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count <= 0 { break }
        collected.append(contentsOf: bytes.prefix(count))
      }
      data = collected
    }
    return data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
  }

  /// The single item under `shows` or `anime`, and which key held it.
  private var payload: (key: String, item: [String: Any])? {
    guard let body, body.count == 1, let key = body.keys.first,
      let items = body[key] as? [[String: Any]], items.count == 1
    else { return nil }
    return (key, items[0])
  }

  private static let logScenarios: Set = [
    "logged", "ignored", "not-found", "missing-episode", "completes", "forked", "split",
  ]

  private func history(_ scenario: String, _ query: [String: String]) -> (Int, String) {
    guard query["allow_rewatch"] == "yes", let payload, payload.item["is_rewatch"] as? Bool == true
    else { return (400, "{}") }
    let key = payload.key
    let item = payload.item
    let ids = item["ids"] as? [String: Any]
    let episodes = (item["seasons"] as? [[String: Any]])?.first?["episodes"] as? [[String: Any]]

    switch scenario {
    case _ where Self.logScenarios.contains(scenario):
      let isAnime = key == "anime"
      let seasons = item["seasons"] as? [[String: Any]]
      let watchedAt = (episodes?.first?["watched_at"] as? String).flatMap {
        ISO8601DateFormatter().date(from: $0)
      }
      guard query["skip_auto_watching"] == nil, key == (isAnime ? "anime" : "shows"),
        ids?["simkl"] as? Int == (isAnime ? 37089 : 17465),
        item["rewatch_id"] as? Int == (isAnime ? 7484 : 7482), item["rewatch_status"] == nil,
        seasons?.count == 1, seasons?.first?["number"] as? Int == 1, episodes?.count == 1,
        episodes?.first?["number"] as? Int == 5, watchedAt != nil
      else { return (400, "{}") }
      switch scenario {
      case "logged", "completes":
        let status = scenario == "completes" ? "completed" : "active"
        let rewatchID = isAnime ? 7484 : 7482
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":1,"statuses":[{"request":{},"response":{"status":1,"simkl_type":"tv","rewatch_id":\#(rewatchID),"rewatch_status":"\#(status)"}}]},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#
        )
      case "forked", "split":
        // As live: a new session, with the episode, under a new id.
        return (
          201,
          #"{"added":{"movies":0,"shows":1,"episodes":1,"statuses":[{"request":{},"response":{"status":3,"simkl_type":"tv","anime_type":null,"rewatch_id":9100,"rewatch_status":"active"}}]},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#
        )
      case "ignored":
        // As live: the running session still answers with its id.
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":0,"statuses":[{"request":{},"response":{"status":3,"simkl_type":"tv","rewatch_id":7482,"rewatch_status":"active"}}]},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#
        )
      case "missing-episode":
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":0},"not_found":{"movies":[],"shows":[],"episodes":[{"ids":{"simkl":17465},"seasons":[{"number":1,"episodes":[{"number":5}]}]}]}}"#
        )
      default:
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":0},"not_found":{"movies":[],"shows":[{"ids":{"simkl":17465}}]}}"#
        )
      }

    case "started", "free-plan", "start-reused":
      guard query["skip_auto_watching"] == "yes", key == "shows", ids?["simkl"] as? Int == 17465,
        item["rewatch_status"] as? String == "active", item["rewatch_id"] == nil,
        item["seasons"] == nil
      else { return (400, "{}") }
      switch scenario {
      case "started":
        return (
          201,
          #"{"added":{"movies":0,"shows":1,"episodes":0,"statuses":[{"response":{"status":3,"simkl_type":"tv","rewatch_id":9001,"rewatch_status":"active"}}]},"not_found":{"movies":[],"shows":[]}}"#
        )
      case "start-reused":
        // As live: an active session already existed, so nothing was added.
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":0,"statuses":[{"response":{"status":3,"simkl_type":"tv","rewatch_id":7482,"rewatch_status":"active"}}]},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#
        )
      default:
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":0,"statuses":[{"response":{"status":"completed","simkl_type":"tv"}}]},"not_found":{"movies":[],"shows":[]}}"#
        )
      }

    case "closed", "completed", "forked-stop":
      guard query["skip_auto_watching"] == "yes", key == "shows", ids?["simkl"] as? Int == 17465,
        item["rewatch_id"] as? Int == 7482, item["rewatch_status"] as? String == "closed",
        item["seasons"] == nil
      else { return (400, "{}") }
      if scenario == "forked-stop" {
        // As live: closing a deleted session opens a new, closed one.
        return (
          201,
          #"{"added":{"movies":0,"shows":1,"episodes":0,"statuses":[{"response":{"status":3,"rewatch_id":9102,"rewatch_status":"closed"}}]},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#
        )
      }
      return (
        201,
        #"{"added":{"movies":0,"shows":0,"episodes":0,"statuses":[{"response":{"status":3,"rewatch_id":7482,"rewatch_status":"\#(scenario)"}}]},"not_found":{"movies":[],"shows":[]}}"#
      )

    default:
      return (400, "{}")
    }
  }

  private func removal(_ scenario: String, _ query: [String: String]) -> (Int, String) {
    guard query["allow_rewatch"] == nil, let payload, payload.key == "shows",
      (payload.item["ids"] as? [String: Any])?["simkl"] as? Int == 17465
    else { return (400, "{}") }
    let rewatchID = payload.item["rewatch_id"] as? Int
    if scenario == "forked" || scenario == "forked-stop" {
      // Deleting the whole forked session: its id and no episodes.
      guard rewatchID == (scenario == "forked" ? 9100 : 9102), payload.item["seasons"] == nil
      else { return (400, "{}") }
      return (
        201,
        #"{"deleted":{"movies":0,"shows":0,"episodes":0,"rewatches":1,"rewatch_episodes":0},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#
      )
    }
    guard rewatchID == 7482 else { return (400, "{}") }
    let seasons = payload.item["seasons"] as? [[String: Any]]
    let episodes = seasons?.first?["episodes"] as? [[String: Any]]
    guard seasons?.count == 1, seasons?.first?["number"] as? Int == 1, episodes?.count == 1,
      episodes?.first?["number"] as? Int == 4, episodes?.first?["watched_at"] == nil
    else { return (400, "{}") }
    let deleted: String
    switch scenario {
    case "removed":
      deleted = #""movies":0,"shows":0,"episodes":0,"rewatches":0,"rewatch_episodes":1"#
    case "last-episode":
      deleted = #""movies":0,"shows":0,"episodes":0,"rewatches":1,"rewatch_episodes":1"#
    case "first-watch-touched":
      deleted = #""movies":0,"shows":0,"episodes":1,"rewatches":0,"rewatch_episodes":0"#
    default:
      return (400, "{}")
    }
    return (201, #"{"deleted":{\#(deleted)},"not_found":{"movies":[],"shows":[],"episodes":[]}}"#)
  }

  private func library(_ scenario: String, _ query: [String: String], status: String?) -> (
    Int, String
  ) {
    guard query["allow_rewatch"] == "yes" else { return (400, "{}") }
    if query["extended"] == "simkl_ids_only" {
      guard status == nil, query["date_from"] == nil else { return (400, "{}") }
      return membership(scenario)
    }
    guard query["extended"] == "full" else { return (400, "{}") }
    switch (scenario, status, query["date_from"]) {
    case ("full", .none, .none): return (200, Self.rows(sessionEpisodes: 4))
    case ("delta", .none, .some("2026-11-17T09:55:00Z")):
      // Live deltas list only the changed rows: here, the session.
      return (200, Self.rows(sessionEpisodes: 5, canonical: false))
    case ("delta-forced", .none, .some("2026-11-17T10:55:00Z")):
      return (200, Self.rows(sessionEpisodes: 5, canonical: false))
    case ("delta-unrelated", .none, .some("2026-11-17T10:55:00Z")):
      return (
        200,
        #"{"shows":[{"status":"completed","user_rating":9,"show":{"title":"Lost","ids":{"simkl":7}},"is_rewatch":false}]}"#
      )
    case ("delta-deleted", .none, .some("2026-11-17T10:55:00Z")):
      // A deletion moves activities but leaves the delta empty.
      return (200, "{}")
    case ("delta-missing", .none, .some("2026-11-17T10:55:00Z")): return (200, "{}")
    case ("delta-missing", .none, .none): return (200, Self.rows(sessionEpisodes: 4))
    case ("full-too-big", .none, .none):
      return (400, #"{"error":"max_items","code":400,"message":"Too many items"}"#)
    case ("full-too-big", .some("completed"), .none): return (200, Self.rows(sessionEpisodes: 4))
    case ("full-too-big", .some("watching"), .none), ("full-too-big", .some("hold"), .none),
      ("full-too-big", .some("dropped"), .none):
      return (200, "{}")
    default: return (400, "{}")
    }
  }

  /// The `simkl_ids_only` list: every saved session, by id and status.
  private func membership(_ scenario: String) -> (Int, String) {
    let canonical = #"{"show":{"ids":{"simkl":17465}},"is_rewatch":false}"#
    func session(_ id: Int, _ status: String) -> String {
      #"{"show":{"ids":{"simkl":17465}},"is_rewatch":true,"rewatch_id":\#(id),"rewatch_status":"\#(status)"}"#
    }
    let rows: [String]
    switch scenario {
    case "full", "delta", "delta-forced", "delta-unrelated":
      rows = [canonical, session(7482, "active"), session(7000, "completed")]
    case "delta-deleted": rows = [canonical, session(7000, "completed")]
    case "delta-missing", "full-too-big": rows = [canonical, session(7482, "active")]
    case "forked": rows = [canonical, session(9100, "active")]
    case "split": rows = [canonical, session(7482, "closed"), session(9100, "active")]
    case "forked-stop": rows = [canonical, session(9102, "closed")]
    default: return (400, "{}")
    }
    return (200, #"{"shows":[\#(rows.joined(separator: ","))]}"#)
  }

  /// A canonical Game of Thrones row, and its active session unless it's gone.
  private static func rows(sessionEpisodes count: Int?, canonical includesCanonical: Bool = true)
    -> String
  {
    let canonical = #"""
      {"status":"completed","watched_episodes_count":73,"total_episodes_count":73,
       "not_aired_episodes_count":0,
       "show":{"title":"Game of Thrones","poster":"57/5742576cd8f59fcb0","ids":{"simkl":17465}},
       "is_rewatch":false}
      """#
    guard let count else { return #"{"shows":[\#(canonical)]}"# }
    let episodes = (1...count).map { #"{"number":\#($0)}"# }.joined(separator: ",")
    let rewatch = #"""
      {"status":"completed","watched_episodes_count":\#(count),"total_episodes_count":73,
       "not_aired_episodes_count":0,"last_watched":"S01E0\#(count)","next_to_watch":null,
       "show":{"title":"Game of Thrones","poster":"57/5742576cd8f59fcb0","ids":{"simkl":17465}},
       "is_rewatch":true,"rewatch_id":7482,"rewatch_status":"active",
       "seasons":[{"number":1,"episodes":[\#(episodes)]}]}
      """#
    return includesCanonical
      ? #"{"shows":[\#(canonical),\#(rewatch)]}"# : #"{"shows":[\#(rewatch)]}"#
  }

  private static let catalog = #"""
    [
      {"title":"Winter Is Coming","season":1,"episode":1,"type":"episode","aired":true,"ids":{"simkl_id":1}},
      {"title":"The Kingsroad","season":1,"episode":2,"type":"episode","aired":true,"ids":{"simkl_id":2}},
      {"title":"Lord Snow","season":1,"episode":3,"type":"episode","aired":true,"ids":{"simkl_id":3}},
      {"title":"Cripples, Bastards, and Broken Things","season":1,"episode":4,"type":"episode","aired":true,"ids":{"simkl_id":4}},
      {"title":"The Wolf and the Lion","season":1,"episode":5,"type":"episode","aired":true,"date":"2011-05-08T21:00:00-04:00","ids":{"simkl_id":5}},
      {"title":"A Golden Crown","season":1,"episode":6,"type":"episode","aired":true,"ids":{"simkl_id":6}},
      {"title":"Unaired Pilot","season":0,"episode":1,"type":"special","aired":true,"ids":{"simkl_id":7}}
    ]
    """#
}

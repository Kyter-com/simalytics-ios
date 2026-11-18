import Foundation
import Testing

@testable import Simalytics

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
    #expect(result == .succeeded)
  }

  @Test("A rewatch SIMKL ignored, like one within 2 days, is not reported as logged")
  func ignoredRewatch() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "ignored", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result == .failed(userMessage: RewatchMutation.notLoggedMessage))
  }

  @Test("A session SIMKL no longer has is reported as gone, not logged")
  func unknownSession() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "not-found", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(result == .failed(userMessage: RewatchMutation.sessionGoneMessage))
  }

  @Test("An episode the title doesn't have is not reported as logged")
  func unknownEpisode() async {
    let session = fixtureSession()
    defer { session.invalidateAndCancel() }
    let result = await RewatchMutation.markEpisodeWatched(
      "missing-episode", Self.show, RewatchEpisode(season: 1, episode: 5), session: session)
    #expect(
      result == .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.episodeNotFound)))
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
    #expect(started == .started(rewatchID: 9001))
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
    #expect(full.sessionCounts == [17465: 1])
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

    // Deleted on simkl.com: the title comes back with no sessions at all.
    let deleted = try await pullRewatchSessions(
      .tv, accessToken: "delta-deleted", activity: "2026-11-17T12:00:00Z",
      cached: delta.sessions, cachedCounts: delta.sessionCounts, cursor: delta.cursor,
      refreshUpNext: false, session: session, now: laterSync)
    #expect(deleted?.sessions.isEmpty == true)
    #expect(deleted?.sessionCounts.isEmpty == true)
  }
}

/// No live writes: a request that doesn't match the documented rewatch shape
/// gets a 400, so each success proves the method, path, flags, and body.
private final class RewatchFixtureProtocol: URLProtocol, @unchecked Sendable {
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

    let reply: (Int, String)
    switch (request.httpMethod ?? "GET", components?.path ?? "") {
    case ("POST", "/sync/history"): reply = history(scenario, query)
    case ("POST", "/sync/history/remove"): reply = removal(scenario, query)
    case ("GET", "/sync/all-items/shows"): reply = library(scenario, query)
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

  private func history(_ scenario: String, _ query: [String: String]) -> (Int, String) {
    guard query["allow_rewatch"] == "yes", let payload, payload.item["is_rewatch"] as? Bool == true
    else { return (400, "{}") }
    let key = payload.key
    let item = payload.item
    let ids = item["ids"] as? [String: Any]
    let episodes = (item["seasons"] as? [[String: Any]])?.first?["episodes"] as? [[String: Any]]

    switch scenario {
    case "logged", "ignored", "not-found", "missing-episode":
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
      case "logged":
        return (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":1,"statuses":[{"request":{},"response":{"status":1,"simkl_type":"tv","rewatch_id":7482,"rewatch_status":"active"}}]},"not_found":{"movies":[],"shows":[]}}"#
        )
      case "ignored":
        return (201, #"{"added":{"movies":0,"shows":0,"episodes":0},"not_found":{"movies":[],"shows":[]}}"#)
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

    case "started", "free-plan":
      guard query["skip_auto_watching"] == "yes", key == "shows", ids?["simkl"] as? Int == 17465,
        item["rewatch_status"] as? String == "active", item["rewatch_id"] == nil,
        item["seasons"] == nil
      else { return (400, "{}") }
      return scenario == "started"
        ? (
          201,
          #"{"added":{"movies":0,"shows":1,"episodes":0,"statuses":[{"response":{"status":3,"simkl_type":"tv","rewatch_id":9001,"rewatch_status":"active"}}]},"not_found":{"movies":[],"shows":[]}}"#
        )
        : (
          201,
          #"{"added":{"movies":0,"shows":0,"episodes":0,"statuses":[{"response":{"status":"completed","simkl_type":"tv"}}]},"not_found":{"movies":[],"shows":[]}}"#
        )

    case "closed", "completed":
      guard query["skip_auto_watching"] == "yes", key == "shows", ids?["simkl"] as? Int == 17465,
        item["rewatch_id"] as? Int == 7482, item["rewatch_status"] as? String == "closed",
        item["seasons"] == nil
      else { return (400, "{}") }
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
      (payload.item["ids"] as? [String: Any])?["simkl"] as? Int == 17465,
      payload.item["rewatch_id"] as? Int == 7482
    else { return (400, "{}") }
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

  private func library(_ scenario: String, _ query: [String: String]) -> (Int, String) {
    guard query["allow_rewatch"] == "yes", query["extended"] == "full" else { return (400, "{}") }
    switch (scenario, query["date_from"]) {
    case ("full", .none): return (200, Self.rows(sessionEpisodes: 4))
    case ("delta", .some("2026-11-17T09:55:00Z")): return (200, Self.rows(sessionEpisodes: 5))
    case ("delta-forced", .some("2026-11-17T10:55:00Z")):
      return (200, Self.rows(sessionEpisodes: 5))
    case ("delta-deleted", .some("2026-11-17T10:55:00Z")):
      return (200, Self.rows(sessionEpisodes: nil))
    default: return (400, "{}")
    }
  }

  /// A canonical Game of Thrones row, and its active session unless it's gone.
  private static func rows(sessionEpisodes count: Int?) -> String {
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
       "not_aired_episodes_count":0,
       "show":{"title":"Game of Thrones","poster":"57/5742576cd8f59fcb0","ids":{"simkl":17465}},
       "is_rewatch":true,"rewatch_id":7482,"rewatch_status":"active",
       "seasons":[{"number":1,"episodes":[\#(episodes)]}]}
      """#
    return #"{"shows":[\#(canonical),\#(rewatch)]}"#
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

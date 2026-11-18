import Foundation
import Testing

@testable import Simalytics

@Suite("Rewatch sessions from Simkl rows")
struct RewatchSessionTests {
  /// The Rewatches guide's Game of Thrones example: a canonical row plus an
  /// active session four episodes in, and a finished rewatch of another title.
  static let gotRows = """
    {"shows":[
      {"status":"completed","last_watched":null,"next_to_watch":null,"watched_episodes_count":73,
       "total_episodes_count":73,"not_aired_episodes_count":0,
       "show":{"title":"Game of Thrones","poster":"57/5742576cd8f59fcb0","ids":{"simkl":17465}},
       "is_rewatch":false},
      {"status":"completed","last_watched_at":"2026-05-16T20:00:00Z","last_watched":"S01E04",
       "next_to_watch":null,"watched_episodes_count":4,"total_episodes_count":73,
       "not_aired_episodes_count":0,
       "show":{"title":"Game of Thrones","poster":"57/5742576cd8f59fcb0","ids":{"simkl":17465}},
       "is_rewatch":true,"rewatch_id":7482,"rewatch_status":"active",
       "seasons":[{"number":1,"episodes":[
         {"number":1,"watched_at":"2026-05-16T14:02:10Z"},{"number":2},{"number":3},{"number":4}]}]},
      {"status":"completed","show":{"title":"The Wire","ids":{"simkl":100}},
       "is_rewatch":true,"rewatch_id":500,"rewatch_status":"completed","seasons":[]}
    ]}
    """

  static func rows(_ json: String, key: String = "shows") throws -> [RewatchRowModel] {
    try decodeSimklLibraryResponse(RewatchRowModel.self, from: Data(json.utf8), key: key)
  }

  static func episodes(_ season: Int, _ numbers: ClosedRange<Int>) -> [RewatchEpisode] {
    numbers.map { RewatchEpisode(season: season, episode: $0) }
  }

  @Test("Active sessions come from rewatch rows; canonical rows are skipped")
  func parsesActiveSessions() throws {
    let response = try RewatchSession.response(from: Self.rows(Self.gotRows), kind: .tv)
    #expect(response.sessionCounts == [17465: 1, 100: 1])
    let session = try #require(response.sessions.first)
    #expect(response.sessions.count == 1)
    #expect(session.id == 7482)
    #expect(session.simkl == 17465)
    #expect(session.title == "Game of Thrones")
    #expect(session.episodes == Self.episodes(1, 1...4))
    #expect(session.watchedCount == 4)
    #expect(session.totalEpisodes == 73)
    #expect(session.lastWatchedAt == "2026-05-16T20:00:00Z")
    #expect(session.nextResolvedAt == nil)
  }

  @Test("A free account's response, without rewatch rows, has no sessions")
  func freePlanHasNoSessions() throws {
    let json = """
      {"shows":[{"status":"completed","show":{"title":"Lost","ids":{"simkl":7}}}]}
      """
    let response = try RewatchSession.response(from: Self.rows(json), kind: .tv)
    #expect(response == RewatchResponse(sessions: [], sessionCounts: [:]))
  }

  @Test("A title returned without sessions has none left, unless SIMKL skipped the flag")
  func deletedSessionsDropOut() throws {
    let json = """
      {"shows":[
        {"show":{"ids":{"simkl":10}},"is_rewatch":false},
        {"show":{"ids":{"simkl":20}}}
      ]}
      """
    let response = try RewatchSession.response(from: Self.rows(json), kind: .tv)
    #expect(response.sessionCounts == [10: 0])
    let cached = [
      RewatchSession(id: 1, simkl: 10, kind: .tv),  // deleted on simkl.com
      RewatchSession(id: 2, simkl: 20, kind: .tv),  // unknown: kept
    ]
    #expect(RewatchSession.merged(cached: cached, with: response, isFullPull: false).map(\.id) == [2])
  }

  @Test("A rewatch row without a session id fails the pull")
  func malformedRewatchRow() throws {
    let json = """
      {"shows":[{"show":{"ids":{"simkl":7}},"is_rewatch":true,"rewatch_status":"active"}]}
      """
    #expect(throws: SimklMutationError.invalidResponse) {
      try RewatchSession.response(from: Self.rows(json), kind: .tv)
    }
  }

  @Test("If two sessions report active, the newest wins")
  func newestActiveWins() throws {
    let json = """
      {"anime":[
        {"show":{"ids":{"simkl":9}},"anime_type":"tv","is_rewatch":true,"rewatch_id":12,"rewatch_status":"active",
         "seasons":[{"number":1,"episodes":[{"number":3}]}]},
        {"show":{"ids":{"simkl":9}},"anime_type":"tv","is_rewatch":true,"rewatch_id":11,"rewatch_status":"active"}
      ]}
      """
    let response = try RewatchSession.response(from: Self.rows(json, key: "anime"), kind: .anime)
    #expect(response.sessions.map(\.id) == [12])
    #expect(response.sessions.first?.animeType == "tv")
    #expect(response.sessions.first?.episodes == [RewatchEpisode(season: 1, episode: 3)])
  }

  @Test("A full pull replaces cached sessions")
  func fullPullReplaces() {
    let cached = [RewatchSession(id: 1, simkl: 10, kind: .tv)]
    let response = RewatchResponse(
      sessions: [RewatchSession(id: 2, simkl: 20, kind: .tv)], sessionCounts: [20: 1])
    #expect(
      RewatchSession.merged(cached: cached, with: response, isFullPull: true).map(\.id) == [2])
  }

  @Test("A delta replaces the sessions of each title it returns, and only those")
  func deltaMerge() {
    let cached = [
      RewatchSession(id: 1, simkl: 10, kind: .tv),  // not in the delta: kept
      RewatchSession(id: 2, simkl: 20, kind: .tv),  // session completed: dropped
    ]
    let response = RewatchResponse(
      sessions: [RewatchSession(id: 3, simkl: 30, kind: .tv)], sessionCounts: [20: 1, 30: 1])
    #expect(
      RewatchSession.merged(cached: cached, with: response, isFullPull: false).map(\.id) == [1, 3])
  }

  @Test("Session counts follow the same full and delta rules")
  func countsMerge() {
    let response = RewatchResponse(sessions: [], sessionCounts: [10: 3, 20: 0])
    #expect(
      RewatchSession.mergedCounts(
        cached: [10: 1, 20: 2, 30: 4], with: response, isFullPull: false) == [10: 3, 30: 4])
    #expect(
      RewatchSession.mergedCounts(cached: [10: 1, 30: 4], with: response, isFullPull: true)
        == [10: 3])
  }

  @Test("A rewatch started while a pull was in flight still counts toward the cap")
  func reconcilesInFlightStart() {
    let base = [RewatchSession(id: 1, simkl: 10, kind: .tv)]
    let current = [RewatchSession(id: 1, simkl: 10, kind: .tv), RewatchSession(id: 9, simkl: 40, kind: .tv)]
    let counts = RewatchSession.reconciledCounts(
      pulled: [10: 2, 40: 49], base: base, current: current, currentCounts: [10: 2, 40: 50])
    #expect(counts == [10: 2, 40: 50])
    // Without a local start, the pull's count stands, even when it went down.
    #expect(
      RewatchSession.reconciledCounts(
        pulled: [10: 1], base: base, current: base, currentCounts: [10: 2]) == [10: 1])
  }

  @Test("A resolved next episode survives a pull until the session's episodes change")
  func keepsResolutionWhileUnchanged() {
    let resolvedAt = Date(timeIntervalSince1970: 100)
    let next = RewatchNextEpisode(season: 1, episode: 5, title: "The Wolf and the Lion", date: nil)
    let cached = RewatchSession(
      id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...4), next: next,
      nextResolvedAt: resolvedAt)
    let same = RewatchSession(id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...4))
    let advanced = RewatchSession(id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...5))

    let unchanged = RewatchSession.merged(
      cached: [cached], with: RewatchResponse(sessions: [same], sessionCounts: [10: 1]),
      isFullPull: false)
    #expect(unchanged.first?.next == next)
    #expect(unchanged.first?.nextResolvedAt == resolvedAt)

    let moved = RewatchSession.merged(
      cached: [cached], with: RewatchResponse(sessions: [advanced], sessionCounts: [10: 1]),
      isFullPull: false)
    #expect(moved.first?.nextResolvedAt == nil)
  }

  @Test("Writes made while a pull was in flight keep their local copy")
  func reconcilesInFlightWrites() {
    let base = [
      RewatchSession(id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...1)),
      RewatchSession(id: 2, simkl: 20, kind: .tv),
      RewatchSession(id: 3, simkl: 30, kind: .tv),
      RewatchSession(id: 8, simkl: 40, kind: .tv),
    ]
    var logged = base[0]
    logged.record(RewatchEpisode(season: 1, episode: 2), watched: true)
    let started = RewatchSession(id: 9, simkl: 40, kind: .tv)
    // Session 2 was stopped locally; 3 and 8 were untouched; 9 was started.
    let current = [logged, base[2], started]
    let pulled = [
      RewatchSession(id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...1)),
      RewatchSession(id: 2, simkl: 20, kind: .tv),
      RewatchSession(id: 3, simkl: 30, kind: .tv, episodes: Self.episodes(1, 1...3)),
      RewatchSession(id: 8, simkl: 40, kind: .tv),
    ]

    let result = RewatchSession.reconciled(pulled: pulled, base: base, current: current)
    #expect(result.map(\.id) == [1, 3, 9])
    #expect(result.first?.episodes == Self.episodes(1, 1...2))
    #expect(result[1].episodes == Self.episodes(1, 1...3))
  }

  static let catalog = [
    RewatchCatalogEpisode(season: 1, episode: 1, title: "One", date: nil, aired: true),
    RewatchCatalogEpisode(season: 1, episode: 2, title: "Two", date: nil, aired: true),
    RewatchCatalogEpisode(season: 1, episode: 3, title: "Three", date: nil, aired: true),
    RewatchCatalogEpisode(season: 2, episode: 1, title: "Four", date: nil, aired: true),
    RewatchCatalogEpisode(season: 2, episode: 2, title: "Five", date: nil, aired: true),
    RewatchCatalogEpisode(season: 0, episode: 1, title: "Special", date: nil, aired: true),
  ]

  @Test(
    "The next episode follows the furthest one logged, across seasons and past gaps",
    arguments: [
      ([RewatchEpisode](), RewatchEpisode(season: 1, episode: 1)),
      ([RewatchEpisode(season: 1, episode: 3)], RewatchEpisode(season: 2, episode: 1)),
      (
        [RewatchEpisode(season: 1, episode: 1), RewatchEpisode(season: 2, episode: 1)],
        RewatchEpisode(season: 2, episode: 2)
      ),
      ([RewatchEpisode(season: 0, episode: 1)], RewatchEpisode(season: 1, episode: 1)),
    ])
  func nextEpisode(watched: [RewatchEpisode], expected: RewatchEpisode) {
    let next = RewatchSession.nextEpisode(after: watched, in: Self.catalog)
    #expect(next.map { RewatchEpisode(season: $0.season, episode: $0.episode) } == expected)
  }

  @Test("A session that reached the last episode has nothing next")
  func caughtUp() {
    #expect(
      RewatchSession.nextEpisode(after: [RewatchEpisode(season: 2, episode: 2)], in: Self.catalog)
        == nil)
  }

  @Test("An unaired next episode needs a date to be listed")
  func unairedNextEpisode() {
    let watched = [RewatchEpisode(season: 1, episode: 1)]
    let undated = [
      RewatchCatalogEpisode(season: 1, episode: 1, title: "One", date: nil, aired: true),
      RewatchCatalogEpisode(season: 1, episode: 2, title: "Two", date: nil, aired: false),
    ]
    #expect(RewatchSession.nextEpisode(after: watched, in: undated) == nil)

    let dated = [
      undated[0],
      RewatchCatalogEpisode(
        season: 1, episode: 2, title: "Two", date: "2099-01-01T00:00:00-05:00", aired: false),
    ]
    #expect(RewatchSession.nextEpisode(after: watched, in: dated)?.date == "2099-01-01T00:00:00-05:00")
  }

  @Test("Up Next markers match SIMKL's for TV and anime")
  func markers() {
    let next = RewatchNextEpisode(season: 1, episode: 5, title: nil, date: nil)
    #expect(next.marker(for: .tv) == "S01E05")
    #expect(next.marker(for: .anime) == "E5")
  }

  @MainActor
  @Test("A rewatch row in Up Next lists the session's next episode")
  func upNextItem() {
    let session = RewatchSession(
      id: 7482, simkl: 17465, kind: .tv, episodes: Self.episodes(1, 1...4),
      next: RewatchNextEpisode(season: 1, episode: 5, title: "The Wolf and the Lion", date: nil),
      nextResolvedAt: Date())
    let item = RewatchUpNextItem(session: session)
    #expect(item.upNextID == "rewatch-7482")
    #expect(item.isAvailableUpNext())
    #expect(item.nextEpisodeBadge == "S1 · E5")

    var caughtUp = session
    caughtUp.next = nil
    #expect(!RewatchUpNextItem(session: caughtUp).isAvailableUpNext())
  }

  @MainActor
  @Test("The episode list checks off exactly the session's episodes")
  func episodeListFollowsSession() {
    let items = (1...3).map {
      EpisodeListItem(
        id: $0, group: 1, watchSeason: 1, number: $0, title: "E\($0)", overview: nil, image: nil,
        date: nil)
    }
    let session = RewatchSession(id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...2))
    let model = EpisodeBrowserModel(
      episodes: items, seasons: session.watchlistSeasons, isAnime: false)
    #expect(model.watchedIDs == [1, 2])
    #expect(model.nextUnwatched?.id == 3)
  }
}

@MainActor
@Suite("Rewatch store")
struct RewatchStoreTests {
  @Test("Sessions and cursors persist; signing out forgets them")
  func persistence() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "rewatch-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "state.json")
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))

    let store = RewatchStore(fileURL: file, defaults: defaults)
    store.insert(RewatchSession(id: 1, simkl: 10, kind: .anime, animeType: "tv"))
    store.record(RewatchEpisode(season: 1, episode: 4), watched: true, sessionID: 1)

    let reopened = RewatchStore(fileURL: file, defaults: defaults)
    #expect(reopened.state == store.state)
    #expect(reopened.activeSession(simkl: 10, kind: .anime)?.episodes.count == 1)
    #expect(reopened.activeSession(simkl: 10, kind: .tv) == nil)
    #expect(reopened.sessionCount(simkl: 10, kind: .anime) == 1)

    reopened.reset()
    #expect(reopened.state == RewatchStore.State())
    #expect(!FileManager.default.fileExists(atPath: file.path))
  }

  @Test("Sessions are counted only after the first pull, and a start counts toward the cap")
  func sessionLimit() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "rewatch-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "state.json")
    var state = RewatchStore.State()
    state.tv.baselineAt = Date()
    state.tvSessionCounts = [10: 49]
    try JSONEncoder().encode(state).write(to: file)
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))

    let store = RewatchStore(fileURL: file, defaults: defaults)
    #expect(store.hasCountedSessions(.tv))
    #expect(!store.hasCountedSessions(.anime))
    #expect(store.sessionCount(simkl: 10, kind: .tv) == 49)
    store.insert(RewatchSession(id: 5, simkl: 10, kind: .tv))
    #expect(store.sessionCount(simkl: 10, kind: .tv) == RewatchStore.maxSessionsPerTitle)

    store.clearSessions()
    #expect(!store.hasCountedSessions(.tv))
    #expect(store.sessionCount(simkl: 10, kind: .tv) == 0)
  }

  @Test("Tracking needs both the switch and a PRO or VIP plan")
  func gating() throws {
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))
    let store = RewatchStore(fileURL: nil, defaults: defaults)
    #expect(!store.isTrackingEnabled)
    #expect(!store.isPlanEligible)
    defaults.set(true, forKey: RewatchStore.preferenceKey)
    #expect(store.isTrackingEnabled)
    store.disableTracking()
    #expect(!store.isTrackingEnabled)
  }
}

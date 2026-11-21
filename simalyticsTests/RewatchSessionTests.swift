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
    #expect(response.endedIDs == [500])
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
    #expect(response == RewatchResponse(sessions: []))
  }

  /// SIMKL's live deltas list only the rows that changed: a rated title can
  /// come back without its sessions, and a deleted session never comes back.
  @Test("A delta's canonical row leaves the title's sessions alone")
  func canonicalRowsKeepSessions() throws {
    let json = """
      {"shows":[{"show":{"ids":{"simkl":10}},"is_rewatch":false,"user_rating":7}]}
      """
    let response = try RewatchSession.response(from: Self.rows(json), kind: .tv)
    let cached = [RewatchSession(id: 1, simkl: 10, kind: .tv)]
    #expect(RewatchSession.merged(cached: cached, with: response, isFullPull: false) == cached)
  }

  @Test("The membership list drops deleted sessions and counts every saved one")
  func membershipPrunesAndCounts() throws {
    let json = """
      {"shows":[
        {"show":{"ids":{"simkl":10}},"is_rewatch":false},
        {"show":{"ids":{"simkl":10}},"is_rewatch":true,"rewatch_id":3,"rewatch_status":"closed"},
        {"show":{"ids":{"simkl":10}},"is_rewatch":true,"rewatch_id":4,"rewatch_status":"active"},
        {"show":{"ids":{"simkl":20}},"is_rewatch":false},
        {"show":{"ids":{"simkl":30}},"is_rewatch":true,"rewatch_id":9,"rewatch_status":"active"}
      ]}
      """
    let membership = try #require(try RewatchSession.membership(from: Self.rows(json)))
    #expect(membership.activeIDs == [4, 9])
    #expect(membership.counts == [10: 2, 30: 1])

    let cached = [
      RewatchSession(id: 2, simkl: 20, kind: .tv),  // deleted on simkl.com
      RewatchSession(id: 4, simkl: 10, kind: .tv),  // still active
    ]
    let pruned = RewatchSession.pruned(cached, by: membership)
    #expect(pruned.sessions.map(\.id) == [4])
    #expect(pruned.missingIDs == [9])
  }

  @Test("Without SIMKL's rewatch flag, the membership list is unknown rather than empty")
  func membershipNeedsTheFlag() throws {
    let json = """
      {"shows":[{"show":{"ids":{"simkl":10}}}]}
      """
    #expect(try RewatchSession.membership(from: Self.rows(json)) == nil)
    #expect(
      try RewatchSession.membership(from: []) == RewatchMembership(titles: [:], activeIDs: []))
    let malformed = """
      {"shows":[{"show":{"ids":{"simkl":10}},"is_rewatch":true,"rewatch_status":"active"}]}
      """
    #expect(throws: SimklMutationError.invalidResponse) {
      try RewatchSession.membership(from: Self.rows(malformed))
    }
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
    let response = RewatchResponse(sessions: [RewatchSession(id: 2, simkl: 20, kind: .tv)])
    #expect(
      RewatchSession.merged(cached: cached, with: response, isFullPull: true).map(\.id) == [2])
  }

  @Test("A delta updates session by session")
  func deltaMerge() {
    let cached = [
      RewatchSession(id: 1, simkl: 10, kind: .tv),  // not in the delta: kept
      RewatchSession(id: 2, simkl: 20, kind: .tv),  // closed or completed: dropped
      RewatchSession(id: 4, simkl: 40, kind: .tv),  // replaced by a newer active session
    ]
    let response = RewatchResponse(
      sessions: [
        RewatchSession(id: 3, simkl: 30, kind: .tv), RewatchSession(id: 5, simkl: 40, kind: .tv),
      ],
      endedIDs: [2])
    #expect(
      RewatchSession.merged(cached: cached, with: response, isFullPull: false).map(\.id)
        == [1, 3, 5])
  }

  @Test("A logged next episode marks the row stale until it's resolved again")
  func staleNextEpisode() {
    var session = RewatchSession(
      id: 1, simkl: 10, kind: .tv, episodes: Self.episodes(1, 1...4),
      next: RewatchNextEpisode(season: 1, episode: 5, title: nil, date: nil),
      nextResolvedAt: Date())
    #expect(!session.isNextLogged)
    session.record(RewatchEpisode(season: 1, episode: 5), watched: true)
    #expect(session.isNextLogged)
    #expect(session.nextResolvedAt == nil)
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
      cached: [cached], with: RewatchResponse(sessions: [same]), isFullPull: false)
    #expect(unchanged.first?.next == next)
    #expect(unchanged.first?.nextResolvedAt == resolvedAt)

    let moved = RewatchSession.merged(
      cached: [cached], with: RewatchResponse(sessions: [advanced]), isFullPull: false)
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

  static func movieRows(_ json: String) throws -> [MovieRewatchRowModel] {
    try decodeSimklLibraryResponse(MovieRewatchRowModel.self, from: Data(json.utf8), key: "movies")
  }

  /// As live: each movie rewatch is its own row, already complete.
  @Test("Each movie rewatch row is one rewatch; the first watch isn't one")
  func movieRewatchIDs() throws {
    let json = """
      {"movies":[
        {"movie":{"ids":{"simkl":53186,"slug":"gladiator"}},"is_rewatch":false},
        {"movie":{"ids":{"simkl":53186,"slug":"gladiator"}},"is_rewatch":true,"rewatch_id":831262,"rewatch_status":"completed"},
        {"movie":{"ids":{"simkl":53186,"slug":"gladiator"}},"is_rewatch":true,"rewatch_id":831260,"rewatch_status":"completed"},
        {"movie":{"ids":{"simkl":54424}},"is_rewatch":false}
      ]}
      """
    #expect(try MovieRewatches.ids(from: Self.movieRows(json)) == [53186: [831260, 831262]])
    #expect(try MovieRewatches.ids(from: []) == [:])
  }

  @Test("Without SIMKL's rewatch flag, movie rewatches are unknown rather than none")
  func movieRewatchIDsNeedTheFlag() throws {
    let unflagged = """
      {"movies":[{"movie":{"ids":{"simkl":53186}}}]}
      """
    #expect(try MovieRewatches.ids(from: Self.movieRows(unflagged)) == nil)
    let malformed = """
      {"movies":[{"movie":{"ids":{"simkl":53186}},"is_rewatch":true,"rewatch_status":"completed"}]}
      """
    #expect(throws: SimklMutationError.invalidResponse) {
      try MovieRewatches.ids(from: Self.movieRows(malformed))
    }
  }

  @Test("Movie rewatches logged or removed while a pull was in flight keep their local copy")
  func reconcilesInFlightMovieRewatches() {
    let base = [1: [10], 2: [20], 3: [30]]
    // A rewatch of 1 was logged and 2's only one was removed; 3 was untouched.
    let current = [1: [10, 11], 3: [30]]
    // Meanwhile simkl.com added one to 3 and to 4.
    let pulled = [1: [10], 2: [20], 3: [30, 31], 4: [40]]
    #expect(
      MovieRewatches.reconciled(pulled: pulled, base: base, current: current)
        == [1: [10, 11], 3: [30, 31], 4: [40]])
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
  @Test("Up Next lists the most recently watched first, rewatches included")
  func upNextOrder() {
    func item(_ id: Int, _ title: String, _ lastWatched: String?) -> RewatchUpNextItem {
      RewatchUpNextItem(
        session: RewatchSession(
          id: id, simkl: id, kind: .tv, title: title, lastWatchedAt: lastWatched))
    }
    let items: [any UpNextMedia] = [
      item(1, "Older", "2026-11-01T10:00:00Z"),
      item(2, "Undated", nil),
      item(3, "Newest", "2026-11-20T22:00:00Z"),
      item(4, "Also Older", "2026-11-01T10:00:00Z"),
    ]
    #expect(
      items.sorted(by: isListedBeforeInUpNext).map(\.title)
        == ["Newest", "Also Older", "Older", "Undated"])
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

  @Test("Signing out turns tracking off, so the next account opts in for itself")
  func signOutDisablesTracking() throws {
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))
    defaults.set(true, forKey: RewatchStore.preferenceKey)
    let store = RewatchStore(fileURL: nil, defaults: defaults)
    store.reset()
    #expect(!store.isTrackingEnabled)
  }

  @Test("Logging resolves the next episode at once, and a finished rewatch leaves")
  func nextEpisodeAndCompletion() throws {
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))
    let store = RewatchStore(fileURL: nil, defaults: defaults)
    store.insert(RewatchSession(id: 1, simkl: 10, kind: .tv))
    store.record(RewatchEpisode(season: 1, episode: 1), watched: true, sessionID: 1)
    let resolvedAt = Date(timeIntervalSince1970: 5)
    store.resolveNext(sessionID: 1, catalog: RewatchSessionTests.catalog, at: resolvedAt)
    #expect(store.activeSession(simkl: 10, kind: .tv)?.next?.episode == 2)
    #expect(store.activeSession(simkl: 10, kind: .tv)?.nextResolvedAt == resolvedAt)

    store.complete(sessionID: 1)
    #expect(store.activeSession(simkl: 10, kind: .tv) == nil)
    #expect(store.isRecentlyCompleted(simkl: 10))
    store.insert(RewatchSession(id: 2, simkl: 10, kind: .tv))
    #expect(!store.isRecentlyCompleted(simkl: 10))
  }

  @Test("A reused session asks the next sync for a full read of its type")
  func fullPullRequest() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "rewatch-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "state.json")
    var state = RewatchStore.State()
    state.tv = RewatchStore.Cursor(activity: "2026-11-20T10:00:00Z", baselineAt: Date())
    state.anime = state.tv
    try JSONEncoder().encode(state).write(to: file)
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))

    let store = RewatchStore(fileURL: file, defaults: defaults)
    store.requestFullPull(.tv)
    #expect(!store.hasCountedSessions(.tv))
    #expect(store.hasCountedSessions(.anime))
    #expect(RewatchStore(fileURL: file, defaults: defaults).state.tv.baselineAt == nil)
  }

  @Test("An older cache keeps its sessions and counts movies on the next pull")
  func cacheWithoutMovies() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "rewatch-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "state.json")
    var state = RewatchStore.State()
    state.accountType = "vip"
    state.tv = RewatchStore.Cursor(activity: "2026-11-20T10:00:00Z", baselineAt: Date())
    state.sessions = [RewatchSession(id: 1, simkl: 10, kind: .tv)]
    var saved = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    saved["movies"] = nil
    saved["movieRewatchIDs"] = nil
    try JSONSerialization.data(withJSONObject: saved).write(to: file)
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))

    let store = RewatchStore(fileURL: file, defaults: defaults)
    #expect(store.isPlanEligible)
    #expect(store.hasCountedSessions(.tv))
    #expect(store.activeSession(simkl: 10, kind: .tv)?.id == 1)
    #expect(!store.hasCountedMovieRewatches)
    #expect(store.movieRewatchIDs(simkl: 53186).isEmpty)
  }

  @Test("Movie rewatches persist oldest first, and removing the last one clears the movie")
  func movieRewatches() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "rewatch-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appending(path: "state.json")
    var state = RewatchStore.State()
    state.movies = RewatchStore.Cursor(activity: "2026-11-20T10:00:00Z", baselineAt: Date())
    try JSONEncoder().encode(state).write(to: file)
    let defaults = try #require(UserDefaults(suiteName: "rewatch-\(UUID())"))

    let store = RewatchStore(fileURL: file, defaults: defaults)
    #expect(store.hasCountedMovieRewatches)
    store.recordMovieRewatch(simkl: 53186, id: 831262)
    store.recordMovieRewatch(simkl: 53186, id: 831260)
    #expect(store.movieRewatchIDs(simkl: 53186) == [831260, 831262])

    let reopened = RewatchStore(fileURL: file, defaults: defaults)
    #expect(reopened.movieRewatchIDs(simkl: 53186) == [831260, 831262])
    reopened.removeMovieRewatch(simkl: 53186, id: 831262)
    #expect(reopened.movieRewatchIDs(simkl: 53186) == [831260])
    reopened.removeMovieRewatch(simkl: 53186, id: 831260)
    #expect(reopened.state.movieRewatchIDs.isEmpty)

    reopened.recordMovieRewatch(simkl: 53186, id: 831264)
    reopened.clearSessions()
    #expect(!reopened.hasCountedMovieRewatches)
    #expect(reopened.movieRewatchIDs(simkl: 53186).isEmpty)
  }
}

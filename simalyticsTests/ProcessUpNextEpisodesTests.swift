import Foundation
import SwiftData
import Testing

@testable import Simalytics

@MainActor
@Suite("Up Next — authoritative summaries", .serialized)
struct ProcessUpNextCacheTests {
  private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }

  private func makeSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [UpNextFixtureProtocol.self]
    return URLSession(configuration: configuration)
  }

  @Test("Invalidation forces a fresh summary instead of a cached phantom episode")
  func cacheInvalidation() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.changes_api = "2026-05-22T10:00:00Z"
    context.insert(sync)
    try context.save()
    invalidateUpNextCache(modelContainer: container)
    let refreshed = try ModelContext(container).fetch(FetchDescriptor<V1.SDLastSync>()).first
    #expect(refreshed?.changes_api == nil)
  }

  @Test("An update refreshes estimates from older versions once, not on every launch")
  func refreshOnceAfterUpdate() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.changes_api = "2026-10-14T10:00:00Z"
    context.insert(sync)
    try context.save()
    let name = "ProcessUpNextCacheTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }

    refreshUpNextOnceAfterUpdate(modelContainer: container, defaults: defaults)
    let first = try ModelContext(container).fetch(FetchDescriptor<V1.SDLastSync>()).first
    #expect(first?.changes_api == nil)

    first?.changes_api = "2026-10-14T11:00:00Z"
    try first?.modelContext?.save()
    refreshUpNextOnceAfterUpdate(modelContainer: container, defaults: defaults)
    let second = try ModelContext(container).fetch(FetchDescriptor<V1.SDLastSync>()).first
    #expect(second?.changes_api == "2026-10-14T11:00:00Z")
  }

  @Test("Catalog refresh respects the six-hour boundary and invalid timestamps")
  func cacheBoundary() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-10-11T12:00:00Z"))
    #expect(shouldRefreshUpNext(lastRefresh: nil, now: now))
    #expect(shouldRefreshUpNext(lastRefresh: "invalid", now: now))
    #expect(shouldRefreshUpNext(lastRefresh: "2026-10-11T06:00:00Z", now: now))
    #expect(!shouldRefreshUpNext(lastRefresh: "2026-10-11T06:00:01Z", now: now))
  }

  @Test("Forced Watching refresh omits date_from and clears stale info", arguments: [false, true])
  func clearsCaughtUpEpisode(isAnime: Bool) async throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let activity = "2026-10-11T12:00:00Z"
    let sync = V1.SDLastSync(id: 1)
    sync.tv_watching = activity
    sync.anime_watching = activity
    context.insert(sync)
    if isAnime {
      context.insert(
        V1.SDAnimes(
          simkl: 38636, release_date: "1999-10-20", status: "watching", next_to_watch: "1181",
          anime_type: "tv",
          title: "One Piece", id_offjp: "preserve-catalog-value",
          next_to_watch_info_title: "Stale episode",
          next_to_watch_info_episode: 1181
        ))
    } else {
      context.insert(
        V1.SDShows(
          simkl: 42, release_date: "2020-01-01", status: "watching", next_to_watch: "S1E2",
          title: "Test Show", id_offen: "preserve-catalog-value",
          next_to_watch_info_title: "Stale episode", next_to_watch_info_season: 1,
          next_to_watch_info_episode: 2
        ))
    }
    try context.save()
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let success: Bool
    if isAnime {
      success = await fetchAndStoreAnimeWatching(
        "caught-up", activity, ModelContext(container), forceRefresh: true, session: session)
    } else {
      success = await fetchAndStoreTVWatching(
        "caught-up", activity, ModelContext(container), forceRefresh: true, session: session)
    }
    #expect(success)
    // The fixture returns a non-empty next marker if date_from was sent.
    // Nil therefore proves a full pull was used despite an unchanged activity.
    let refreshedContext = ModelContext(container)
    if isAnime {
      let rows = try refreshedContext.fetch(FetchDescriptor<V1.SDAnimes>())
      #expect(rows.count == 1)
      let row = try #require(rows.first)
      #expect(row.next_to_watch == nil)
      #expect(row.next_to_watch_info_title == nil)
      #expect(row.next_to_watch_info_episode == nil)
      #expect(row.next_to_watch_info_date == nil)
      #expect(!row.isAvailableUpNext())
      #expect(row.release_date == "1999-10-20" && row.id_offjp == "preserve-catalog-value")
    } else {
      let rows = try refreshedContext.fetch(FetchDescriptor<V1.SDShows>())
      #expect(rows.count == 1)
      let row = try #require(rows.first)
      #expect(row.next_to_watch == nil)
      #expect(row.next_to_watch_info_title == nil)
      #expect(row.next_to_watch_info_season == nil)
      #expect(row.next_to_watch_info_episode == nil)
      #expect(row.next_to_watch_info_date == nil)
      #expect(!row.isAvailableUpNext())
      #expect(row.release_date == "2020-01-01" && row.id_offen == "preserve-catalog-value")
    }
  }

  @Test("Watching deltas still use date_from", arguments: [false, true])
  func preservesIncrementalSync(isAnime: Bool) async throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.tv_watching = "2026-10-11T10:00:00Z"
    sync.anime_watching = sync.tv_watching
    context.insert(sync)
    try context.save()
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    let activity = "2026-10-11T12:00:00Z"
    if isAnime {
      #expect(await fetchAndStoreAnimeWatching("caught-up", activity, context, session: session))
      #expect(try context.fetch(FetchDescriptor<V1.SDAnimes>()).first?.next_to_watch == "1181")
    } else {
      #expect(await fetchAndStoreTVWatching("caught-up", activity, context, session: session))
      #expect(try context.fetch(FetchDescriptor<V1.SDShows>()).first?.next_to_watch == "S1E2")
    }
  }

  @Test(
    "Decode and HTTP failures do not advance Watching timestamps",
    arguments: ["invalid-json", "error-envelope", "missing-id", "null-array", "unauthorized"])
  func failedRefreshStaysRetryable(scenario: String) async throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    let previous = "2026-10-11T10:00:00Z"
    sync.tv_watching = previous
    sync.anime_watching = previous
    context.insert(sync)
    try context.save()
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    #expect(
      await fetchAndStoreTVWatching(
        scenario, "2026-10-11T12:00:00Z", context, forceRefresh: true, session: session) == false)
    #expect(
      await fetchAndStoreAnimeWatching(
        scenario, "2026-10-11T12:00:00Z", context, forceRefresh: true, session: session) == false)
    let refreshed = try #require(
      ModelContext(container).fetch(FetchDescriptor<V1.SDLastSync>()).first)
    #expect(refreshed.tv_watching == previous)
    #expect(refreshed.anime_watching == previous)
    #expect(refreshed.changes_api == nil)
  }

  @Test(
    "Empty full Watching responses clear stale queue metadata but retain library data",
    arguments: ["empty-object", "empty-array", "empty-null"])
  func handlesEmptyWatchingResponse(scenario: String) async throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    context.insert(
      V1.SDShows(
        simkl: 42, user_rating: 8, status: "watching", next_to_watch: "S1E2", title: "TV",
        memo_text: "Keep this", next_to_watch_info_episode: 2))
    context.insert(
      V1.SDAnimes(
        simkl: 38636, user_rating: 9, status: "watching", next_to_watch: "E1181", anime_type: "tv",
        title: "One Piece", next_to_watch_info_episode: 1181))
    context.insert(V1.SDShows(simkl: 43, status: "hold", next_to_watch: "S1E3"))
    try context.save()
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    // No timestamp is not proof of emptiness: forced refresh must still read.
    #expect(
      await fetchAndStoreTVWatching(scenario, nil, context, forceRefresh: true, session: session))
    #expect(
      await fetchAndStoreAnimeWatching(scenario, nil, context, forceRefresh: true, session: session)
    )
    let rows = try ModelContext(container).fetch(FetchDescriptor<V1.SDShows>())
    #expect(rows.count == 2)
    let show = try #require(rows.first { $0.simkl == 42 })
    #expect(show.next_to_watch == nil)
    #expect(show.next_to_watch_info_episode == nil)
    #expect(show.title == "TV" && show.user_rating == 8 && show.memo_text == "Keep this")
    #expect(rows.first { $0.simkl == 43 }?.next_to_watch == "S1E3")
    let anime = try #require(ModelContext(container).fetch(FetchDescriptor<V1.SDAnimes>()).first)
    #expect(anime.next_to_watch == nil && anime.next_to_watch_info_episode == nil)
    #expect(anime.title == "One Piece" && anime.user_rating == 9)
  }

  @Test("A delta does not clear absent queue rows, while a full refresh does")
  func absentRowsFullVersusDelta() async throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.tv_watching = "2026-10-11T10:00:00Z"
    context.insert(sync)
    context.insert(
      V1.SDShows(
        simkl: 99, status: "watching", next_to_watch: "S1E4", next_to_watch_info_episode: 4))
    try context.save()
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    #expect(
      await fetchAndStoreTVWatching("caught-up", "2026-10-11T12:00:00Z", context, session: session))
    #expect(
      try ModelContext(container).fetch(FetchDescriptor<V1.SDShows>()).first { $0.simkl == 99 }?
        .next_to_watch == "S1E4")
    #expect(
      await fetchAndStoreTVWatching(
        "caught-up", "2026-10-11T12:00:00Z", context, forceRefresh: true, session: session))
    #expect(
      try ModelContext(container).fetch(FetchDescriptor<V1.SDShows>()).first { $0.simkl == 99 }?
        .next_to_watch == nil)
  }

  @Test("A malformed full response preserves cached queue rows")
  func malformedResponseDoesNotClearRows() async throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    context.insert(V1.SDShows(simkl: 99, status: "watching", next_to_watch: "S1E4"))
    try context.save()
    let session = makeSession()
    defer { session.invalidateAndCancel() }
    #expect(
      await fetchAndStoreTVWatching(
        "missing-id", nil, context, forceRefresh: true, session: session) == false)
    #expect(
      try ModelContext(container).fetch(FetchDescriptor<V1.SDShows>()).first?.next_to_watch
        == "S1E4")
  }

  @Test("Hiatus marker and timezone-aware future dates cannot appear as watchable")
  func availability() throws {
    let now = try #require(ISO8601DateFormatter().date(from: "2026-10-11T12:00:00Z"))
    let anime = V1.SDAnimes(
      simkl: 38636, status: "watching", next_to_watch: nil, anime_type: "tv",
      next_to_watch_info_title: "Episode 1181", next_to_watch_info_episode: 1181
    )
    #expect(!anime.isAvailableUpNext(now: now))
    anime.next_to_watch = "1181"
    anime.next_to_watch_info_date = "2026-10-11T22:00:00+09:00"
    #expect(!anime.isAvailableUpNext(now: now))
    anime.next_to_watch_info_date = "2026-10-11T20:00:00.000+09:00"
    #expect(anime.isAvailableUpNext(now: now))
    anime.next_to_watch_info_date = "2026-10-11T21:00:00+09:00"
    #expect(anime.isAvailableUpNext(now: now))
    anime.next_to_watch_info_date = "TBA"
    #expect(!anime.isAvailableUpNext(now: now))
    anime.next_to_watch_info_date = nil
    anime.next_to_watch_info_title = nil
    #expect(
      anime.isAvailableUpNext(now: now),
      "A missing title/date must not discard an authoritative aired marker")
    anime.next_to_watch_info_episode = 0
    #expect(!anime.isAvailableUpNext(now: now))
    let show = V1.SDShows(
      simkl: 42, next_to_watch: "S1E1", next_to_watch_info_season: 0, next_to_watch_info_episode: 1)
    #expect(
      !show.isAvailableUpNext(now: now), "Specials must not appear in the regular Up Next queue")
    show.next_to_watch_info_season = 1
    #expect(show.isAvailableUpNext(now: now))
  }

  @Test("Up Next mark-watched refuses invalid episode coordinates")
  func validatesEpisodeBeforePosting() {
    #expect(validatedSimklEpisode(season: 1, episode: nil) == nil)
    #expect(validatedSimklEpisode(season: 1, episode: 0) == nil)
    #expect(validatedSimklEpisode(season: nil, episode: 4) == nil)
    #expect(validatedSimklEpisode(season: nil, episode: 4, fallbackSeason: 1)?.season == 1)
    #expect(validatedSimklEpisode(season: 2, episode: 4)?.episode == 4)
  }

  @Test("Simkl API URLs include required app metadata")
  func simklURLMetadata() throws {
    let url = simklAPIURL(path: "search/tv", queryItems: [URLQueryItem(name: "q", value: "world")])
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
    let names = Set((components.queryItems ?? []).map(\.name))
    #expect(components.host == "api.simkl.com")
    #expect(names.isSuperset(of: ["client_id", "app-name", "app-version"]))
  }
}

/// All test requests stay offline; query-dependent fixtures prove full vs delta pulls.
private final class UpNextFixtureProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let scenario = request.value(forHTTPHeaderField: "Authorization") ?? ""
    let isAnime = request.url!.path.contains("/anime/")
    let isDelta =
      URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.contains {
        $0.name == "date_from"
      } == true
    let status = scenario.contains("unauthorized") ? 401 : 200
    let body: String
    if scenario.contains("invalid-json") {
      body = "invalid"
    } else if scenario.contains("empty-null") {
      body = "null"
    } else if scenario.contains("empty-object") {
      body = "{}"
    } else if scenario.contains("empty-array") {
      body = isAnime ? "{\"anime\":[]}" : "{\"shows\":[]}"
    } else if scenario.contains("error-envelope") {
      body = "{\"error\":\"invalid_response\"}"
    } else if scenario.contains("null-array") {
      body = isAnime ? "{\"anime\":null}" : "{\"shows\":null}"
    } else if scenario.contains("missing-id") {
      body =
        isAnime
        ? "{\"anime\":[{\"status\":\"watching\"}]}" : "{\"shows\":[{\"status\":\"watching\"}]}"
    } else if isAnime {
      body = """
        {"anime":[{"status":"watching","anime_type":"tv","next_to_watch":\(isDelta ? "\"1181\"" : "null"),"show":{"title":"One Piece","ids":{"simkl":38636}},"next_to_watch_info":{"title":"Stale episode","episode":1181,"date":"2027-04-01T09:00:00+09:00"}}]}
        """
    } else {
      body = """
        {"shows":[{"status":"watching","next_to_watch":\(isDelta ? "\"S1E2\"" : "null"),"show":{"title":"Test Show","ids":{"simkl":42}},"next_to_watch_info":{"title":"Stale episode","season":1,"episode":2,"date":"2027-04-01T09:00:00Z"}}]}
        """
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

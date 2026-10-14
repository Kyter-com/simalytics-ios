import Foundation
import SwiftData
import Testing

@testable import Simalytics

@Suite(.serialized)
struct ReadRecoveryTests {
  private func session() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RecoveryFixtureProtocol.self]
    return URLSession(configuration: config)
  }

  @Test("Resource-unavailable GET retries recover without changing mutation retry safety")
  func safeReadRetry() async throws {
    let session = session()
    defer { session.invalidateAndCancel() }
    for method in ["GET", "POST"] {
      let url = URL(string: "https://example.invalid/retry/\(UUID().uuidString)")!
      var request = URLRequest(url: url)
      request.httpMethod = method
      do {
        let (_, response) = try await performSimklRequest(request, session: session)
        #expect(method == "GET")
        #expect(response.statusCode == 200)
      } catch {
        #expect(method == "POST")
        #expect((error as? URLError)?.code == .resourceUnavailable)
      }
      #expect(
        RecoveryFixtureProtocol.attempts.count(url.absoluteString) == (method == "GET" ? 2 : 1))
    }
  }

  @Test(
    "Episode JSON errors propagate instead of looking like an empty catalog",
    arguments: [false, true])
  func episodeFailure(isAnime: Bool) async {
    let session = session()
    defer { session.invalidateAndCancel() }
    await #expect(throws: DecodingError.self) {
      if isAnime {
        _ = try await AnimeDetailView.getAnimeEpisodes(42, session: session)
      } else {
        _ = try await ShowDetailView.getShowEpisodes(42, session: session)
      }
    }
  }

  @Test(
    "Rejected library reads preserve rows and cursors across all removal categories",
    arguments: ["unauthorized", "malformed", "error-envelope", "invalid-id"],
    ["movies", "tv", "anime"])
  func failedRemovalRead(scenario: String, category: String) async throws {
    let container = try makeContainer()
    let context = makeSyncContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.movies_removed_from_list = "old"
    sync.tv_removed_from_list = "old"
    sync.anime_removed_from_list = "old"
    context.insert(sync)
    context.insert(V1.SDMovies(simkl: 1, title: "Preserved"))
    context.insert(V1.SDShows(simkl: 2, title: "Preserved"))
    context.insert(V1.SDAnimes(simkl: 3, title: "Preserved"))
    try context.save()
    let session = session()
    defer { session.invalidateAndCancel() }
    let outcome = await SyncFailureScope.perform {
      switch category {
      case "movies":
        await fetchAndStoreMoviesRemovedFromList(scenario, "new", context, session: session)
      case "tv": await fetchAndStoreTVRemovedFromList(scenario, "new", context, session: session)
      default: await fetchAndStoreAnimeRemovedFromList(scenario, "new", context, session: session)
      }
    }
    #expect(outcome == .incomplete)
    let fresh = ModelContext(container)
    #expect(try fresh.fetchCount(FetchDescriptor<V1.SDMovies>()) == 1)
    #expect(try fresh.fetchCount(FetchDescriptor<V1.SDShows>()) == 1)
    #expect(try fresh.fetchCount(FetchDescriptor<V1.SDAnimes>()) == 1)
    let saved = try #require(fresh.fetch(FetchDescriptor<V1.SDLastSync>()).first)
    #expect(saved.movies_removed_from_list == "old")
    #expect(saved.tv_removed_from_list == "old")
    #expect(saved.anime_removed_from_list == "old")
  }

  @Test("A malformed list response does not mark an unapplied delta as synchronized")
  func malformedPlanToWatch() async throws {
    let container = try makeContainer()
    let context = makeSyncContext(container)
    let sync = V1.SDLastSync(id: 1)
    sync.movies_plantowatch = "2026-10-01T00:00:00Z"
    context.insert(sync)
    try context.save()
    let session = session()
    defer { session.invalidateAndCancel() }
    await fetchAndStoreMoviesPlanToWatch(
      "malformed", "2026-10-12T00:00:00Z", context, session: session)
    #expect(
      try context.fetch(FetchDescriptor<V1.SDLastSync>()).first?.movies_plantowatch
        == "2026-10-01T00:00:00Z")
  }

  @Test(
    "Valid full and empty libraries reconcile only their category and advance its cursor",
    arguments: ["valid-list", "empty-object", "empty-null", "empty-array"],
    ["movies", "tv", "anime"])
  func validRemovalRead(scenario: String, category: String) async throws {
    let container = try makeContainer()
    let context = makeSyncContext(container)
    context.insert(V1.SDLastSync(id: 1))
    for id in [1, 2] {
      context.insert(V1.SDMovies(simkl: id, title: "Movie"))
      context.insert(V1.SDShows(simkl: id, title: "Show"))
      context.insert(V1.SDAnimes(simkl: id, title: "Anime"))
    }
    try context.save()
    let session = session()
    defer { session.invalidateAndCancel() }
    let outcome = await SyncFailureScope.perform {
      switch category {
      case "movies":
        await fetchAndStoreMoviesRemovedFromList(scenario, "new", context, session: session)
      case "tv": await fetchAndStoreTVRemovedFromList(scenario, "new", context, session: session)
      default: await fetchAndStoreAnimeRemovedFromList(scenario, "new", context, session: session)
      }
    }
    #expect(outcome == .succeeded)
    let fresh = ModelContext(container)
    let movieIDs = try fresh.fetch(FetchDescriptor<V1.SDMovies>()).map(\.simkl).sorted()
    let showIDs = try fresh.fetch(FetchDescriptor<V1.SDShows>()).map(\.simkl).sorted()
    let animeIDs = try fresh.fetch(FetchDescriptor<V1.SDAnimes>()).map(\.simkl).sorted()
    let expected = scenario == "valid-list" ? [1] : []
    #expect(movieIDs == (category == "movies" ? expected : [1, 2]))
    #expect(showIDs == (category == "tv" ? expected : [1, 2]))
    #expect(animeIDs == (category == "anime" ? expected : [1, 2]))
    let saved = try #require(fresh.fetch(FetchDescriptor<V1.SDLastSync>()).first)
    #expect(saved.movies_removed_from_list == (category == "movies" ? "new" : nil))
    #expect(saved.tv_removed_from_list == (category == "tv" ? "new" : nil))
    #expect(saved.anime_removed_from_list == (category == "anime" ? "new" : nil))
  }

  private func makeContainer() throws -> ModelContainer {
    try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
  }
}

private final class RecoveryFixtureProtocol: URLProtocol, @unchecked Sendable {
  static let attempts = AttemptCounts()
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    let url = request.url!
    let attempt = Self.attempts.increment(url.absoluteString)
    if url.path.hasPrefix("/retry/") && attempt == 1 {
      client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
      return
    }
    let scenario = request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(
      of: "Bearer ", with: "")
    let body: String
    let category =
      url.path.contains("movies") ? "movies" : url.path.contains("anime") ? "anime" : "shows"
    switch scenario {
    case "valid-list":
      let item = category == "movies" ? "movie" : "show"
      body = "{\"\(category)\":[{\"\(item)\":{\"ids\":{\"simkl\":1}}}]}"
    case "empty-object": body = "{}"
    case "empty-null": body = "null"
    case "empty-array": body = "{\"\(category)\":[]}"
    case "error-envelope": body = "{\"error\":\"unavailable\"}"
    case "invalid-id":
      if url.path.contains("movies") {
        body = "{\"movies\":[{}]}"
      } else if url.path.contains("anime") {
        body = "{\"anime\":[{}]}"
      } else {
        body = "{\"shows\":[{}]}"
      }
    default: body = url.path.hasPrefix("/retry/") ? "{}" : "not json"
    }
    let response = HTTPURLResponse(
      url: url, statusCode: scenario == "unauthorized" ? 401 : 200, httpVersion: nil,
      headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
}

/// URLProtocol callbacks run on Foundation queues; every access is locked.
private final class AttemptCounts: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [String: Int] = [:]
  func increment(_ key: String) -> Int {
    lock.withLock {
      values[key, default: 0] += 1
      return values[key, default: 0]
    }
  }
  func count(_ key: String) -> Int { lock.withLock { values[key, default: 0] } }
}

import Foundation
import SwiftData
import Testing

@testable import Simalytics

@MainActor
struct RatingMutationTests {
  private func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RatingFixtureProtocol.self]
    return URLSession(configuration: configuration)
  }

  @Test(
    "All scores and removal use the correct payload and endpoint",
    arguments: RatingMediaType.allCases, Array(0...10))
  func ratingContract(type: RatingMediaType, score: Int) async {
    let session = session()
    defer { session.invalidateAndCancel() }
    let token = "\(type.payloadKey):\(score)"
    #expect(
      await setSimklRating(
        simklID: 42, type: type, rating: score, accessToken: token, session: session) == .succeeded)
  }

  @Test(
    "Rating failures are surfaced",
    arguments: ["rejected", "empty", "zero", "boolean", "unauthorized", "cancelled"], [0, 7])
  func errors(scenario: String, score: Int) async {
    let session = session()
    defer { session.invalidateAndCancel() }
    let result = await setSimklRating(
      simklID: 42, type: .anime, rating: score, accessToken: "shows:\(score):\(scenario)",
      session: session)
    if scenario == "cancelled" {
      #expect(result == .cancelled)
    } else {
      guard case .failed = result else {
        Issue.record("Failure must not be reported as saved")
        return
      }
    }
  }

  @Test(
    "Whole-title removal validates the server acknowledgement", arguments: RatingMediaType.allCases,
    ["success", "rejected", "empty"])
  func removeTitle(type: RatingMediaType, scenario: String) async {
    let session = session()
    defer { session.invalidateAndCancel() }
    let token = "\(type.payloadKey):0:remove-\(scenario)"
    let error: String?
    switch type {
    case .movie:
      error = await MovieWatchlistButton.updateMovieList(42, token, "nil", session: session)
    case .show: error = await ShowWatchlistButton.updateShowList(42, token, "nil", session: session)
    case .anime:
      error = await AnimeWatchlistButton.updateAnimeList(42, token, "nil", session: session)
    }
    #expect((error == nil) == (scenario == "success"))
  }

  @Test("A confirmed removal clears the local score without deleting the title")
  func localRatingPersistence() throws {
    let container = try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.insert(V1.SDMovies(simkl: 42, status: "completed", user_rating: 8))
    context.insert(V1.SDShows(simkl: 42, user_rating: 8, status: "watching"))
    context.insert(V1.SDAnimes(simkl: 42, user_rating: 8, status: "watching"))
    try context.save()
    for type in RatingMediaType.allCases {
      try storeConfirmedRating(3, simklID: 42, type: type, context: context)
      try storeConfirmedRating(8, simklID: 42, type: type, context: context)
    }
    let rated = ModelContext(container)
    #expect(try rated.fetch(FetchDescriptor<V1.SDMovies>()).first?.user_rating == 8)
    #expect(try rated.fetch(FetchDescriptor<V1.SDShows>()).first?.user_rating == 8)
    #expect(try rated.fetch(FetchDescriptor<V1.SDAnimes>()).first?.user_rating == 8)
    for type in RatingMediaType.allCases {
      try storeConfirmedRating(0, simklID: 42, type: type, context: context)
    }
    let cleared = ModelContext(container)
    let movie = try #require(cleared.fetch(FetchDescriptor<V1.SDMovies>()).first)
    let show = try #require(cleared.fetch(FetchDescriptor<V1.SDShows>()).first)
    let anime = try #require(cleared.fetch(FetchDescriptor<V1.SDAnimes>()).first)
    #expect(movie.user_rating == nil && movie.user_rated_at == nil && movie.status == "completed")
    #expect(show.user_rating == nil && show.user_rated_at == nil && show.status == "watching")
    #expect(anime.user_rating == nil && anime.user_rated_at == nil && anime.status == "watching")
  }
}

private final class RatingFixtureProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let parts = (request.value(forHTTPHeaderField: "Authorization") ?? "").replacingOccurrences(
      of: "Bearer ", with: ""
    ).split(separator: ":").map(String.init)
    guard parts.count >= 2, let score = Int(parts[1]) else { return }
    let key = parts[0]
    let scenario = parts.last!
    let removingTitle = scenario.hasPrefix("remove-")
    if scenario == "cancelled" {
      client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
      return
    }
    var bodyData = request.httpBody
    if bodyData == nil, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var data = Data()
      var bytes = [UInt8](repeating: 0, count: 1024)
      while stream.hasBytesAvailable {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count <= 0 { break }
        data.append(contentsOf: bytes.prefix(count))
      }
      bodyData = data
    }
    let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let entries = body?[key] as? [[String: Any]]
    let item = entries?.first
    let ids = item?["ids"] as? [String: Int]
    let valid =
      request.httpMethod == "POST"
      && request.url?.path
        == (removingTitle
          ? "/sync/history/remove" : (score == 0 ? "/sync/ratings/remove" : "/sync/ratings"))
      && body?.count == 1 && entries?.count == 1 && ids?["simkl"] == 42
      && (score == 0 ? item?["rating"] == nil : item?["rating"] as? Int == score)
      && request.value(forHTTPHeaderField: "simkl-api-key") != nil
    let count = scenario == "zero" ? "0" : (scenario == "boolean" ? "true" : "1")
    let movies = key == "movies" ? count : "0"
    let shows = key == "shows" ? count : "0"
    let rejection =
      (scenario == "rejected" || scenario == "remove-rejected")
      ? "[{\"ids\":{\"simkl\":42}}]" : "[]"
    let counter = score == 0 ? "deleted" : "added"
    let bodyString =
      (scenario == "empty" || scenario == "remove-empty")
      ? "{}"
      : """
      {"\(counter)":{"movies":\(movies),"shows":\(shows)},"not_found":{"movies":[],"shows":\(rejection)}}
      """
    let response = HTTPURLResponse(
      url: request.url!, statusCode: scenario == "unauthorized" ? 401 : (valid ? 201 : 400),
      httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(bodyString.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

import Foundation
import Testing

@testable import Simalytics

@MainActor
@Suite("Episode history request/response contract")
struct EpisodeHistoryContractTests {
  @Test("Posts exactly the selected TV or absolute anime episode", arguments: [false, true])
  func requestTargetsSingleEpisode(isAnime: Bool) async {
    #expect(await mutate(isAnime: isAnime, scenario: "success") == .succeeded)
  }

  @Test("Already-watched no-op is an idempotent success", arguments: [false, true])
  func idempotentRetry(isAnime: Bool) async {
    #expect(await mutate(isAnime: isAnime, scenario: "already-watched") == .succeeded)
  }

  @Test(
    "A 201 resolver rejection does not report watched",
    arguments: ["not-found-show", "not-found-episode"])
  func resolverRejection(scenario: String) async {
    #expect(
      await mutate(isAnime: true, scenario: scenario)
        == .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.episodeNotFound)))
  }

  @Test(
    "Malformed history acknowledgement is not success",
    arguments: ["empty", "missing-not-found", "excess-episodes", "boolean-count"])
  func invalidAcknowledgement(scenario: String) async {
    #expect(
      await mutate(isAnime: false, scenario: scenario)
        == .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.invalidResponse)))
  }

  @Test(
    "401 and cancellation propagate without false success",
    arguments: ["unauthorized", "cancelled"])
  func errors(scenario: String) async {
    let result = await mutate(isAnime: false, scenario: scenario)
    if scenario == "cancelled" {
      #expect(result == .cancelled)
    } else {
      #expect(
        result == .failed(userMessage: "Your Simkl session has expired. Please sign in again."))
    }
  }

  @Test(
    "Unwatch validates both documented and live responses", arguments: [false, true],
    ["success", "already-watched", "documented"])
  func unwatchSuccess(isAnime: Bool, scenario: String) async {
    #expect(await mutate(isAnime: isAnime, scenario: scenario, remove: true) == .succeeded)
  }

  @Test(
    "Unwatch does not report success on a resolver rejection", arguments: [false, true],
    ["not-found-show", "not-found-episode"])
  func unwatchRejection(isAnime: Bool, scenario: String) async {
    #expect(
      await mutate(isAnime: isAnime, scenario: scenario, remove: true)
        == .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.episodeNotFound)))
  }

  @Test(
    "Unwatch rejects malformed success responses",
    arguments: ["empty", "missing-not-found", "excess-episodes", "boolean-count"])
  func unwatchMalformed(scenario: String) async {
    #expect(
      await mutate(isAnime: true, scenario: scenario, remove: true)
        == .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.invalidResponse)))
  }

  private func mutate(isAnime: Bool, scenario: String, remove: Bool = false) async
    -> SimklMutationResult
  {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [EpisodeHistoryFixtureProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    if remove {
      if isAnime {
        return await AnimeDetailView.markEpisodeUnwatched(
          scenario, "One Piece", 38636, 1, 1180, session: session)
      }
      return await ShowDetailView.markEpisodeUnwatched(
        scenario, "Test TV", 42, 2, 3, session: session)
    }
    if isAnime {
      return await AnimeDetailView.markEpisodeWatched(
        scenario, "One Piece", 38636, 1, 1180, session: session)
    }
    return await ShowDetailView.markEpisodeWatched(scenario, "Test TV", 42, 2, 3, session: session)
  }
}

/// No live writes: an invalid request gets a failure response so success proves
/// method, headers, app metadata, IDs and exact nested episode payload match.
private final class EpisodeHistoryFixtureProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let scenario =
      request.value(forHTTPHeaderField: "Authorization")?.replacingOccurrences(
        of: "Bearer ", with: "") ?? ""
    if scenario == "cancelled" {
      client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
      return
    }
    var bodyData = request.httpBody
    if bodyData == nil, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var data = Data()
      var bytes = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count <= 0 { break }
        data.append(contentsOf: bytes.prefix(count))
      }
      bodyData = data
    }
    let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    let remove = request.url?.path == "/sync/history/remove"
    let entries = body?[body?["anime"] != nil ? "anime" : "shows"] as? [[String: Any]]
    let isAnime = (entries?.first?["ids"] as? [String: Int])?["simkl"] == 38636
    let item = entries?.first
    let ids = item?["ids"] as? [String: Any]
    let seasons = item?["seasons"] as? [[String: Any]]
    let episodes = seasons?.first?["episodes"] as? [[String: Any]]
    let episode = episodes?.first
    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let names = Set(query.map(\.name))
    let valid =
      request.httpMethod == "POST"
      && request.url?.path == (remove ? "/sync/history/remove" : "/sync/history")
      && request.value(forHTTPHeaderField: "Content-Type") == "application/json"
      && request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("simalytics-ios/") == true
      && request.value(forHTTPHeaderField: "simkl-api-key") != nil
      && names.isSuperset(of: ["client_id", "app-name", "app-version"])
      && !names.contains("allow_rewatch") && entries?.count == 1 && body?.count == 1
      && ids?["simkl"] as? Int == (isAnime ? 38636 : 42)
      && seasons?.count == 1 && seasons?.first?["number"] as? Int == (isAnime ? 1 : 2)
      && episodes?.count == 1 && episode?["number"] as? Int == (isAnime ? 1180 : 3)
      && (remove
        ? (episode?["watched_at"] == nil && body?["anime"] == nil)
        : (episode?["watched_at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
          != nil)
    let status = scenario == "unauthorized" ? 401 : (valid ? 201 : 400)
    let responseBody: String
    let counter = remove ? "deleted" : "added"
    switch scenario {
    case "empty": responseBody = "{}"
    case "missing-not-found": responseBody = "{\"\(counter)\":{\"episodes\":1}}"
    case "boolean-count":
      responseBody =
        "{\"\(counter)\":{\"episodes\":true},\"not_found\":{\"movies\":[],\"shows\":[]}}"
    case "documented":
      responseBody =
        "{\"deleted\":{\"movies\":0,\"shows\":0,\"episodes\":1},\"not_found\":{\"movies\":[],\"shows\":[]}}"
    default:
      let count = scenario == "already-watched" ? 0 : (scenario == "excess-episodes" ? 2 : 1)
      let rejectedShow = scenario == "not-found-show" ? "[{\"ids\":{\"simkl\":38636}}]" : "[]"
      let rejectedEpisode = scenario == "not-found-episode" ? "[{\"number\":1180}]" : "[]"
      responseBody = """
        {"\(counter)":{"movies":0,"shows":0,"episodes":\(count)},"not_found":{"movies":[],"shows":\(rejectedShow),"episodes":\(rejectedEpisode)}}
        """
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Type": "application/json"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(responseBody.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

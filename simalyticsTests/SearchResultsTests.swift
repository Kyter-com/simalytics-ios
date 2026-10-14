import Foundation
import Testing

@testable import Simalytics

@MainActor
struct SearchResultsTests {
  private func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SearchFixtureProtocol.self]
    return URLSession(configuration: configuration)
  }

  @Test("Initial search loads without waiting for another keystroke")
  func initialSearch() async {
    let model = SearchResultsViewModel()
    let request = MediaSearchRequest(query: "  Moon  ", category: .all, hideAnime: false)
    let session = session()
    defer { session.invalidateAndCancel() }
    #expect(model.completedRequest == nil)
    await model.search(request, session: session, debounce: .zero)
    #expect(model.completedRequest == request)
    #expect(model.errorMessage == nil)
    #expect(model.results.map(\.endpoint_type) == ["tv", "movies", "anime"])
  }

  @Test("Hidden anime is not requested or returned")
  func hideAnime() async {
    let model = SearchResultsViewModel()
    let session = session()
    defer { session.invalidateAndCancel() }
    await model.search(
      MediaSearchRequest(query: "moon", category: .all, hideAnime: true), session: session,
      debounce: .zero)
    #expect(model.results.map(\.endpoint_type) == ["tv", "movies"])
  }

  @Test(
    "Network failure is distinct from a successful empty search",
    arguments: ["offline", "empty", "malformed", "unauthorized"])
  func emptyAndError(query: String) async {
    let model = SearchResultsViewModel()
    let session = session()
    defer { session.invalidateAndCancel() }
    let request = MediaSearchRequest(query: query, category: .movie, hideAnime: false)
    await model.search(request, session: session, debounce: .zero)
    #expect(model.results.isEmpty)
    #expect(model.completedRequest == request)
    #expect((model.errorMessage == nil) == (query == "empty"))
  }

  @Test("Cancellation leaves no false no-results state and a subsequent query can finish")
  func cancellation() async {
    let model = SearchResultsViewModel()
    let session = session()
    defer { session.invalidateAndCancel() }
    let cancelled = Task {
      await model.search(
        MediaSearchRequest(query: "cancelled", category: .all, hideAnime: false), session: session,
        debounce: .seconds(30))
    }
    cancelled.cancel()
    await cancelled.value
    #expect(model.completedRequest == nil)
    #expect(model.errorMessage == nil)
    let request = MediaSearchRequest(query: "moon", category: .tv, hideAnime: false)
    await model.search(request, session: session, debounce: .zero)
    #expect(model.completedRequest == request)
    #expect(model.results.count == 1)
  }
}

private final class SearchFixtureProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first
    { $0.name == "q" }?.value
    if query == "offline" {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    let type = request.url!.lastPathComponent
    let endpoint = type == "movie" ? "movies" : type
    let body: String
    switch query {
    case "empty": body = "[]"
    case "malformed": body = "{}"
    default:
      body = """
        [{"title":"Moon","year":2020,"endpoint_type":"\(endpoint)","ids":{"simkl_id":42}}]
        """
    }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: query == "unauthorized" ? 401 : 200, httpVersion: nil,
      headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

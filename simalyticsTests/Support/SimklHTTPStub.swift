import Foundation
import os

/// A URLProtocol that answers every request with one shared handler and logs
/// what it saw. Suites using it must be `.serialized`.
final class SimklHTTPStub: URLProtocol, @unchecked Sendable {
  struct Request: Sendable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data

    var path: String { url.path }
    var host: String { url.host ?? "" }

    var query: [String: String] {
      Dictionary(
        (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map {
          ($0.name, $0.value ?? "")
        }, uniquingKeysWith: { _, last in last })
    }

    /// An `application/x-www-form-urlencoded` body, decoded.
    var form: [String: String] {
      var components = URLComponents()
      components.percentEncodedQuery = String(decoding: body, as: UTF8.self)
      return Dictionary(
        (components.queryItems ?? []).map { ($0.name, $0.value ?? "") },
        uniquingKeysWith: { _, last in last })
    }

    func header(_ name: String) -> String? {
      headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    var bearer: String? {
      header("Authorization").map { $0.replacingOccurrences(of: "Bearer ", with: "") }
    }
  }

  struct Response: Sendable {
    var status = 200
    var headers: [String: String] = ["Content-Type": "application/json"]
    var body = Data("{}".utf8)
    var error: URLError.Code?

    static func json(_ status: Int = 200, _ text: String, headers: [String: String] = [:])
      -> Response
    {
      Response(
        status: status, headers: ["Content-Type": "application/json"].merging(headers) { $1 },
        body: Data(text.utf8))
    }

    static func failure(_ code: URLError.Code) -> Response { Response(error: code) }
  }

  typealias Handler = @Sendable (Request) -> Response

  private struct State {
    var handler: Handler?
    var log: [Request] = []
  }

  private static let state = OSAllocatedUnfairLock(initialState: State())

  /// Installs `handler` and returns a session whose requests reach it.
  static func session(_ handler: @escaping Handler) -> URLSession {
    state.withLock { $0 = State(handler: handler) }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SimklHTTPStub.self]
    return URLSession(configuration: configuration)
  }

  static var log: [Request] { state.withLock { $0.log } }

  static func requests(to path: String) -> [Request] { log.filter { $0.path == path } }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let recorded = Request(
      method: request.httpMethod ?? "GET", url: request.url!,
      headers: request.allHTTPHeaderFields ?? [:], body: Self.body(of: request))
    let handler = Self.state.withLock { state -> Handler? in
      state.log.append(recorded)
      return state.handler
    }
    guard let handler else {
      client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
      return
    }
    let response = handler(recorded)
    if let error = response.error {
      client?.urlProtocol(self, didFailWithError: URLError(error))
      return
    }
    let http = HTTPURLResponse(
      url: request.url!, statusCode: response.status, httpVersion: "HTTP/1.1",
      headerFields: response.headers)!
    client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: response.body)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private static func body(of request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      if count <= 0 { break }
      data.append(contentsOf: buffer.prefix(count))
    }
    return data
  }
}

/// A settable clock for sessions under test.
final class SimklTestClock: Sendable {
  private let current: OSAllocatedUnfairLock<Date>

  init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
    current = OSAllocatedUnfairLock(initialState: start)
  }

  var now: Date { current.withLock { $0 } }

  func advance(_ seconds: TimeInterval) { current.withLock { $0 = $0.addingTimeInterval(seconds) } }
}

/// Polls until `condition` holds, for state that settles asynchronously.
@MainActor
func eventually(
  timeout: Duration = .seconds(2), _ condition: @MainActor () async -> Bool
) async -> Bool {
  let deadline = ContinuousClock.now + timeout
  while ContinuousClock.now < deadline {
    if await condition() { return true }
    try? await Task.sleep(for: .milliseconds(10))
  }
  return await condition()
}

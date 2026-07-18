import Foundation
import Testing

@testable import Simalytics

@Suite("Simkl mutation errors")
struct SimklMutationRequestTests {
  @Test("Cancellation variants remain recognized")
  func recognizesCancellation() {
    #expect(isSimklCancellationError(CancellationError()))
    #expect(isSimklCancellationError(URLError(.cancelled)))
    #expect(
      isSimklCancellationError(
        NSError(domain: NSURLErrorDomain, code: URLError.cancelled.rawValue)
      ))
    #expect(isSimklCancellationError(URLError(.timedOut)) == false)
  }

  @Test(
    "Expected transient network failures remain filtered",
    arguments: [
      URLError.Code.timedOut,
      .networkConnectionLost,
      .notConnectedToInternet,
      .cannotConnectToHost,
      .cannotFindHost,
      .dnsLookupFailed,
    ]
  )
  func recognizesExpectedTransientURLFailures(code: URLError.Code) {
    #expect(isExpectedTransientNetworkError(URLError(code)))
    #expect(
      isExpectedTransientNetworkError(
        NSError(domain: NSURLErrorDomain, code: code.rawValue)
      ))
  }

  @Test("Deterministic schema and authentication failures are not filtered")
  func doesNotFilterDeterministicFailures() {
    let decoding = DecodingError.dataCorrupted(
      .init(codingPath: [], debugDescription: "contract mismatch")
    )
    #expect(isExpectedTransientNetworkError(decoding) == false)
    #expect(isSimklCancellationError(decoding) == false)

    let authentication = SimklMutationError.httpStatusCode(401, reason: nil)
    #expect(isExpectedTransientNetworkError(authentication) == false)
    #expect(isSimklCancellationError(authentication) == false)
  }

  @Test("Server reason retains only bounded safe categories")
  func sanitizesServerReason() throws {
    let data = try #require(
      """
      {"code":"invalid_episode","message":"Episode 4 is invalid; token secret-value and private title"}
      """.data(using: .utf8)
    )
    let reason = try #require(parseSimklServerErrorReason(from: data))

    #expect(reason.code == "invalid_episode")
    #expect(reason.message == "Episode selection was rejected.")
    #expect(String(describing: reason).contains("secret-value") == false)
    #expect(String(describing: reason).contains("private title") == false)
  }

  @Test("Unsafe server fields are discarded")
  func discardsUnsafeReason() throws {
    let oversizedNumericCode = String(repeating: "7", count: 20)
    let data = try JSONSerialization.data(
      withJSONObject: [
        "code": "PrivateTitle",
        "secondary_code": oversizedNumericCode,
        "message": "Unclassified private response details",
      ])

    #expect(parseSimklServerErrorReason(from: data) == nil)
  }
}

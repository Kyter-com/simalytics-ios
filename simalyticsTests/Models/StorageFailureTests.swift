import Foundation
import Testing

@testable import Simalytics

struct StorageFailureTests {
  @Test("Disk-full errors are recognized through persistence wrappers", arguments: [0, 1, 2, 3])
  func diskFull(variant: Int) {
    let underlying = NSError(domain: "NSSQLiteErrorDomain", code: 13)
    let errors = [
      underlying,
      NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError),
      NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)),
      NSError(
        domain: NSCocoaErrorDomain, code: 134060, userInfo: [NSUnderlyingErrorKey: underlying]),
    ]
    #expect(StorageFailure.classify(errors[variant]) == .insufficientSpace)
  }

  @Test("Sentry's shared-memory open failure is a recoverable storage failure")
  func sqliteUserInfo() {
    let error = NSError(
      domain: NSCocoaErrorDomain, code: 256, userInfo: ["NSSQLiteErrorDomain": 4618])
    #expect(StorageFailure.classify(error) == .unavailable)
  }

  @Test("Detailed underlying errors prefer the actionable disk-full cause")
  func multipleErrors() {
    let error = NSError(
      domain: NSCocoaErrorDomain, code: 134060,
      userInfo: [
        "NSDetailedErrors": [
          NSError(domain: "NSSQLiteErrorDomain", code: 13),
          NSError(domain: "NSSQLiteErrorDomain", code: 4618),
        ]
      ])
    #expect(StorageFailure.classify(error) == .insufficientSpace)
  }

  @Test(
    "Network, decoding, unrelated file reads, and SQLite contention do not masquerade as disk failure"
  )
  func unrelatedErrors() {
    #expect(StorageFailure.classify(URLError(.resourceUnavailable)) == nil)
    #expect(StorageFailure.classify(SimklMutationError.invalidResponse) == nil)
    #expect(StorageFailure.classify(NSError(domain: NSCocoaErrorDomain, code: 256)) == nil)
    #expect(StorageFailure.classify(NSError(domain: "NSSQLiteErrorDomain", code: 5)) == nil)
  }
}

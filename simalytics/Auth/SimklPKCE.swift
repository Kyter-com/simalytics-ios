//
//  SimklPKCE.swift
//  simalytics
//

import CryptoKit
import Foundation
import Security

/// The PKCE pair for one browser sign-in (RFC 7636, `S256`, which AUTH V2
/// requires). The verifier never leaves the device until the code exchange;
/// only its hash travels through the browser.
struct SimklPKCE: Sendable, Equatable {
  let verifier: String
  let challenge: String

  init(verifier: String) {
    self.verifier = verifier
    self.challenge = Self.challenge(for: verifier)
  }

  /// 32 random bytes, base64url-encoded: a 43-character verifier.
  static func generate() throws -> SimklPKCE {
    SimklPKCE(verifier: try randomURLSafeString(byteCount: 32))
  }

  /// The SHA-256 of the verifier *string*, base64url-encoded without padding.
  static func challenge(for verifier: String) -> String {
    base64URLEncoded(Data(SHA256.hash(data: Data(verifier.utf8))))
  }

  /// A random value for PKCE or `state`. Throws instead of returning a
  /// predictable all-zero value when the system can't produce randomness.
  static func randomURLSafeString(byteCount: Int) throws -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw SimklSignInError.randomGenerationFailed
    }
    return base64URLEncoded(Data(bytes))
  }

  static func base64URLEncoded(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

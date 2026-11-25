//
//  SimklCredential.swift
//  simalytics
//

import Foundation

/// The Simkl account a credential belongs to. On reconnect it tells the same
/// person apart from a different account, so another account's changes never
/// merge into this device's library.
struct SimklAccount: Codable, Equatable, Sendable {
  let id: Int
  var name: String?
}

/// What the app holds to call Simkl for the signed-in person.
///
/// Never logged: `description` and `debugDescription` redact the tokens, so a
/// stray `print` or a crash report can't carry them.
struct SimklCredential: Codable, Equatable, Sendable {
  var version: SimklAuthVersion
  var accessToken: String
  /// AUTH V2 only. Non-rotating: each refresh returns the same value and slides
  /// its 180-day window forward.
  var refreshToken: String?
  var accessTokenExpiresAt: Date?
  var refreshTokenExpiresAt: Date?
  /// AUTH V2 only: `media:read`, or `media:read media:write`.
  var scope: String?
  var account: SimklAccount?
  /// Set when Simkl stopped accepting this credential, so a relaunch doesn't
  /// keep asking with a token that can't come back.
  var invalidatedAt: Date?

  var client: SimklClient { .client(for: version) }

  var canRefresh: Bool { version == .v2 && !(refreshToken ?? "").isEmpty }

  /// AUTH V1 tokens are always full access; AUTH V2 tokens only with `media:write`.
  var canWrite: Bool { version == .v1 || SimklScope.grantsWrite(scope) }

  /// Whether the access token is within the refresh window or already expired.
  func needsRefresh(at now: Date, leeway: TimeInterval = SimklOAuthConfig.refreshLeeway) -> Bool {
    guard canRefresh, let accessTokenExpiresAt else { return false }
    return accessTokenExpiresAt.timeIntervalSince(now) <= leeway
  }

  func isExpired(at now: Date) -> Bool {
    guard let accessTokenExpiresAt else { return false }
    return accessTokenExpiresAt <= now
  }
}

extension SimklCredential: CustomStringConvertible, CustomDebugStringConvertible {
  var description: String {
    "SimklCredential(\(version.rawValue), account: \(account.map { String($0.id) } ?? "unknown"), "
      + "refreshable: \(canRefresh), canWrite: \(canWrite), invalidated: \(invalidatedAt != nil))"
  }

  var debugDescription: String { description }
}

enum SimklScope {
  /// Simkl grants write only for the exact token `media:write`; anything else,
  /// including a misspelling, quietly means read-only.
  static func grantsWrite(_ scope: String?) -> Bool {
    guard let scope else { return false }
    return scope.split(whereSeparator: { $0 == " " || $0 == "," })
      .contains { $0 == Substring(SimklOAuthConfig.writeScope) }
  }
}

/// The body of a successful `POST /oauth2/token`, for all three grants.
struct SimklTokenResponse: Decodable, Sendable {
  let accessToken: String
  let tokenType: String?
  let expiresIn: TimeInterval?
  let refreshToken: String?
  let scope: String?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case tokenType = "token_type"
    case expiresIn = "expires_in"
    case refreshToken = "refresh_token"
    case scope
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    accessToken = try container.decode(String.self, forKey: .accessToken)
    tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
    if let seconds = try? container.decodeIfPresent(Double.self, forKey: .expiresIn) {
      expiresIn = seconds
    } else if let text = try? container.decodeIfPresent(String.self, forKey: .expiresIn) {
      expiresIn = TimeInterval(text)
    } else {
      expiresIn = nil
    }
    refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
    scope = try container.decodeIfPresent(String.self, forKey: .scope)
  }

  /// Simkl's documented lifetime, used only if a response leaves it out.
  static let defaultAccessTokenLifetime: TimeInterval = 7 * 24 * 60 * 60

  /// The AUTH V2 credential this response describes. A refresh carries over what
  /// the response doesn't repeat, such as the account.
  func credential(issuedAt: Date, replacing previous: SimklCredential? = nil) throws
    -> SimklCredential
  {
    let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    // RFC 6749 makes token_type case-insensitive: V1 sends "bearer", V2 "Bearer".
    guard !token.isEmpty,
      tokenType.map({ $0.caseInsensitiveCompare("bearer") == .orderedSame }) ?? true
    else { throw SimklOAuthError.invalidResponse }
    let refresh = refreshToken.flatMap { $0.isEmpty ? nil : $0 } ?? previous?.refreshToken
    guard refresh != nil else { throw SimklOAuthError.invalidResponse }
    return SimklCredential(
      version: .v2,
      accessToken: token,
      refreshToken: refresh,
      accessTokenExpiresAt: issuedAt.addingTimeInterval(
        max(60, expiresIn ?? Self.defaultAccessTokenLifetime)),
      refreshTokenExpiresAt: issuedAt.addingTimeInterval(SimklOAuthConfig.refreshTokenLifetime),
      scope: scope ?? previous?.scope,
      account: previous?.account,
      invalidatedAt: nil)
  }
}

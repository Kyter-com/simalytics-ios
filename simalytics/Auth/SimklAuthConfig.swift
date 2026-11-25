//
//  SimklAuthConfig.swift
//  simalytics
//

import Foundation

/// Which Simkl sign-in a credential came from. Simkl treats AUTH V1 and AUTH V2
/// as separate apps, and a token only works with the client ID it was issued for.
/// See https://api.simkl.org/guides/migrating-v1-to-v2
enum SimklAuthVersion: String, Codable, Sendable {
  /// The original sign-in: a five-year token with no refresh. New sign-ins never
  /// use it; it stays for people who signed in before AUTH V2 until they reconnect.
  case v1
  /// OAuth 2.0 with PKCE: a 7-day access token plus a sliding 180-day refresh token.
  case v2
}

/// A Simkl app registration. Every request picks its client ID from the
/// credential it carries, so a V2 token is never sent with the V1 client ID or
/// the reverse, which Simkl rejects.
struct SimklClient: Sendable, Equatable {
  let version: SimklAuthVersion
  let clientID: String

  /// AUTH V1 app #49868. Expected to stop working around April 2027.
  static let v1 = SimklClient(
    version: .v1, clientID: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9")

  /// AUTH V2 app #8275966, registered as "Mobile, desktop & browser apps": a public
  /// client with PKCE and no secret. Simkl publishes client IDs by design.
  static let v2 = SimklClient(
    version: .v2, clientID: "c43e982d8db0674c1f5a2221f6510fc500dd71656d27b49f0c333b10ae2c9845")

  static func client(for version: SimklAuthVersion) -> SimklClient {
    switch version {
    case .v1: .v1
    case .v2: .v2
    }
  }

  /// Requests without a user token (catalog lookups, discovery files) identify
  /// the app only. V2 keeps working after V1 retires, and its catalog traffic
  /// isn't counted against anyone's allowance.
  static let anonymous = v2
}

/// AUTH V2 endpoints and the values this app registers with them.
enum SimklOAuthConfig {
  /// Compared exactly with the `iss` on every callback (RFC 9207).
  static let issuer = "https://simkl.com"
  /// The consent page lives on simkl.com; everything else is on api.simkl.com.
  static let authorizeURL = URL(string: "https://simkl.com/oauth2/authorize")!
  static let tokenURL = URL(string: "https://api.simkl.com/oauth2/token")!
  static let revokeURL = URL(string: "https://api.simkl.com/oauth2/revoke")!
  /// Must match the registered redirect character for character, on both the
  /// authorize URL and the code exchange.
  static let redirectURI = "simalytics://auth/simkl"
  static let callbackScheme = "simalytics"
  /// Omitting the scope, or misspelling it, silently yields a read-only token.
  static let requestedScope = "media:read media:write"
  static let writeScope = "media:write"
  /// Refresh when the access token is this close to expiring. Simkl suggests
  /// about a day before its 7-day expiry.
  static let refreshLeeway: TimeInterval = 24 * 60 * 60
  /// A refresh token lasts 180 days from its last use. Simkl doesn't return
  /// this, so it's tracked from each exchange and refresh.
  static let refreshTokenLifetime: TimeInterval = 180 * 24 * 60 * 60
}

/// When to nudge people still on the AUTH V1 sign-in. Simkl expects V1 to stop
/// working around April 2027 but hasn't fixed the date. These follow the
/// cadence in Simkl's migration guide: quiet at first, then a banner that comes
/// back every couple of weeks, then one that stays. Move them if Simkl announces
/// a different date.
enum SimklMigrationSchedule {
  /// From here a dismissible banner appears, at most every `bannerInterval`.
  static let bannerStart = date(2027, 1, 15)
  /// From here the banner stays until the person upgrades.
  static let persistentStart = date(2027, 3, 1)
  static let bannerInterval: TimeInterval = 14 * 24 * 60 * 60
  /// Shown in copy. Not used to switch anything off: V1 credentials keep
  /// working until Simkl actually rejects them.
  static let expectedRetirement = "April 2027"

  enum Stage: Equatable, Sendable {
    /// Only the Settings row offers the upgrade.
    case settingsOnly
    /// A banner that can be dismissed until `bannerInterval` passes.
    case dismissibleBanner
    /// A banner that stays until the person upgrades.
    case persistentBanner
  }

  static func stage(at now: Date) -> Stage {
    if now >= persistentStart { return .persistentBanner }
    if now >= bannerStart { return .dismissibleBanner }
    return .settingsOnly
  }

  /// Whether the upgrade banner should show, given when it was last dismissed.
  static func showsBanner(at now: Date, lastDismissed: Date?) -> Bool {
    switch stage(at: now) {
    case .settingsOnly: return false
    case .persistentBanner: return true
    case .dismissibleBanner:
      guard let lastDismissed else { return true }
      return now.timeIntervalSince(lastDismissed) >= bannerInterval
    }
  }

  private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }
}

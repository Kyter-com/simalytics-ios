//
//  SimklAuthTelemetry.swift
//  simalytics
//

import Foundation
import Sentry

/// Sign-in state for crash reports, without tokens or account details. The
/// `simkl_auth` tag shows how many people still run on the AUTH V1 sign-in.
enum SimklAuthTelemetry {
  static func record(_ snapshot: SimklSessionSnapshot) {
    let value: String
    switch snapshot.status {
    case .signedOut: value = "signed_out"
    case .connected(let version, _): value = version.rawValue
    case .reconnectRequired(let reason, _, _): value = "reconnect_\(reason.rawValue)"
    }
    SentrySDK.configureScope { scope in
      scope.setTag(value: value, key: "simkl_auth")
    }
  }

  static func breadcrumb(_ message: String) {
    let crumb = Breadcrumb(level: .info, category: "auth")
    crumb.message = message
    SentrySDK.addBreadcrumb(crumb)
  }

  /// The session is built before Sentry starts, so the app reports its launch
  /// state once Sentry is running.
  static func recordLaunch(_ session: SimklSession) {
    record(session.initialSnapshot)
    if let failure = session.initialLoadFailure {
      SentrySDK.capture(message: "Simkl credential unreadable at launch (\(failure))")
    }
  }
}

//
//  SimklAccountNotice.swift
//  simalytics
//

import AuthenticationServices
import SwiftData
import SwiftUI

/// Something about the Simkl sign-in worth a card at the top of a tab.
enum SimklAccountNoticeKind: Equatable {
  /// Simkl won't accept the saved sign-in. Local data stays; syncing waits.
  case reconnect(SimklReconnectReason)
  /// Still on AUTH V1, inside the migration window.
  case legacyUpgrade(dismissible: Bool)
  /// Simkl's daily allowance is spent; syncing waits for the reset.
  case dailyLimit(resetsAt: Date)
}

extension Auth {
  func notice(at now: Date, upgradeDismissedAt: Date?) -> SimklAccountNoticeKind? {
    if let reconnectReason { return .reconnect(reconnectReason) }
    if usesLegacySignIn,
      SimklMigrationSchedule.showsBanner(at: now, lastDismissed: upgradeDismissedAt)
    {
      return .legacyUpgrade(
        dismissible: SimklMigrationSchedule.stage(at: now) == .dismissibleBanner)
    }
    if let reset = dailyLimitResetsAt, reset > now { return .dailyLimit(resetsAt: reset) }
    return nil
  }
}

/// Copy for sign-in states, shared by the notice and Settings. It says what's
/// known and no more: a rejected token has more than one cause, so none of
/// these claims a specific one.
enum SimklAccountCopy {
  static func reconnectMessage(_ reason: SimklReconnectReason) -> String {
    switch reason {
    case .signInEnded:
      "Simkl stopped accepting this device's sign-in. That happens if Simalytics is removed in Simkl's Connected Apps or goes unused for six months. Reconnect to resume syncing. Your library on this device stays put."
    case .legacySignInEnded:
      "Simkl stopped accepting the older sign-in this device used. Reconnect once to resume syncing. Your lists and history are safe on Simkl, and your library on this device stays put."
    case .missingWriteAccess:
      "Simalytics needs permission to update your Simkl library. Reconnect and allow access to keep your lists in sync."
    case .credentialMissing:
      "This device has your library but not your Simkl sign-in, as after restoring from a backup. Reconnect to resume syncing."
    }
  }

  static let upgradeMessage =
    "Simkl is retiring the sign-in this device first used, around \(SimklMigrationSchedule.expectedRetirement). Upgrade once to keep syncing: you approve Simalytics on simkl.com, Simalytics never sees your password, and your lists and history stay put."

  static let signInPrivacy =
    "Sign-in opens simkl.com. Simalytics never sees your password."

  /// Why syncing paused for Simkl's daily limit. AUTH V1 shares one allowance
  /// among everyone on Simalytics' older sign-in, so there upgrading is the fix.
  static func dailyLimitMessage(resumes: String, legacy: Bool) -> String {
    legacy
      ? "Simkl's older sign-in shares one daily allowance among everyone using Simalytics, and today's is used up. Syncing resumes \(resumes). Upgrade your sign-in to get your own allowance and sync right away."
      : "Syncing resumes \(resumes). Simkl counts requests from every app you've connected, listed in its Connected Apps settings."
  }

  // MARK: Switching accounts

  /// A Simkl username for copy, or nil when the account didn't share one.
  static func name(_ account: SimklAccount) -> String? {
    guard let name = account.name?.trimmingCharacters(in: .whitespacesAndNewlines),
      !name.isEmpty
    else { return nil }
    return name
  }

  static func useAccountButton(_ new: SimklAccount) -> String {
    "Use \(name(new) ?? "New Account")"
  }

  static func keepAccountButton(_ previous: SimklAccount) -> String {
    "Keep \(name(previous) ?? "Current Account")"
  }

  static func switchMessage(new: SimklAccount, previous: SimklAccount) -> String {
    let approved = name(new).map { "as \($0)" } ?? "with a different Simkl account"
    let library = name(previous).map { "\($0)'s" } ?? "another account's"
    return
      "You approved Simalytics \(approved), but this device has \(library) library. Switching replaces this device's copy with the new account's library. Nothing changes on Simkl."
  }
}

/// A card for reconnecting, upgrading the AUTH V1 sign-in, or waiting out the
/// daily limit. Renders nothing when there's nothing to say.
struct SimklAccountNotice: View {
  @Environment(Auth.self) private var auth
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @Environment(\.modelContext) private var modelContext
  @AppStorage(SimklAccountNotice.dismissedKey) private var dismissedAt: Double = 0

  /// Outside a List, the card draws its own background.
  var standalone = false
  /// Space around a standalone card, applied only when there is one, so an
  /// absent notice leaves no gap.
  var margins = EdgeInsets()

  static let dismissedKey = "simklUpgradeBannerDismissedAt"

  var body: some View {
    if let notice = auth.notice(at: .now, upgradeDismissedAt: dismissedDate) {
      if standalone {
        card(for: notice)
          .padding()
          .background(.regularMaterial, in: .rect(cornerRadius: 16))
          .padding(margins)
      } else {
        card(for: notice)
      }
    }
  }

  private var dismissedDate: Date? {
    dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil
  }

  @ViewBuilder
  private func card(for notice: SimklAccountNoticeKind) -> some View {
    switch notice {
    case .reconnect(let reason):
      NoticeCard(
        symbol: "exclamationmark.arrow.triangle.2.circlepath", tint: .orange,
        title: reason == .missingWriteAccess ? "Allow Simalytics on Simkl" : "Reconnect to Simkl",
        message: SimklAccountCopy.reconnectMessage(reason)
      ) {
        signInButton("Reconnect")
      }
    case .legacyUpgrade(let dismissible):
      NoticeCard(
        symbol: "arrow.triangle.2.circlepath.circle", tint: .blue,
        title: "Simkl Is Upgrading Sign-In",
        message: SimklAccountCopy.upgradeMessage
      ) {
        signInButton("Upgrade Sign-In")
        if dismissible {
          Button("Not Now") { dismissedAt = Date.now.timeIntervalSince1970 }
            .buttonStyle(.bordered)
        }
      }
    case .dailyLimit(let resetsAt):
      let legacy = auth.authVersion == .v1
      NoticeCard(
        symbol: "hourglass", tint: .secondary,
        title: "Simkl's Daily Limit Reached",
        message: SimklAccountCopy.dailyLimitMessage(
          resumes: SimklDailyLimit.remainingDescription(until: resetsAt, from: .now),
          legacy: legacy)
      ) {
        if legacy {
          signInButton("Upgrade Sign-In")
        } else {
          Link(
            "Open Connected Apps",
            destination: URL(string: "https://simkl.com/settings/connected-apps/")!)
        }
      }
    }
  }

  private func signInButton(_ title: String) -> some View {
    Button {
      Task {
        await auth.signIn(
          authenticate: webAuthenticationSession.simklAuthenticate(),
          resetLibrary: { LocalLibrary.reset(modelContext) })
      }
    } label: {
      if auth.isSigningIn {
        ProgressView().accessibilityLabel("Waiting for Simkl")
      } else {
        Text(title)
      }
    }
    .buttonStyle(.borderedProminent)
    .disabled(auth.isSigningIn)
  }
}

private struct NoticeCard<Actions: View>: View {
  let symbol: String
  let tint: Color
  let title: String
  let message: String
  @ViewBuilder let actions: Actions

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label {
        Text(title).font(.headline)
      } icon: {
        Image(systemName: symbol).foregroundStyle(tint)
      }
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 12) { actions }
        .controlSize(.small)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
  }
}

/// The notice as the first section of a List, present only when there's one.
struct SimklAccountNoticeSection: View {
  @Environment(Auth.self) private var auth
  @AppStorage(SimklAccountNotice.dismissedKey) private var dismissedAt: Double = 0

  var body: some View {
    let dismissed = dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil
    if auth.notice(at: .now, upgradeDismissedAt: dismissed) != nil {
      Section { SimklAccountNotice() }
    }
  }
}

/// The standalone card as the first row of a plain List, present only when
/// there's a notice. It scrolls with the rows, so at large text sizes it can
/// never cover them or push its button out of reach.
struct SimklAccountNoticeRow: View {
  @Environment(Auth.self) private var auth
  @AppStorage(SimklAccountNotice.dismissedKey) private var dismissedAt: Double = 0

  var body: some View {
    let dismissed = dismissedAt > 0 ? Date(timeIntervalSince1970: dismissedAt) : nil
    if auth.notice(at: .now, upgradeDismissedAt: dismissed) != nil {
      SimklAccountNotice(standalone: true)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
  }
}

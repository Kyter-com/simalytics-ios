//
//  SettingsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct SettingsView: View {
  @Environment(Auth.self) private var auth
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @AppStorage("blurEpisodeImages") private var blurImages = false
  @AppStorage("useFiveStarRating") private var useFiveStarRating = false
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage(AppTab.preferenceKey) private var defaultTab = AppTab.defaultLaunchTab
  @AppStorage(RewatchStore.preferenceKey) private var trackRewatches = false
  @State private var showResetConfirmation = false
  @State private var showSignOutConfirmation = false
  @State private var isCheckingRewatchPlan = false
  @State private var showRewatchPlanRequired = false
  @State private var rewatchPlanError: String?
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  @Environment(\.modelContext) private var modelContext

  /// Sign Out and Reset & Sign Out both discard this device's library copy.
  /// Signing out first stops any running sync from restoring it.
  private func signOut() {
    Task { await auth.signOut(resetLibrary: { LocalLibrary.reset(modelContext) }) }
  }

  /// Signs in, reconnects, or upgrades an AUTH V1 sign-in. The library stays
  /// when the same Simkl account approves.
  private func signIn() {
    Task {
      await auth.signIn(
        authenticate: webAuthenticationSession.simklAuthenticate(),
        resetLibrary: { LocalLibrary.reset(modelContext) })
    }
  }

  private var accountStatusText: String {
    switch auth.status {
    case .signedOut: "Not Connected"
    case .connected(.v1, _): "Connected (Legacy)"
    case .connected: "Connected"
    case .reconnectRequired: "Reconnect Needed"
    }
  }

  private var accountFooter: String? {
    switch auth.status {
    case .signedOut:
      SimklAccountCopy.signInPrivacy
    case .connected(.v1, _):
      SimklAccountCopy.upgradeMessage
        + " Afterward Simalytics may be listed twice in Simkl's Connected Apps; you can remove the older one."
    case .connected:
      nil
    case .reconnectRequired(let reason, _, _):
      SimklAccountCopy.reconnectMessage(reason)
    }
  }

  private var trackRewatchesBinding: Binding<Bool> {
    Binding {
      trackRewatches
    } set: { enabled in
      if enabled {
        Task { await enableRewatches() }
      } else {
        trackRewatches = false
        RewatchStore.shared.clearSessions()
      }
    }
  }

  /// SIMKL only records rewatches for PRO and VIP plans and silently ignores
  /// the rest, so read the plan before turning tracking on.
  private func enableRewatches() async {
    guard !isCheckingRewatchPlan, auth.isConnected else { return }
    isCheckingRewatchPlan = true
    defer { isCheckingRewatchPlan = false }
    let account = auth.accountSessionID
    do {
      let accountType = try await fetchSimklAccountType()
      RewatchStore.shared.updatePlan(accountType, settingsActivity: nil, account: account)
      guard RewatchStore.shared.isPlanEligible else {
        showRewatchPlanRequired = true
        return
      }
      trackRewatches = true
      globalLoadingIndicator.startSync()
      await syncLatestActivities(modelContainer: modelContext.container)
      globalLoadingIndicator.stopSync()
    } catch {
      guard !isSimklCancellationError(error) else { return }
      reportError(error)
      // Name Simkl's answer, such as an expired sign-in, instead of blaming the connection.
      rewatchPlanError =
        error is SimklMutationError || error is SimklAuthError
        ? simklMutationUserMessage(for: error)
        : "Couldn't check your Simkl plan. Check your connection and try again."
    }
  }

  var body: some View {
    NavigationStack {
      VStack {
        Form {
          Section {
            HStack {
              Image(systemName: "link.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)

              // At accessibility sizes the status goes under the title; beside
              // it, both columns are too narrow and words break mid-word.
              let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout())
              layout {
                VStack(alignment: .leading, spacing: 2) {
                  Text("Simkl Status")
                  if let name = auth.account?.name, !name.isEmpty {
                    Text(name)
                      .font(.footnote)
                      .foregroundStyle(.secondary)
                  }
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                // The dot stays beside the first line when the status wraps.
                HStack(alignment: .firstTextBaseline) {
                  Text(accountStatusText)
                    .foregroundStyle(.secondary)
                  PulseCircle(active: auth.isConnected)
                }
              }
            }
            .accessibilityElement(children: .combine)

            switch auth.status {
            case .signedOut:
              signInButton("Sign In")
            case .connected(let version, _):
              if version == .v1 {
                signInButton("Upgrade Sign-In")
              }
              signOutButton
            case .reconnectRequired(let reason, _, _):
              signInButton(reason == .missingWriteAccess ? "Reconnect and Allow Access" : "Reconnect")
              signOutButton
            }
          } header: {
            Text("Account")
          } footer: {
            if let accountFooter {
              Text(accountFooter)
            }
          }

          Section {
            NavigationLink {
              DefaultTabSettingsView()
            } label: {
              HStack {
                Label {
                  Text("Default Tab")
                } icon: {
                  Image(systemName: "house.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
                }
                Spacer()
                Text(defaultTab.title)
                  .foregroundStyle(.secondary)
              }
            }
          } header: {
            Text("On Launch")
          }

          Section {
            Toggle(isOn: $blurImages) {
              Label {
                Text("Blur Episode Images")
              } icon: {
                Image(systemName: "photo.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.purple)
                  .frame(width: 28, height: 28)
              }
            }

            Toggle(isOn: $useFiveStarRating) {
              Label {
                Text("Use 5-Star Ratings")
              } icon: {
                Image(systemName: "star.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.yellow)
                  .frame(width: 28, height: 28)
              }
            }

            Toggle(isOn: $hideAnime) {
              Label {
                Text("Hide Anime")
              } icon: {
                Image(systemName: "eye.slash.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.orange)
                  .frame(width: 28, height: 28)
              }
            }
          } header: {
            Text("Display")
          }

          Section {
            Toggle(isOn: trackRewatchesBinding) {
              Label {
                HStack {
                  Text("Track Rewatches")
                  if isCheckingRewatchPlan {
                    Spacer()
                    ProgressView()
                  }
                }
              } icon: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.teal)
                  .frame(width: 28, height: 28)
              }
            }
            .disabled(!auth.isConnected || isCheckingRewatchPlan)
            .alert("Simkl PRO or VIP Required", isPresented: $showRewatchPlanRequired) {
              Button("OK", role: .cancel) {}
            } message: {
              Text(
                "Rewatch tracking is part of Simkl PRO and VIP. Your Simkl account is on the free plan, so Simkl doesn't record rewatches for it."
              )
            }
          } header: {
            Text("Rewatches")
          } footer: {
            Text(
              "Log each rewatch as its own viewing with separate episode progress, see your next rewatch episode in Up Next, and log movies you watch again. Requires Simkl PRO or VIP."
            )
          }
          .alert(
            "Couldn't Turn On Rewatches",
            isPresented: Binding(
              get: { rewatchPlanError != nil },
              set: { if !$0 { rewatchPlanError = nil } }
            )
          ) {
            Button("OK", role: .cancel) { rewatchPlanError = nil }
          } message: {
            Text(rewatchPlanError ?? "Please try again.")
          }

          Section(header: Text("Support")) {
            Button(action: {
              UIApplication.shared.open(URL(string: "https://github.com/Kyter-com/simalytics-ios/")!)
            }) {
              HStack {
                Image("GitHub")
                  .font(.title2)
                  .foregroundStyle(.primary)
                  .frame(width: 28, height: 28)

                Text("GitHub")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }
            Button(action: {
              let email = "dev@kyter.com"
              let subject = "Simalytics App Feedback"
              let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
              let encodedBody = ""

              if let url = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "envelope.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.blue)
                  .frame(width: 28, height: 28)

                Text("Send Feedback")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.footnote)
                  .fontWeight(.semibold)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }
          }

          Section(header: Text("Data Providers")) {
            Button(action: {
              if let url = URL(
                string: "https://simkl.com/about/policies/privacy/")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "lock.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.indigo)
                  .frame(width: 28, height: 28)

                Text("Simkl Privacy Policy")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }
            Button(action: {
              if let url = URL(
                string: "https://simkl.com/about/policies/terms/")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "doc.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.teal)
                  .frame(width: 28, height: 28)

                Text("Simkl Terms of Service")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }
            Button(action: {
              if let url = URL(
                string: "https://www.themoviedb.org/terms-of-use?language=en-US")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "tv.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.green)
                  .frame(width: 28, height: 28)

                Text("TMDB Terms of Use")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }
          }

          Section(header: Text("Legal")) {
            Button(action: {
              if let url = URL(
                string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "doc.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.gray)
                  .frame(width: 28, height: 28)

                Text("End User License Agreement")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }

            Button(action: {
              if let url = URL(
                string: "https://kyter.com/simalytics/privacy.html")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "hand.raised.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.blue)
                  .frame(width: 28, height: 28)

                Text("Privacy Policy")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }

            Button(action: {
              if let url = URL(
                string: "https://kyter.com/simalytics/terms.html")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Image(systemName: "checkmark.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.mint)
                  .frame(width: 28, height: 28)

                Text("Terms & Conditions")
                  .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundStyle(Color(UIColor.tertiaryLabel))
              }
            }
          }

          Section(header: Text("About")) {
            NavigationLink(destination: AcknowledgementsView()) {
              HStack {
                Image(systemName: "heart.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.pink)
                  .frame(width: 28, height: 28)

                Text("Acknowledgements")
                  .foregroundStyle(.primary)
                Spacer()
              }
            }
          }

          if auth.hasAccount {
            Section {
              Button(role: .destructive) {
                showResetConfirmation = true
              } label: {
                Label {
                  Text("Reset & Sign Out")
                } icon: {
                  Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .frame(width: 28, height: 28)
                }
              }
              .disabled(globalLoadingIndicator.isSyncing)
              .confirmationDialog(
                "Reset local data and sign out?", isPresented: $showResetConfirmation,
                titleVisibility: .visible
              ) {
                Button("Reset & Sign Out", role: .destructive) { signOut() }
              } message: {
                Text(
                  "This removes downloaded library data from this device and signs you out. Your Simkl lists, ratings, and watch history stay on Simkl."
                )
              }

              Button(action: {
                if let url = URL(
                  string: "https://simkl.com/settings/login/clean-or-delete/")
                {
                  UIApplication.shared.open(url)
                }
              }) {
                HStack {
                  Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 28, height: 28)

                  Text("Delete Account")
                    .foregroundStyle(.red)
                  Spacer()
                  Image(systemName: "arrow.up.forward")
                    .font(.footnote)
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                }
              }
            } header: {
              Text("Data Management")
            } footer: {
              Text(
                "Resetting removes local library data and signs you out. Your Simkl account is kept."
              )
            }
          }

          Section {
          } footer: {
            HStack {
              Spacer()
              Text(
                "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
              )
              .font(.footnote)
              .foregroundStyle(.secondary)
              Spacer()
            }
            .padding(.vertical, 24)
          }
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if globalLoadingIndicator.isSyncing {
            ProgressView()
          }
        }
      }
    }
  }

  private func signInButton(_ title: String) -> some View {
    Button {
      signIn()
    } label: {
      if auth.isSigningIn {
        ProgressView()
          .accessibilityLabel("Waiting for Simkl")
      } else {
        Text(title)
      }
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .disabled(auth.isSigningIn)
  }

  private var signOutButton: some View {
    Button("Sign Out") {
      showSignOutConfirmation = true
    }
    .foregroundStyle(.red)
    .frame(maxWidth: .infinity, alignment: .center)
    .disabled(globalLoadingIndicator.isSyncing || auth.isSigningIn)
    .confirmationDialog(
      "Sign out of Simkl?", isPresented: $showSignOutConfirmation,
      titleVisibility: .visible
    ) {
      Button("Sign Out", role: .destructive) { signOut() }
    } message: {
      Text(
        "Downloaded library data will be removed from this device. Your Simkl lists, ratings, and watch history stay on Simkl."
      )
    }
  }
}

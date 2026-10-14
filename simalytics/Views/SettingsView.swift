//
//  SettingsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import AuthenticationServices
import Sentry
import SimpleKeychain
import SwiftData
import SwiftUI

struct SettingsView: View {
  @Environment(Auth.self) private var auth
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @AppStorage("blurEpisodeImages") private var blurImages = false
  @AppStorage("useFiveStarRating") private var useFiveStarRating = false
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage(AppTab.preferenceKey) private var defaultTab = AppTab.defaultLaunchTab
  @State private var showResetConfirmation = false
  @State private var showErrorAlert = false
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  @Environment(\.modelContext) private var modelContext

  func clearLocalSwiftData() {
    func clearAll<T: PersistentModel>(_ type: T.Type) {
      if let results = try? modelContext.fetch(FetchDescriptor<T>()) {
        for item in results {
          modelContext.delete(item)
        }
      }
    }

    clearAll(V1.SDLastSync.self)
    clearAll(V1.SDMovies.self)
    clearAll(V1.SDShows.self)
    clearAll(V1.SDAnimes.self)
    clearAll(V1.TrendingShows.self)
    clearAll(V1.TrendingMovies.self)
    clearAll(V1.TrendingAnimes.self)

    try? modelContext.save()
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

              Text("Simkl Status")
              Spacer()
              Text(auth.simklAccessToken.isEmpty ? "Not Connected" : "Connected")
                .foregroundStyle(.secondary)
              PulseCircle(active: !auth.simklAccessToken.isEmpty)
            }
            if auth.simklAccessToken.isEmpty {
              Button("Sign In") {
                Task {
                  do {
                    var oAuthURLComponents = URLComponents()
                    oAuthURLComponents.scheme = "https"
                    oAuthURLComponents.host = "simkl.com"
                    oAuthURLComponents.path = "/oauth/authorize"
                    oAuthURLComponents.queryItems = [
                      URLQueryItem(name: "response_type", value: "code"),
                      URLQueryItem(name: "redirect_uri", value: "simalytics://"),
                      URLQueryItem(
                        name: "client_id",
                        value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
                    ]

                    let tokenResponse: URL
                    do {
                      tokenResponse = try await webAuthenticationSession.authenticate(
                        using: oAuthURLComponents.url!,
                        callbackURLScheme: "simalytics"
                      )
                    } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
                      // User cancelled the sheet — not an error worth alerting on.
                      return
                    }

                    let queryItems = URLComponents(string: tokenResponse.absoluteString)?.queryItems
                    let token = queryItems?.filter({ $0.name == "code" }).first?.value ?? ""

                    if token.isEmpty {
                      SentrySDK.capture(message: "Simkl OAuth redirect missing code")
                      showErrorAlert = true
                      return
                    }

                    var accessTokenURLComponents = URLComponents()
                    accessTokenURLComponents.scheme = "https"
                    accessTokenURLComponents.host = "api.simalytics.kyter.com"
                    accessTokenURLComponents.path = "/oauth"

                    var request = URLRequest(url: accessTokenURLComponents.url!)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: String] = ["code": token]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (data, _) = try await performSimklRequest(request)

                    struct AccessTokenResponse: Decodable {
                      let access_token: String
                    }
                    let accessTokenResponse = try JSONDecoder().decode(
                      AccessTokenResponse.self, from: data)
                    let accessToken = accessTokenResponse.access_token
                    if accessToken.isEmpty {
                      showErrorAlert = true
                      return
                    }

                    let simpleKeychain = SimpleKeychain()
                    try simpleKeychain.set(accessToken, forKey: "simkl-access-token")
                    auth.simklAccessToken = accessToken  // Update UI immediately

                    // Run sync in a background task
                    Task {
                      globalLoadingIndicator.startSync()
                      await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
                      globalLoadingIndicator.stopSync()
                    }
                  } catch {
                    reportError(error)
                    showErrorAlert = true
                  }
                }
              }
              .frame(maxWidth: .infinity, alignment: .center)
            } else {
              Button("Sign Out") {
                Task {
                  do {
                    let simpleKeychain = SimpleKeychain()
                    try simpleKeychain.deleteItem(forKey: "simkl-access-token")
                    auth.simklAccessToken = ""
                    clearLocalSwiftData()
                  } catch {
                    reportError(error)
                  }
                }
              }
              .foregroundStyle(.red)
              .frame(maxWidth: .infinity, alignment: .center)
            }
          } header: {
            Text("Account")
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

          if !auth.simklAccessToken.isEmpty {
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
                Button("Reset & Sign Out", role: .destructive) {
                  do {
                    try SimpleKeychain().deleteItem(forKey: "simkl-access-token")
                    auth.simklAccessToken = ""
                    clearLocalSwiftData()
                  } catch {
                    reportError(error)
                  }
                }
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
        .alert("Error signing in with Simkl", isPresented: $showErrorAlert) {
          Button("OK", role: .cancel) {}
        } message: {
          Text("We've been alerted of the error. Please try again later.")
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
}

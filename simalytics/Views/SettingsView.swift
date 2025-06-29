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
  @EnvironmentObject private var auth: Auth
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @AppStorage("blurEpisodeImages") private var blurImages = false
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
    NavigationView {
      VStack {
        Form {
          Section {
            HStack {
              Text(auth.simklAccessToken.isEmpty ? "Not Connected" : "Connected")
              Spacer()
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

                    let tokenResponse = try await webAuthenticationSession.authenticate(
                      using: oAuthURLComponents.url!,
                      callbackURLScheme: "simalytics"
                    )

                    let queryItems = URLComponents(string: tokenResponse.absoluteString)?.queryItems
                    let token = queryItems?.filter({ $0.name == "code" }).first?.value ?? ""

                    if token.isEmpty {
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
                    let (data, response) = try await URLSession.shared.data(for: request)

                    guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200
                    else {
                      showErrorAlert = true
                      return
                    }

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
                    auth.simklAccessToken = accessToken // Update UI immediately

                    // Run sync in a background task
                    Task {
                        globalLoadingIndicator.startSync()
                        await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
                        globalLoadingIndicator.stopSync()
                    }
                  } catch {
                    showErrorAlert = true
                  }
                }
              }
              .frame(maxWidth: .infinity, alignment: .center)
            } else {
              Button("Sign Out") {
                Task {
                  let simpleKeychain = SimpleKeychain()
                  try simpleKeychain.deleteItem(forKey: "simkl-access-token")
                  auth.simklAccessToken = ""
                  clearLocalSwiftData()
                }
              }
              .foregroundColor(.red)
              .frame(maxWidth: .infinity, alignment: .center)
            }
          } header: {
            Text("Simkl Connection")
          }

          Section {
            HStack {
              Text("Blur Episode Images")
              Spacer()
              Toggle("", isOn: $blurImages)
            }
          } header: {
            Text("Show Settings")
          }

          Section(header: Text("Ratings & Feedback")) {
            Button(action: {
              UIApplication.shared.open(URL(string: "https://github.com/Kyter-com/simalytics-ios/")!)
            }) {
              HStack {
                Text("GitHub")
                Spacer()
                Image("GitHub")
                  .imageScale(.large)
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
                Text("Send Feedback")
                Spacer()
                Image(systemName: "envelope")
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
                Text("Simkl Privacy Policy")
                Spacer()
                Image(systemName: "arrow.up.right")
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
                Text("Simkl Terms of Service")
                Spacer()
                Image(systemName: "arrow.up.right")
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
                Text("TMDB Terms of Use")
                Spacer()
                Image(systemName: "arrow.up.right")
              }
            }
          }

          Section(header: Text("Privacy & Legal")) {
            Button(action: {
              if let url = URL(
                string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Text("End User License Agreement")
                Spacer()
                Image(systemName: "arrow.up.right")
              }
            }

            Button(action: {
              if let url = URL(
                string: "https://kyter.com/simalytics/privacy/")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Text("Privacy Policy")
                Spacer()
                Image(systemName: "arrow.up.right")
              }
            }

            Button(action: {
              if let url = URL(
                string: "https://kyter.com/simalytics/terms/")
              {
                UIApplication.shared.open(url)
              }
            }) {
              HStack {
                Text("Terms & Conditions")
                Spacer()
                Image(systemName: "arrow.up.right")
              }
            }
          }

          if !auth.simklAccessToken.isEmpty {
            Section(header: Text("Account Settings")) {
              Button(action: {
                Task {
                  let simpleKeychain = SimpleKeychain()
                  try simpleKeychain.deleteItem(forKey: "simkl-access-token")
                  auth.simklAccessToken = ""
                  clearLocalSwiftData()
                }
              }) {
                HStack {
                  Text("Clear Locally Stored Data")
                  Spacer()
                  Image(systemName: "arrow.up.trash")
                }
                .foregroundColor(.red)
              }

              Button(action: {
                if let url = URL(
                  string: "https://simkl.com/settings/login/clean-or-delete/")
                {
                  UIApplication.shared.open(url)
                }
              }) {
                HStack {
                  Text("Delete Account")
                  Spacer()
                  Image(systemName: "arrow.up.right")
                }
                .foregroundColor(.red)
              }
            }
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

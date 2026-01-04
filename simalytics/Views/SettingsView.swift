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
  @AppStorage("useFiveStarRating") private var useFiveStarRating = false
  @AppStorage("hideAnime") private var hideAnime = false
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
              Image(systemName: "link.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 28, height: 28)

              Text("Simkl Status")
              Spacer()
              Text(auth.simklAccessToken.isEmpty ? "Not Connected" : "Connected")
                .foregroundColor(.secondary)
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
                    auth.simklAccessToken = accessToken  // Update UI immediately

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
            Text("Account")
          }

          Section {
            HStack {
              Image(systemName: "photo.circle.fill")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 28, height: 28)

              Text("Blur Episode Images")
              Spacer()
              Toggle("", isOn: $blurImages)
            }
            HStack {
              Image(systemName: "star.circle.fill")
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 28, height: 28)

              Text("Use 5-Star Ratings")
              Spacer()
              Toggle("", isOn: $useFiveStarRating)
            }
            HStack {
              Image(systemName: "eye.slash.circle.fill")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 28, height: 28)

              Text("Hide Anime")
              Spacer()
              Toggle("", isOn: $hideAnime)
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
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                  .foregroundColor(.blue)
                  .frame(width: 28, height: 28)

                Text("Send Feedback")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                  .font(.footnote)
                  .fontWeight(.semibold)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                  .foregroundColor(.indigo)
                  .frame(width: 28, height: 28)

                Text("Simkl Privacy Policy")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                  .foregroundColor(.teal)
                  .frame(width: 28, height: 28)

                Text("Simkl Terms of Service")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                  .foregroundColor(.green)
                  .frame(width: 28, height: 28)

                Text("TMDB Terms of Use")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                  .foregroundColor(.gray)
                  .frame(width: 28, height: 28)

                Text("End User License Agreement")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                Image(systemName: "hand.raised.circle.fill")
                  .font(.title2)
                  .foregroundColor(.blue)
                  .frame(width: 28, height: 28)

                Text("Privacy Policy")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
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
                Image(systemName: "checkmark.circle.fill")
                  .font(.title2)
                  .foregroundColor(.mint)
                  .frame(width: 28, height: 28)

                Text("Terms & Conditions")
                  .foregroundColor(.primary)
                Spacer()
                Image(systemName: "arrow.up.forward")
                  .font(.footnote)
                  .foregroundColor(Color(UIColor.tertiaryLabel))
              }
            }
          }

          Section(header: Text("About")) {
            NavigationLink(destination: AcknowledgementsView()) {
              HStack {
                Image(systemName: "heart.circle.fill")
                  .font(.title2)
                  .foregroundColor(.pink)
                  .frame(width: 28, height: 28)

                Text("Acknowledgements")
                  .foregroundColor(.primary)
                Spacer()
              }
            }
          }

          if !auth.simklAccessToken.isEmpty {
            Section(header: Text("Data Management")) {
              Button(action: {
                Task {
                  let simpleKeychain = SimpleKeychain()
                  try simpleKeychain.deleteItem(forKey: "simkl-access-token")
                  auth.simklAccessToken = ""
                  clearLocalSwiftData()
                }
              }) {
                HStack {
                  Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)

                  Text("Clear Locally Stored Data")
                    .foregroundColor(.red)
                  Spacer()
                }
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
                    .foregroundColor(.red)
                    .frame(width: 28, height: 28)

                  Text("Delete Account")
                    .foregroundColor(.red)
                  Spacer()
                  Image(systemName: "arrow.up.forward")
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                }
              }
            }
          }

          Section {
          } footer: {
            HStack {
              Spacer()
              Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.footnote)
                .foregroundColor(.secondary)
              Spacer()
            }
            .padding(.top, 8)
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

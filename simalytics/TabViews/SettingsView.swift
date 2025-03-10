//
//  SettingsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import AuthenticationServices
import Sentry
import SimpleKeychain
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var showErrorAlert = false
  @State private var loadingAccessToken: Bool = false
  @State private var isAnimating = false

  var body: some View {
    NavigationView {
      VStack {
        Form {
          Section {
            HStack {
              Text(auth.simklAccessToken.isEmpty ? "Not Connected" : "Connected")
              Spacer()
              ZStack {
                Circle()
                  .fill(auth.simklAccessToken == "" ? Color.red : Color.green)
                  .frame(width: 10, height: 10)
                Circle()
                  .fill(
                    auth.simklAccessToken == "" ? Color.red.opacity(0.5) : Color.green.opacity(0.5)
                  )
                  .frame(width: 10, height: 10)
                  .scaleEffect(isAnimating ? 2.5 : 1.0)
                  .opacity(isAnimating ? 0.0 : 0.6)
                  .animation(
                    Animation.easeInOut(duration: 1.5)
                      .repeatForever(autoreverses: false),
                    value: isAnimating
                  )
              }
              .onAppear {
                isAnimating = true
              }
              .onDisappear {
                isAnimating = false
              }
            }
            if auth.simklAccessToken.isEmpty {
              Button("Sign In") {
                Task {
                  do {
                    loadingAccessToken = true

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
                    auth.simklAccessToken = accessToken

                    loadingAccessToken = false
                  } catch {
                    loadingAccessToken = false
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
                }
              }
              .foregroundColor(.red)
              .frame(maxWidth: .infinity, alignment: .center)
            }
          } header: {
            Text("Simkl Connection")
          }
        }
        .alert("Error signing in with Simkl", isPresented: $showErrorAlert) {
          Button("OK", role: .cancel) {}
        } message: {
          Text("We've been alerted of the error. Please try again later.")
        }
      }
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  SettingsView()
}

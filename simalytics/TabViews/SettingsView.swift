//
//  SettingsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import AuthenticationServices
import SimpleKeychain
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var showErrorAlert = false
  @State private var loadingAccessToken: Bool = false

  var body: some View {
    NavigationView {
      VStack {
        Text(auth.simklAccessToken)
        Text("Settings View!")
        Button("Sign Out") {
          Task {
            let simpleKeychain = SimpleKeychain()
            try simpleKeychain.deleteItem(forKey: "simkl-access-token")
            auth.simklAccessToken = ""
          }
        }
        Button("Sign In") {
          Task {
            do {
              loadingAccessToken = true

              var OAuthURLComponents = URLComponents()
              OAuthURLComponents.scheme = "https"
              OAuthURLComponents.host = "simkl.com"
              OAuthURLComponents.path = "/oauth/authorize"
              OAuthURLComponents.queryItems = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "redirect_uri", value: "simalytics://"),
                URLQueryItem(
                  name: "client_id",
                  value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
              ]

              let tokenResponse = try await webAuthenticationSession.authenticate(
                using: OAuthURLComponents.url!,
                callbackURLScheme: "simalytics"
              )

              let queryItems = URLComponents(string: tokenResponse.absoluteString)?.queryItems
              let token = queryItems?.filter({ $0.name == "code" }).first?.value ?? ""

              if token.isEmpty {
                showErrorAlert = true
                return
              }

              struct AccessTokenResponse: Decodable {
                let access_token: String
              }
              var AccessTokenURLComponents = URLComponents()
              AccessTokenURLComponents.scheme = "https"
              AccessTokenURLComponents.host = "api.simalytics.kyter.com"
              AccessTokenURLComponents.path = "/oauth"

              var request = URLRequest(url: AccessTokenURLComponents.url!)
              request.httpMethod = "POST"
              request.setValue("application/json", forHTTPHeaderField: "Content-Type")
              let body: [String: String] = ["code": token]
              request.httpBody = try JSONSerialization.data(withJSONObject: body)
              let (data, response) = try await URLSession.shared.data(for: request)

              guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
              else {
                showErrorAlert = true
                return
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

              // TODO: Loading indicator during the access token request
              // TODO: Save token to global state
            } catch {
              loadingAccessToken = false
              showErrorAlert = true
            }
          }
        }
        .alert("Error signing in with Simkl", isPresented: $showErrorAlert) {
          Button("OK", role: .cancel) {}
          // TODO: Save to Sentry
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

//
//  SettingsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import AuthenticationServices
import SwiftUI

struct SettingsView: View {
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @State private var showErrorAlert = false

  var body: some View {
    NavigationView {
      VStack {
        Text("Settings View!")
        Button("Sign In") {
          Task {
            do {
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
              }

              print("Token: \(token)")
              // TODO: Save token to Keychain or something similar
            } catch {
              showErrorAlert = true
            }
          }
        }
        .alert("Error signing in with Simkl", isPresented: $showErrorAlert) {
          Button("OK", role: .cancel) {}
        }
      }
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  SettingsView()
}

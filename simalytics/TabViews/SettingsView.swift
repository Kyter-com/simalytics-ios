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

  var body: some View {
    NavigationView {
      VStack {
        Text("Settings View!")
        Button("Sign In") {
          Task {
            do {
              let oauthURL = URL(
                string:
                  "https://simkl.com/oauth/authorize?client_id=c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9&response_type=code&redirect_uri=simalytics://"
              )!
              let urlWithToken = try await webAuthenticationSession.authenticate(
                using: oauthURL,
                callbackURLScheme: "simalytics"
              )
              print("URL with token: \(urlWithToken)")
            } catch {
              print("Error: \(error)")
            }
          }
        }
      }
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  SettingsView()
}

//
//  SettingsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct SettingsView: View {
  var body: some View {
    NavigationView {
      VStack {
        Text("Settings View!")
        Button(action: {

        }) {
          Text("Login to Simkl")
        }
      }
      .navigationTitle("Settings")
    }
  }
}

#Preview {
  SettingsView()
}

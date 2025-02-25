//
//  simalyticsApp.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//
// swift-format ./Documents/GitHub/simalytics-ios/ -i -r && swift-format lint ./Documents/GitHub/simalytics-ios/ -r

import SimpleKeychain
import SwiftUI

class Auth: ObservableObject {
  @Published var simklAccessToken: String
  init() {
    let simpleKeychain = SimpleKeychain()
    do {
      let accessToken = try simpleKeychain.string(forKey: "simkl-access-token")
      self.simklAccessToken = accessToken
    } catch {
      self.simklAccessToken = ""
    }
  }
}

@main
struct SimalyticsApp: App {
  @StateObject private var auth = Auth()

  var body: some Scene {
    WindowGroup {
      MainView()
        .environmentObject(auth)
    }
  }
}

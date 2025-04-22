//
//  simalyticsApp.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//
// swift-format ./Documents/GitHub/simalytics-ios/ -i -r && swift-format lint ./Documents/GitHub/simalytics-ios/ -r

import Sentry
import SimpleKeychain
import SwiftData
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
  @State private var globalLoadingIndicator = GlobalLoadingIndicator()

  let modelContainer: ModelContainer = {
    do {
      let schema = Schema([V1.SDLastSync.self, V1.SDMovies.self, V1.SDShows.self, V1.SDAnimes.self])
      let configuration = ModelConfiguration(schema: schema)
      return try ModelContainer(for: schema, configurations: configuration)
    } catch {
      fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
    }
  }()

  init() {
    SentrySDK.start { options in
      options.dsn =
        "https://2f19a4a9e212e5ee432f16fa2e22780d@o507828.ingest.us.sentry.io/4508956076605440"
    }
  }

  var body: some Scene {
    WindowGroup {
      IndexView()
        .environmentObject(auth)
        .environment(globalLoadingIndicator)
        .modelContainer(modelContainer)
        .task {
          if !auth.simklAccessToken.isEmpty {
            globalLoadingIndicator.startSync()
            await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContainer)
            globalLoadingIndicator.stopSync()
          }
        }
    }
  }
}

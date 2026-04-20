//
//  simalyticsApp.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//
// swift-format lint ./Documents/GitHub/simalytics-ios/ -r

import Sentry
import SimpleKeychain
import SwiftData
import SwiftUI

@Observable @MainActor
class Auth {
  var simklAccessToken: String
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
  @State private var auth = Auth()
  @State private var globalLoadingIndicator = GlobalLoadingIndicator()
  private static let sentryFallbackDSN = "https://94a93419c81edfd551d0956b8cf216c9@o1393466.ingest.us.sentry.io/4511253519466496"

  private static var sentryReleaseName: String? {
    guard let infoDictionary = Bundle.main.infoDictionary,
      let version = infoDictionary["CFBundleShortVersionString"] as? String,
      let build = infoDictionary["CFBundleVersion"] as? String
    else {
      return nil
    }

    return "simalytics-ios@\(version)+\(build)"
  }

  let modelContainer: ModelContainer = {
    do {
      let schema = Schema([
        V1.SDLastSync.self, V1.SDMovies.self, V1.SDShows.self, V1.SDAnimes.self,
        V1.TrendingMovies.self, V1.TrendingShows.self,
        V1.TrendingAnimes.self,
      ])
      let configuration = ModelConfiguration(schema: schema)
      return try ModelContainer(
        for: schema,
        migrationPlan: SimalyticsMigrationPlan.self,
        configurations: configuration
      )
    } catch {
      fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
    }
  }()

  init() {
    SentrySDK.start { options in
      if let configuredDSN = (Bundle.main.infoDictionary?["SENTRY_DSN"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !configuredDSN.isEmpty
      {
        options.dsn = configuredDSN
      } else {
        options.dsn = Self.sentryFallbackDSN
        print("warning: Missing SENTRY_DSN in Info.plist. Using fallback DSN.")
      }

      if let environment = (Bundle.main.infoDictionary?["SENTRY_ENVIRONMENT"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !environment.isEmpty
      {
        options.environment = environment
      }

      options.releaseName = Self.sentryReleaseName
      options.tracesSampleRate = 0.1
      options.enableMetricKit = true
      options.beforeSend = { event in
        guard let request = event.request else {
          return event
        }

        if var headers = request.headers {
          for key in headers.keys {
            let normalizedKey = key.lowercased()
            if normalizedKey == "authorization"
              || normalizedKey.contains("token")
              || normalizedKey.contains("cookie")
            {
              headers[key] = "[REDACTED]"
            }
          }
          request.headers = headers
        }

        return event
      }
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(auth)
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

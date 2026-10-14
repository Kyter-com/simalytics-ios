//
//  simalyticsApp.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//
// swift-format lint ./Documents/GitHub/simalytics-ios/ -r

import Kingfisher
import Sentry
import SimpleKeychain
import SwiftData
import SwiftUI

@Observable @MainActor
class Auth {
  var simklAccessToken: String
  init() {
    let simpleKeychain = SimpleKeychain()
    #if DEBUG
      // App Store screenshot harness (marketing/app-store-screenshots): a sentinel
      // token opens the Explore / Up Next gates so the seeded public-domain
      // fixtures render. It is never sent to the network (sync is disabled in this
      // mode) and never written to the keychain. See ScreenshotMode.
      if ScreenshotMode.isActive {
        self.simklAccessToken = ScreenshotMode.sentinelToken
        return
      }
    #endif
    do {
      let accessToken = try simpleKeychain.string(forKey: "simkl-access-token")
      self.simklAccessToken = accessToken
    } catch {
      self.simklAccessToken = ""
    }
    SyncAccount.update(simklAccessToken)
  }

  /// Change accounts here so background syncs stop writing for a signed-out one.
  func setAccessToken(_ accessToken: String) {
    simklAccessToken = accessToken
    SyncAccount.update(accessToken)
  }
}

@main
struct SimalyticsApp: App {
  @State private var auth = Auth()
  @State private var globalLoadingIndicator = GlobalLoadingIndicator()
  private static let sentryFallbackDSN = "https://94a93419c81edfd551d0956b8cf216c9@o1393466.ingest.us.sentry.io/4511253519466496"

  // Cap the Kingfisher disk cache so it LRU-evicts instead of growing without bound.
  private static let imageDiskCacheSizeLimit: UInt = 500 * 1024 * 1024
  private static let urlMemoryCacheSizeLimit = 20 * 1024 * 1024

  private static var sentryReleaseName: String? {
    guard let infoDictionary = Bundle.main.infoDictionary,
      let version = infoDictionary["CFBundleShortVersionString"] as? String,
      let build = infoDictionary["CFBundleVersion"] as? String
    else {
      return nil
    }

    return "simalytics-ios@\(version)+\(build)"
  }

  @State private var store = AppStoreController()

  init() {
    #if DEBUG
      // Screenshot harness: force grid layout + route posters through local PD JPEGs.
      ScreenshotMode.setUp()
    #endif
    URLCache.shared = URLCache(
      memoryCapacity: Self.urlMemoryCacheSizeLimit,
      diskCapacity: 0
    )
    ImageCache.default.diskStorage.config.sizeLimit = Self.imageDiskCacheSizeLimit

    let telemetry = TelemetryConfiguration.current
    guard telemetry.isEnabled else { return }

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

      options.environment = telemetry.environment
      options.releaseName = Self.sentryReleaseName
      options.tracesSampleRate = 0.1
      options.tracePropagationTargets = ["api.simalytics.kyter.com"]
      options.failedRequestTargets = ["api.simalytics.kyter.com"]
      options.enableMetricKit = true
      // Sentry can process events off the main actor. This callback only
      // mutates its event; it must not inherit the app initializer's isolation.
      options.beforeSend = { @Sendable event in
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
      Group {
        if let modelContainer = store.container {
          ContentView()
            .environment(auth)
            .environment(globalLoadingIndicator)
            .modelContainer(modelContainer)
            .task {
              if !auth.simklAccessToken.isEmpty {
                refreshUpNextOnceAfterUpdate(modelContainer: modelContainer)
                globalLoadingIndicator.startSync()
                await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContainer)
                globalLoadingIndicator.stopSync()
              }
            }
        } else if let failure = store.failure {
          StorageRecoveryView(
            failure: failure, retry: { await store.load() }, reset: { await store.resetAndLoad() })
        } else {
          ProgressView("Opening your library…")
        }
      }
      .task { await store.load() }
    }
  }
}

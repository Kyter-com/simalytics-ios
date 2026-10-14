import Foundation

/// Keep automated fixtures out of Sentry and local runs out of production metrics.
struct TelemetryConfiguration: Sendable {
  let isEnabled: Bool
  let environment: String

  static let current: Self = {
    #if DEBUG
      let isDebugBuild = true
    #else
      let isDebugBuild = false
    #endif
    #if targetEnvironment(simulator)
      let isSimulator = true
    #else
      let isSimulator = false
    #endif
    return Self(
      processEnvironment: ProcessInfo.processInfo.environment,
      configuredEnvironment: Bundle.main.infoDictionary?["SENTRY_ENVIRONMENT"] as? String,
      isDebugBuild: isDebugBuild,
      isSimulator: isSimulator
    )
  }()

  init(
    processEnvironment: [String: String],
    configuredEnvironment: String?,
    isDebugBuild: Bool,
    isSimulator: Bool
  ) {
    // Xcode uses these for both XCTest and hosted Swift Testing runs. Check
    // presence, including an empty value, before starting any SDK integrations.
    let isTesting = [
      "XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier",
    ].contains { processEnvironment[$0] != nil }
    let isPreview = processEnvironment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    let isScreenshot = isDebugBuild && processEnvironment["SIMALYTICS_SCREENSHOTS"] == "1"
    isEnabled = !isTesting && !isPreview && !isScreenshot

    // Custom INFOPLIST_KEY settings are not always emitted into a generated
    // Info.plist. Never let the SDK's production default label a local build.
    if isSimulator {
      environment = "simulator"
    } else if isDebugBuild {
      environment = "debug"
    } else if let configured = configuredEnvironment?.trimmingCharacters(
      in: .whitespacesAndNewlines),
      !configured.isEmpty
    {
      environment = configured
    } else {
      environment = "production"
    }
  }
}

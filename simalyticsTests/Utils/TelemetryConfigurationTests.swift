import Sentry
import Testing

@testable import Simalytics

struct TelemetryConfigurationTests {
  @Test("Hosted tests never initialize Sentry")
  func testHostHasNoTelemetry() {
    #expect(TelemetryConfiguration.current.isEnabled == false)
    #expect(SentrySDK.isEnabled == false)
  }

  @Test(
    "Automated test markers disable telemetry in any build",
    arguments: ["XCTestConfigurationFilePath", "XCTestBundlePath", "XCTestSessionIdentifier"],
    [false, true]
  )
  func testMarkersDisableTelemetry(marker: String, isDebug: Bool) {
    let configuration = TelemetryConfiguration(
      processEnvironment: [marker: ""], configuredEnvironment: "production",
      isDebugBuild: isDebug, isSimulator: false)
    #expect(configuration.isEnabled == false)
  }

  @Test("Previews and screenshot fixtures do not send telemetry", arguments: [false, true])
  func offlineToolsDisableTelemetry(isPreview: Bool) {
    let configuration = TelemetryConfiguration(
      processEnvironment: [
        isPreview ? "XCODE_RUNNING_FOR_PREVIEWS" : "SIMALYTICS_SCREENSHOTS": "1"
      ],
      configuredEnvironment: nil, isDebugBuild: true, isSimulator: true)
    #expect(configuration.isEnabled == false)
  }

  @Test("The debug-only screenshot flag cannot disable release telemetry")
  func screenshotFlagDoesNotAffectRelease() {
    let configuration = TelemetryConfiguration(
      processEnvironment: ["SIMALYTICS_SCREENSHOTS": "1"], configuredEnvironment: nil,
      isDebugBuild: false, isSimulator: false)
    #expect(configuration.isEnabled)
    #expect(configuration.environment == "production")
  }

  @Test("Local builds stay observable outside production", arguments: [false, true])
  func simulatorBuildsHaveTheirOwnEnvironment(isDebug: Bool) {
    let configuration = TelemetryConfiguration(
      processEnvironment: [:], configuredEnvironment: "production",
      isDebugBuild: isDebug, isSimulator: true)
    #expect(configuration.isEnabled)
    #expect(configuration.environment == "simulator")
  }

  @Test("Debug device builds do not inherit production")
  func debugDeviceEnvironment() {
    let configuration = TelemetryConfiguration(
      processEnvironment: [:], configuredEnvironment: "production",
      isDebugBuild: true, isSimulator: false)
    #expect(configuration.isEnabled)
    #expect(configuration.environment == "debug")
  }

  @Test("Device releases have a production fallback", arguments: [nil, "", " \n"] as [String?])
  func releaseEnvironmentFallback(configured: String?) {
    let configuration = TelemetryConfiguration(
      processEnvironment: [:], configuredEnvironment: configured,
      isDebugBuild: false, isSimulator: false)
    #expect(configuration.isEnabled)
    #expect(configuration.environment == "production")
  }

  @Test("Device releases honor an explicit deployment environment")
  func explicitReleaseEnvironment() {
    let configuration = TelemetryConfiguration(
      processEnvironment: [:], configuredEnvironment: " beta \n",
      isDebugBuild: false, isSimulator: false)
    #expect(configuration.isEnabled)
    #expect(configuration.environment == "beta")
  }
}

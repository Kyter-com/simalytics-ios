import Foundation
import Testing

@testable import Simalytics

struct AppTabTests {
  @Test("Every launch preference survives a new read", arguments: AppTab.allCases)
  func persistedPreference(tab: AppTab) throws {
    let name = "AppTabTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(tab.rawValue, forKey: AppTab.preferenceKey)
    #expect(AppTab.launchTab(defaults: defaults) == tab)
    #expect(AppTab.launchTab(defaults: defaults, override: "settings") == .settings)
    #expect(AppTab.launchTab(defaults: defaults) == tab)
  }

  @Test("New installs and invalid preferences default to Up Next")
  func fallback() throws {
    let name = "AppTabTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(AppTab.launchTab(defaults: defaults) == .upNext)
    defaults.set("removed-tab", forKey: AppTab.preferenceKey)
    #expect(AppTab.launchTab(defaults: defaults, override: "invalid") == .upNext)
  }
}

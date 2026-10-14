import Foundation

/// Case order is the Default Tab picker order; raw values are persisted.
enum AppTab: String, CaseIterable, Identifiable {
  case lists
  case upNext = "upnext"
  case explore
  case settings

  static let preferenceKey = "defaultTab"
  /// Matches the App Store releases before the launch-tab preference existed.
  static let defaultLaunchTab: AppTab = .lists
  var id: String { rawValue }

  var title: String {
    switch self {
    case .upNext: "Up Next"
    case .lists: "Lists"
    case .explore: "Explore"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .upNext: "play.tv"
    case .lists: "list.bullet.indent"
    case .explore: "magnifyingglass"
    case .settings: "gearshape"
    }
  }

  var subtitle: String {
    switch self {
    case .upNext: "Pick up where you left off."
    case .lists: "Your movies, shows, and anime."
    case .explore: "Find your next favorite."
    case .settings: "Your account and preferences."
    }
  }

  static func launchTab(defaults: UserDefaults = .standard, override: String? = nil) -> AppTab {
    if let override, let tab = AppTab(rawValue: override) { return tab }
    return defaults.string(forKey: preferenceKey).flatMap(AppTab.init(rawValue:)) ?? defaultLaunchTab
  }
}

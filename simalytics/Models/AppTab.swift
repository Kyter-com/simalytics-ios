import Foundation

/// Case order is the tab bar order; raw values are persisted.
enum AppTab: String, CaseIterable, Identifiable {
  case lists
  case upNext = "upnext"
  case explore
  case search
  case settings

  static let preferenceKey = "defaultTab"
  /// Matches the App Store releases before the launch-tab preference existed.
  static let defaultLaunchTab: AppTab = .lists
  /// The Default Tab choices. Search is left out: it opens straight into the
  /// keyboard, which is a jarring way to start the app.
  static let launchOptions: [AppTab] = [.lists, .upNext, .explore, .settings]
  var id: String { rawValue }

  var title: String {
    switch self {
    case .upNext: "Up Next"
    case .lists: "Lists"
    case .explore: "Explore"
    case .search: "Search"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .upNext: "play.tv"
    case .lists: "list.bullet.indent"
    case .explore: "binoculars"
    case .search: "magnifyingglass"
    case .settings: "gearshape"
    }
  }

  var subtitle: String {
    switch self {
    case .upNext: "Pick up where you left off."
    case .lists: "Your movies, shows, and anime."
    case .explore: "Find your next favorite."
    case .search: "Look up any title."
    case .settings: "Your account and preferences."
    }
  }

  static func launchTab(defaults: UserDefaults = .standard, override: String? = nil) -> AppTab {
    if let override, let tab = AppTab(rawValue: override) { return tab }
    return defaults.string(forKey: preferenceKey).flatMap(AppTab.init(rawValue:))
      .flatMap { launchOptions.contains($0) ? $0 : nil } ?? defaultLaunchTab
  }
}

//
//  ContentView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct ContentView: View {
  @State private var selectedTab: AppTab = ContentView.initialTab
  @State private var exploreSearchFocusTrigger = 0

  /// Which tab to open on launch. Release builds always start on Lists; DEBUG
  /// builds honor `SIMALYTICS_SCREENSHOT_TAB` so the App Store screenshot
  /// harness (marketing/app-store-screenshots) can launch straight into a tab.
  private static var initialTab: AppTab {
    #if DEBUG
      switch ProcessInfo.processInfo.environment["SIMALYTICS_SCREENSHOT_TAB"] {
      case "explore": return .explore
      case "upnext": return .upNext
      case "settings": return .settings
      case "lists": return .lists
      default: break
      }
    #endif
    return .lists
  }

  /// The Lists tab's content. Release builds always show the Lists hub; DEBUG
  /// screenshot mode can route to a sub-screen (e.g. the Movies poster-wall grid)
  /// so the harness can capture it with the tab bar intact.
  @ViewBuilder private var listsTab: some View {
    #if DEBUG
      switch ScreenshotMode.screen {
      case "movies-grid": NavigationStack { MovieListView(status: "completed") }
      case "tv-grid": NavigationStack { TVListView(status: "watching") }
      case "movie-detail":
        NavigationStack { MovieDetailView(simkl_id: ScreenshotDetailFixtures.featuredMovieID) }
      default: ListView()
      }
    #else
      ListView()
    #endif
  }

  private var tabSelection: Binding<AppTab> {
    Binding {
      selectedTab
    } set: { newTab in
      if selectedTab == .explore && newTab == .explore {
        exploreSearchFocusTrigger += 1
      }
      selectedTab = newTab
    }
  }

  var body: some View {
    TabView(selection: tabSelection) {
      listsTab
        .tabItem {
          Label("Lists", systemImage: "list.bullet.indent")
        }
        .tag(AppTab.lists)
      ExploreView(searchFocusTrigger: exploreSearchFocusTrigger)
        .tabItem {
          Label("Explore", systemImage: "magnifyingglass")
        }
        .tag(AppTab.explore)
      UpNextView()
        .tabItem {
          Label("Up Next", systemImage: "play.tv")
        }
        .tag(AppTab.upNext)
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .tag(AppTab.settings)
    }
    .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
  }

  private enum AppTab: Hashable {
    case lists
    case explore
    case upNext
    case settings
  }
}

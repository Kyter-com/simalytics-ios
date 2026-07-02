//
//  ContentView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct ContentView: View {
  @State private var selectedTab: AppTab = .lists
  @State private var exploreSearchFocusTrigger = 0

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
      ListView()
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

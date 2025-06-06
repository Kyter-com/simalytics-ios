//
//  ContentView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct ContentView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      ListView()
        .tabItem {
          Label("Lists", systemImage: "list.bullet.indent")
        }
        .tag(0)
      ExploreView()
        .tabItem {
          Label("Explore", systemImage: "magnifyingglass")
        }
        .tag(1)
      UpNextView()
        .tabItem {
          Label("Up Next", systemImage: "play.tv")
        }
        .tag(2)
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape")
        }
        .tag(3)
    }
    .onChange(of: selectedTab) {
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.impactOccurred()
    }
  }
}

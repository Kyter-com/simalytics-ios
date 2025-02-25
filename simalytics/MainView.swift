//
//  MainView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct MainView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tabItem {
          Label("Home", systemImage: "play.house.fill")
        }
        .tag(0)
      ExploreView()
        .tabItem {
          Label("Explore", systemImage: "magnifyingglass")
        }
        .tag(1)
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape.fill")
        }
        .tag(2)
    }
    .onChange(of: selectedTab) {
      let generator = UIImpactFeedbackGenerator(style: .light)
      generator.impactOccurred()
    }
  }
}

#Preview {
  MainView()
}

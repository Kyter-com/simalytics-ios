//
//  MainView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct MainView: View {
  var body: some View {
    TabView {
      HomeView()
        .tabItem {
          Label("Home", systemImage: "play.house.fill")
        }
      ExploreView()
        .tabItem {
          Label("Explore", systemImage: "magnifyingglass")
        }
      SettingsView()
        .tabItem {
          Label("Settings", systemImage: "gearshape.fill")
        }

    }
  }
}

#Preview {
  MainView()
}

//
//  MainView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

extension Binding {
  func onUpdate(_ closure: @escaping (Value) -> Void) -> Binding<Value> {
    Binding(
      get: {
        self.wrappedValue
      },
      set: { newValue in
        self.wrappedValue = newValue
        closure(newValue)
      }
    )
  }
}

struct MainView: View {
  @State private var selectedTab = 0
  @State private var lastSelectedTab = 0

  var body: some View {
    TabView(
      selection: $selectedTab.onUpdate { newValue in
        if newValue == lastSelectedTab && newValue == 1 {
          print("search tapped twice")
        }
        lastSelectedTab = newValue
      }
    ) {
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

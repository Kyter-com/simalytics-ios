//
//  HomeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var auth: Auth

  var body: some View {
    NavigationView {
      Text("Home View!")
        .navigationTitle("Home")
    }
  }
}

#Preview {
  HomeView()
}

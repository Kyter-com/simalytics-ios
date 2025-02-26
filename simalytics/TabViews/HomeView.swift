//
//  HomeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var auth: Auth
  @State private var shows: [Int] = []

  var body: some View {
    NavigationView {
      VStack {
        Text("Home View!")
        List(shows, id: \.self) { show in
          Text("show \(show)")
        }
      }
      .task {
        do {
          if !auth.simklAccessToken.isEmpty {
            var UpNextURLComponents = URLComponents()
            UpNextURLComponents.scheme = "https"
            UpNextURLComponents.host = "api.simkl.com"
            UpNextURLComponents.path = "/sync/all-items/shows/watching"
            UpNextURLComponents.queryItems = [
              URLQueryItem(name: "episode_watched_at", value: "yes"),
              URLQueryItem(name: "memos", value: "yes"),
              URLQueryItem(name: "next_watch_info", value: "yes"),
            ]
            var request = URLRequest(url: UpNextURLComponents.url!)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(
              "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9",
              forHTTPHeaderField: "simkl-api-key")
            request.setValue(auth.simklAccessToken, forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
              shows = []
            }
          } else {
            shows = []
          }
        } catch {
          shows = []
        }
      }
      .navigationTitle("Home")
    }
  }
}

#Preview {
  HomeView()
}

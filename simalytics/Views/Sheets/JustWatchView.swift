//
//  JustWatchView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/27/25.
//

import Sentry
import SwiftUI

struct JustWatchView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(Auth.self) private var auth
  @State private var justWatchListings: JustWatchListings?
  @State private var isLoading = false
  var tmdbId: String?
  var mediaType: String

  private var listingURL: URL? {
    guard let link = justWatchListings?.link else { return nil }
    return URL(string: link)
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if isLoading {
          VStack {
            Spacer()
            ProgressView("Loading listings...")
              .padding()
            Spacer()
          }
        } else if justWatchListings == nil
          || (justWatchListings?.free?.isEmpty ?? true && justWatchListings?.flatrate?.isEmpty ?? true && justWatchListings?.buy?.isEmpty ?? true)
        {
          ContentUnavailableView("No streaming options available", systemImage: "sparkles.tv")
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              JustWatchProviderSection(
                title: "Watch Free",
                options: justWatchListings?.free ?? [],
                listingURL: listingURL
              )
              JustWatchProviderSection(
                title: "Watch with Ads",
                options: justWatchListings?.ads ?? [],
                listingURL: listingURL
              )
              JustWatchProviderSection(
                title: "Stream",
                options: justWatchListings?.flatrate ?? [],
                listingURL: listingURL
              )
              JustWatchProviderSection(
                title: "Rent",
                options: justWatchListings?.rent ?? [],
                listingURL: listingURL
              )
              JustWatchProviderSection(
                title: "Buy",
                options: justWatchListings?.buy ?? [],
                listingURL: listingURL
              )
            }
            .padding(.top, 8)
          }
        }

        Spacer()

        HStack {
          Text("Data provided by")
            .font(.caption)
          Link(destination: URL(string: "https://www.justwatch.com/")!) {
            AsyncImage(url: URL(string: "https://www.justwatch.com/appassets/img/logo/JustWatch-logo-large.png")) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 50)
            } placeholder: {
              ProgressView()
                .frame(width: 100, height: 50)
            }
          }
          .accessibilityLabel("JustWatch")
        }
        .padding(.horizontal)
      }
      .navigationTitle("Where to Watch")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .bold()
        }
      }
      .task {
        isLoading = true
        justWatchListings = await getJustWatchListings(auth.simklAccessToken, tmdbId)
        isLoading = false
      }
    }
  }

  func getJustWatchListings(_ accessToken: String, _ tmdbId: String?) async -> JustWatchListings? {
    if tmdbId == nil { return nil }
    do {
      let url = URL(string: "https://api.simalytics.kyter.com/tmdb-proxy")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue(mediaType, forHTTPHeaderField: "x-type")
      request.setValue(tmdbId!, forHTTPHeaderField: "x-id")
      let (data, response) = try await URLSession.shared.simklData(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      let res = try JSONDecoder().decode(JustWatchModel.self, from: data)
      return res.results?.US
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }
}

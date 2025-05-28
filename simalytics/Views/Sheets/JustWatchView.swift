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
  @EnvironmentObject private var auth: Auth
  @State private var justWatchListings: JustWatchListings?
  @State private var isLoading = false
  var tmdbId: String?
  var mediaType: String

  var body: some View {
    NavigationStack {
      VStack {
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
          if let free = justWatchListings?.free, !free.isEmpty {
            Text("Watch Free")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(free, id: \.provider_id) { option in
                  Button(action: {
                    UIApplication.shared.open(URL(string: justWatchListings?.link ?? "")!)
                  }) {
                    VStack {
                      CustomKFImage(
                        imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                        memoryCacheOnly: true,
                        height: 50,
                        width: 50
                      )
                    }
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
              .padding([.leading, .trailing, .bottom])
            }
          }

          if let flatrate = justWatchListings?.flatrate, !flatrate.isEmpty {
            Text("Stream")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(flatrate, id: \.provider_id) { option in
                  Button(action: {
                    UIApplication.shared.open(URL(string: justWatchListings?.link ?? "")!)
                  }) {
                    VStack {
                      CustomKFImage(
                        imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                        memoryCacheOnly: true,
                        height: 50,
                        width: 50
                      )
                    }
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
              .padding([.leading, .trailing, .bottom])
            }
          }

          if let rent = justWatchListings?.rent, !rent.isEmpty {
            Text("Rent")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(rent, id: \.provider_id) { option in
                  Button(action: {
                    UIApplication.shared.open(URL(string: justWatchListings?.link ?? "")!)
                  }) {
                    VStack {
                      CustomKFImage(
                        imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                        memoryCacheOnly: true,
                        height: 50,
                        width: 50
                      )
                    }
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
              .padding([.leading, .trailing, .bottom])
            }
          }

          if let buy = justWatchListings?.buy, !buy.isEmpty {
            Text("Buy")
              .font(.headline)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                ForEach(buy, id: \.provider_id) { option in
                  Button(action: {
                    UIApplication.shared.open(URL(string: justWatchListings?.link ?? "")!)
                  }) {
                    VStack {
                      CustomKFImage(
                        imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                        memoryCacheOnly: true,
                        height: 50,
                        width: 50
                      )
                    }
                  }
                  .buttonStyle(PlainButtonStyle())
                }
              }
              .padding([.leading, .trailing, .bottom])
            }
          }
        }

        Spacer()

        HStack {
          Text("Data provided by")
            .font(.caption)
          Button(action: {
            UIApplication.shared.open(URL(string: "https://www.justwatch.com/")!)
          }) {
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
        }
      }
      .navigationTitle("Where to Watch")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
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
      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      let res = try JSONDecoder().decode(JustWatchModel.self, from: data)
      return res.results?.US
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }
}

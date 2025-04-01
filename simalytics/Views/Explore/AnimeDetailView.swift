//
//  AnimeDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

struct AnimeDetailView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @State private var animeWatchlist: AnimeWatchlistModel?
  @State private var animeDetails: AnimeDetailsModel?
  @State private var animeEpisodes: [AnimeEpisodeModel] = []
  @State private var filteredEpisodes: [AnimeEpisodeModel] = []
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  var simkl_id: Int

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .onAppear {
          Task {
            animeDetails = await AnimeDetailView.getAnimeDetails(simkl_id)
            animeWatchlist = await AnimeDetailView.getAnimeWatchlist(
              simkl_id, auth.simklAccessToken)
            watchlistStatus = animeWatchlist?.list
            animeEpisodes = await AnimeDetailView.getAnimeEpisodes(simkl_id)

            if let fanart = animeDetails?.fanart {
              let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
              KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
            }

            isLoading = false
          }
        }
    } else {
      ScrollView {
        ParallaxBackgroundImage(fanart: animeDetails?.fanart)

        HStack {
          if let poster = animeDetails?.poster {
            CustomKFImage(
              imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
              memoryCacheOnly: true,
              height: 220.59,
              width: 150
            )
            .overlay(
              RoundedRectangle(cornerRadius: 8).stroke(
                colorScheme == .dark ? Color.black : Color.white, lineWidth: 4)
            )
          }
          Spacer()
          VStack {
            Spacer()
              .frame(height: 8)
            Spacer()
            AnimeHeaderInfo(animeDetails: $animeDetails)
            Spacer()
            AnimeWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            Spacer()
              .frame(height: 2)
          }
        }
        .padding([.leading, .trailing])
        .offset(y: -10)
        .background(colorScheme == .dark ? Color.black : Color.white)

        if let title = animeDetails?.title {
          Text(title)
            .font(.title)
            .bold()
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing])
            .offset(y: -10)
        }

        if let genres = animeDetails?.genres {
          Text(genres.joined(separator: " • "))
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding([.leading, .trailing])
            .fontDesign(.monospaced)
        }

        if let overview = animeDetails?.overview {
          Text(overview.stripHTML)
            .font(.footnote)
            .padding([.leading, .trailing])
            .padding(.top, 8)
        }

        Spacer()

        Recommendations(recommendations: animeDetails?.users_recommendations ?? [])
      }
    }
  }
}

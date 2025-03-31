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
  @State private var animeDetails: AnimeDetailsModel?
  @State private var isLoading = true
  var simkl_id: Int

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .onAppear {
          Task {
            animeDetails = await AnimeDetailView.getAnimeDetails(simkl_id)

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
      }
    }
  }
}

//
//  MovieDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import SwiftUI

struct MovieDetailView: View {
  @EnvironmentObject private var auth: Auth
  @State private var movieDetails: MovieDetailsModel?
  @State private var movieWatchlist: MovieWatchlistModel?
  @State private var isLoading = true
  var simkl_id: Int

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .onAppear {
          Task {
            movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
            movieWatchlist = await MovieDetailView.getMovieWatchlist(
              simkl_id, auth.simklAccessToken)
            isLoading = false
          }
        }
    } else {
      HStack {
        if let poster = movieDetails?.poster {
          CustomKFImage(
            imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
            memoryCacheOnly: true,
            height: 221.43,
            width: 150
          )
        }
        Spacer()
        MovieWatchlistButton()
      }
      .padding([.trailing, .leading])

      if let title = movieDetails?.title {
        Text(title)
          .font(.title)
          .bold()
      }

      Spacer()
    }
  }
}

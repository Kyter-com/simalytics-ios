//
//  MovieDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

struct MovieDetailView: View {
  @EnvironmentObject private var auth: Auth
  @State private var movieDetails: MovieDetailsModel?
  @State private var movieWatchlist: MovieWatchlistModel?
  var simkl_id: Int

  var body: some View {
    if let title = movieDetails?.title {
      Text(title)
      Text(movieWatchlist?.list ?? "Add to Watchlist")
    } else {
      ProgressView("Loading...")
        .onAppear {
          Task {
            movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
            movieWatchlist = await MovieDetailView.getMovieWatchlist(
              simkl_id, auth.simklAccessToken)
          }
        }
    }
  }
}

//
//  MovieDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

struct MovieDetailView: View {
  @State private var movieDetails: MovieDetailsModel?
  var simkl_id: Int

  // https://wsrv.nl/?url=https://simkl.in/fanart/89/894768804228c9ecc_medium.webp

  var body: some View {
    GeometryReader { geometry in
      VStack {
        if let title = movieDetails?.title {
          Text(title)
        } else {
          ProgressView("Loading...")
            .onAppear {
              Task {
                movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
              }
            }
        }
      }
    }
  }
}

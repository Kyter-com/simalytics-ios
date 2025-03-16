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
        if let movieDetails = movieDetails {
          ZStack(alignment: .bottomLeading) {
            if let fanart = movieDetails.fanart {
              KFImage(
                URL(string: "https://wsrv.nl/?url=https://simkl.in/fanart/\(fanart)_mobile.jpg")
              )
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: geometry.size.width, height: geometry.size.height * 0.4)
              .clipped()
              .edgesIgnoringSafeArea(.top)
            }

            VStack(alignment: .leading) {
              Text(movieDetails.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.5))
          }

          Spacer()

          // Additional movie details can go here
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

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
  @State private var watchlistStatus: String?
  var simkl_id: Int

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .onAppear {
          Task {
            movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
            movieWatchlist = await MovieDetailView.getMovieWatchlist(
              simkl_id, auth.simklAccessToken)
            watchlistStatus = movieWatchlist?.list
            isLoading = false
          }
        }
    } else {
      ScrollView {
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
          VStack(alignment: .leading) {
            if let year = movieDetails?.year {
              LabeledContent {
                Text(String(year))
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Released", systemImage: "calendar")
                  .foregroundColor(.secondary)
              }
            }
            if let runtime = movieDetails?.runtime {
              LabeledContent {
                Text("\(String(runtime)) Min")
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Runtime", systemImage: "clock")
                  .foregroundColor(.secondary)
              }
            }
            if let certification = movieDetails?.certification {
              LabeledContent {
                Text(certification)
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("MPAA Rating", systemImage: "figure.and.child.holdinghands")
                  .foregroundColor(.secondary)
              }
            }
            if let language = movieDetails?.language {
              LabeledContent {
                Text(language)
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Language", systemImage: "globe")
                  .foregroundColor(.secondary)
              }
            }
            if let simklRating = movieDetails?.ratings?.simkl?.rating {
              LabeledContent {
                Text(String(simklRating))
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("SIMKL Rating", systemImage: "number")
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            MovieWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
          }
        }
        .padding([.leading, .trailing])

        if let title = movieDetails?.title {
          Text(title)
            .font(.title)
            .bold()
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing])
        }

        if let genres = movieDetails?.genres {
          Text(genres.joined(separator: " • "))
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding([.leading, .trailing])
            .padding(.top, 1)
            .fontDesign(.monospaced)
        }

        if let overview = movieDetails?.overview {
          Text(overview)
            .font(.footnote)
            .padding([.leading, .trailing])
            .padding(.top, 8)
        }

        Spacer()
      }
    }
  }
}

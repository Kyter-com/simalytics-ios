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
  @State private var showWatchlistSheet = false
  var simkl_id: Int

  var body: some View {
    VStack {
      if movieDetails != nil {
        ScrollView {
          HStack {
            Spacer()
            if let poster = movieDetails?.poster {
              KFImage(
                URL(
                  string:
                    "https://wsrv.nl/?url=https://simkl.in/posters/\(poster)_m.jpg"
                )
              )
              .placeholder {
                ProgressView()
              }
              .resizable()
              .serialize(as: .JPEG)
              .frame(width: 150, height: 221.43)
              .clipShape(RoundedRectangle(cornerRadius: 8))
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color(UIColor.systemBackground))
              )
            }

            Spacer()

            VStack {
              if let runtime = movieDetails?.runtime {
                HStack {
                  Image(systemName: "clock")
                  Text("\(runtime) Minutes")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
              }
              if let year = movieDetails?.year {
                HStack {
                  Image(systemName: "calendar")
                  Text("\(year)")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
              }

              Spacer()

              Button(action: {
                showWatchlistSheet.toggle()
              }) {
                Text("Add to List")
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(
                    Color(
                      UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark ? .white : .black
                      })
                  )
                  .foregroundColor(
                    Color(
                      UIColor { traitCollection in
                        traitCollection.userInterfaceStyle == .dark ? .black : .white
                      })
                  )
                  .cornerRadius(8)
                  .bold()
              }
              .sheet(isPresented: $showWatchlistSheet) {
                Text("Hello, World!")
              }
            }
            Spacer()
          }

          Text(movieDetails!.title)
            .font(.title)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      } else {
        ProgressView("Loading Movie...")
          .onAppear {
            Task {
              movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
            }
          }
      }
    }
  }
}

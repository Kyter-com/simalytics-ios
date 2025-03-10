//
//  MovieView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

struct MovieView: View {
  @State private var movieDetails: MovieDetailsModel?
  var simkl_id: Int
  @State private var showWatchlistSheet = false

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
              await getMovieDetails(simkl_id: simkl_id)
            }
          }
      }
    }
  }

  private func getMovieDetails(simkl_id: Int) async {
    do {
      var movieDetailsURLComponents = URLComponents()
      movieDetailsURLComponents.scheme = "https"
      movieDetailsURLComponents.host = "api.simkl.com"
      movieDetailsURLComponents.path = "/movies/\(simkl_id)"
      movieDetailsURLComponents.queryItems = [
        URLQueryItem(name: "extended", value: "full"),
        URLQueryItem(
          name: "client_id",
          value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
      ]
      var request = URLRequest(url: movieDetailsURLComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        movieDetails = nil
        return
      }
      let decoder = JSONDecoder()
      let movieResponse = try decoder.decode(MovieDetailsModel.self, from: data)
      if movieResponse.title != "" {
        movieDetails = movieResponse
      } else {
        movieDetails = nil
      }
    } catch {
      movieDetails = nil
      return
    }
  }
}

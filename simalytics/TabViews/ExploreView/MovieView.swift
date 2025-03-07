//
//  MovieView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

struct MovieView: View {
  @State private var movieDetails: MovieDetails?
  var simkl_id: Int

  var body: some View {
    VStack {
      if movieDetails != nil {
        ScrollView {
          if movieDetails!.fanart != nil {
            KFImage(
              URL(
                string:
                  "https://wsrv.nl/?url=https://simkl.in/fanart/\(movieDetails!.fanart!)_mobile.jpg"
              )
            )
            .placeholder {
              ProgressView()
            }
            .serialize(as: .JPEG)
            .resizable()
            .aspectRatio(contentMode: .fit)
          }

          Text(movieDetails!.title)
            .font(.title)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
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
      let movieResponse = try decoder.decode(MovieDetails.self, from: data)
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

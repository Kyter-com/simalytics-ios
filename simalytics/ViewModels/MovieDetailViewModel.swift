//
//  MovieDetailViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/15/25.
//

import Foundation
import Sentry

extension MovieDetailView {
  static func getMovieDetails(_ simkl_id: Int) async -> MovieDetailsModel? {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/movies/\(simkl_id)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "extended", value: "full"),
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode(MovieDetailsModel.self, from: data)
    } catch {
      SentrySDK.capture(error: error)
      return nil
    }
  }
}

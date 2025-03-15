//
//  SearchResultsViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/15/25.
//

import Foundation
import Sentry

extension SearchResultsView {
  static func fetchResults(searchText: String, type: String) async -> [SearchResultModel] {
    do {
      var urlComponents = URLComponents(string: "https://api.simkl.com/search/\(type)")!
      urlComponents.queryItems = [
        URLQueryItem(name: "q", value: searchText.lowercased()),
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
      ]

      var request = URLRequest(url: urlComponents.url!)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        return []
      }

      return try JSONDecoder().decode([SearchResultModel].self, from: data)
    } catch {
      SentrySDK.capture(error: error)
      return []
    }
  }
}

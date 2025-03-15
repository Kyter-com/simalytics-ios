//
//  SearchResultsViewModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/15/25.
//

import Foundation
import Sentry

enum SearchCategory: String, Codable, CaseIterable, Identifiable, Hashable {
  case all = "All"
  case tv = "TV"
  case movie = "Movies"
  case anime = "Anime"
  var id: String { rawValue }
}

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

  static func getSearchResults(searchText: String, searchType: String) async -> [SearchResultModel]
  {
    if searchType == "all" {
      let tvResults = await SearchResultsView.fetchResults(searchText: searchText, type: "tv")
      let movieResults = await SearchResultsView.fetchResults(searchText: searchText, type: "movie")
      let animeResults = await SearchResultsView.fetchResults(searchText: searchText, type: "anime")
      return tvResults + movieResults + animeResults
    } else if searchType == "movies" {
      let res = await SearchResultsView.fetchResults(searchText: searchText, type: "movie")
      return res
    } else {
      let res = await SearchResultsView.fetchResults(searchText: searchText, type: searchType)
      return res
    }
  }
}

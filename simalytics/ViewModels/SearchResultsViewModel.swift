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
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }

    do {
      let url = simklAPIURL(path: "search/\(type)", queryItems: [
        URLQueryItem(name: "q", value: query.lowercased()),
        URLQueryItem(name: "limit", value: "10"),
      ])

      var request = URLRequest(url: url)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.simklData(for: request)
      try Task.checkCancellation()
      guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        return []
      }

      return try JSONDecoder().decode([SearchResultModel].self, from: data)
    } catch is CancellationError {
      return []
    } catch {
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

  static func debounceSearch(
    query: String,
    searchCategory: SearchCategory,
    previousTask: inout Task<Void, Never>?,
    completion: @escaping @MainActor ([SearchResultModel]) -> Void
  ) {
    previousTask?.cancel()
    previousTask = Task {
      try? await Task.sleep(for: .seconds(1))
      guard !Task.isCancelled else { return }
      let results = await SearchResultsView.getSearchResults(
        searchText: query, searchType: searchCategory.rawValue.lowercased())
      guard !Task.isCancelled else { return }
      await MainActor.run { completion(results) }
    }
  }
}

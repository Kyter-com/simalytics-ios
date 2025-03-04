//
//  SearchResults.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/1/25.
//

import Kingfisher
import SwiftUI

enum SearchCategory: String, Codable, CaseIterable, Identifiable, Hashable {
  case all = "All"
  case tv = "TV"
  case movie = "Movies"
  case anime = "Anime"
  var id: String { rawValue }
}

struct SearchResults: View {
  @Binding var searchText: String
  @Binding var searchCategory: SearchCategory
  @State private var searchResults: [SearchResult] = []
  @State private var debounceWorkItem: DispatchWorkItem?

  var body: some View {
    List(searchResults, id: \.ids.simkl_id) { searchResult in
      Text(searchResult.title)
    }
    .onChange(of: searchText) { _, newValue in
      debounceSearch(newValue)
    }
    .onChange(of: searchCategory) { _, newValue in
      debounceSearch(searchText)
    }
  }

  private func debounceSearch(_ query: String) {
    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      Task {
        await getSearchResults(searchText: query, searchType: searchCategory.rawValue.lowercased())
      }
    }

    debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
  }

  private func getSearchResults(searchText: String, searchType: String) async {
    if searchType == "all" {
      let animeResults = await fetchResults(for: searchText, type: "anime")
      let movieResults = await fetchResults(for: searchText, type: "movie")
      let tvResults = await fetchResults(for: searchText, type: "tv")
      searchResults = animeResults + movieResults + tvResults
    } else if searchType == "movies" {
      searchResults = await fetchResults(for: searchText, type: "movie")
    } else {
      searchResults = await fetchResults(for: searchText, type: searchType)
    }
  }

  private func fetchResults(for searchText: String, type: String) async -> [SearchResult] {
    print("fetching \(type) results for \(searchText)")
    do {
      var searchResultsURLComponents = URLComponents()
      searchResultsURLComponents.scheme = "https"
      searchResultsURLComponents.host = "api.simkl.com"
      searchResultsURLComponents.path = "/search/\(type)"
      searchResultsURLComponents.queryItems = [
        URLQueryItem(name: "q", value: searchText.lowercased()),
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(
          name: "client_id",
          value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
      ]
      var request = URLRequest(url: searchResultsURLComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        return []
      }
      let decoder = JSONDecoder()
      let results = try decoder.decode([SearchResult].self, from: data)
      return results
    } catch {
      return []
    }
  }
}

#Preview {
  SearchResults(searchText: .constant(""), searchCategory: .constant(.all))
}

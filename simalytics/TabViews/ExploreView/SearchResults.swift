//
//  SearchResults.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/1/25.
//

import SwiftUI

struct SearchResults: View {
  @Binding var searchText: String
  @State private var searchResults: [SearchResult] = []
  @State private var debounceWorkItem: DispatchWorkItem?

  var body: some View {
    List(searchResults, id: \.ids.simkl_id) { searchResult in
      Text(searchResult.title)
    }
    .onChange(of: searchText) { _, newValue in
      debounceSearch(newValue)
    }
  }

  private func debounceSearch(_ query: String) {
    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      Task {
        await getSearchResults(searchText: query, searchType: "movie")
      }
    }

    debounceWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
  }

  private func getSearchResults(searchText: String, searchType: String) async {
    do {
      var SearchResultsURLComponents = URLComponents()
      SearchResultsURLComponents.scheme = "https"
      SearchResultsURLComponents.host = "api.simkl.com"
      SearchResultsURLComponents.path = "/search/\(searchType)"
      SearchResultsURLComponents.queryItems = [
        URLQueryItem(name: "q", value: searchText.lowercased()),
        URLQueryItem(name: "limit", value: "10"),
        URLQueryItem(
          name: "client_id",
          value: "c387a1e6b5cf2151af039a466c49a6b77891a4134aed1bcb1630dd6b8f0939c9"),
      ]
      var request = URLRequest(url: SearchResultsURLComponents.url!)
      request.httpMethod = "GET"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        searchResults = []
        return
      }
      let decoder = JSONDecoder()
      let showsResponse = try decoder.decode([SearchResult].self, from: data)
      if showsResponse.count > 0 {
        searchResults = showsResponse
      } else {
        searchResults = []
      }
    } catch {
      searchResults = []
    }
  }
}

#Preview {
  SearchResults(searchText: .constant(""))
}

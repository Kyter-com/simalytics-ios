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

  let columns = [
    GridItem(.flexible()),
    GridItem(.flexible()),
    GridItem(.flexible()),
  ]

  private func customKFImage(_ url: URL?) -> KFImage {
    let result = KFImage(url)
    result.options = KingfisherParsedOptionsInfo(
      KingfisherManager.shared.defaultOptions + [
        .forceTransition, .keepCurrentImageWhileLoading, .cacheMemoryOnly,
      ])
    return result
  }

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 16) {
        ForEach(searchResults, id: \.ids.simkl_id) { searchResult in
          NavigationLink(destination: destinationView(for: searchResult)) {
            VStack {
              if let poster = searchResult.poster {
                ZStack(alignment: .bottomLeading) {
                  customKFImage(
                    URL(string: "https://wsrv.nl/?url=https://simkl.in/posters/\(poster)_m.jpg")
                  )
                  .fade(duration: 0.33)
                  .placeholder {
                    ProgressView()
                  }
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .frame(width: 100, height: 147.62)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                  .overlay(
                    RoundedRectangle(cornerRadius: 8)
                      .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                  )
                  if let year = searchResult.year {
                    Text(String(year))
                      .font(.caption2)
                      .padding(4)
                      .background(
                        Color(
                          UIColor { traitCollection in
                            traitCollection.userInterfaceStyle == .dark ? .black : .white
                          }
                        ).opacity(0.8)
                      )
                      .cornerRadius(6)
                      .padding([.leading, .bottom], 6)
                  }
                }
              }
              Text(searchResult.title)
                .font(.subheadline)
                .padding(.top, 2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 100)
            }
          }
          .buttonStyle(.plain)
        }
      }
      .padding()
    }
    .onChange(of: searchText) { _, newValue in
      debounceSearch(newValue)
    }
    .onChange(of: searchCategory) { _, newValue in
      debounceSearch(searchText)
    }
  }

  private func destinationView(for searchResult: SearchResult) -> some View {
    switch searchResult.endpoint_type {
    case "tv":
      return AnyView(ShowView())
    case "movies":
        return AnyView(MovieView(simkl_id: searchResult.ids.simkl_id))
    case "anime":
      return AnyView(AnimeView())
    default:
      return AnyView(Text("Unknown type"))
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
      let tvResults = await fetchResults(for: searchText, type: "tv")
      let movieResults = await fetchResults(for: searchText, type: "movie")
      let animeResults = await fetchResults(for: searchText, type: "anime")
      searchResults = tvResults + movieResults + animeResults
    } else if searchType == "movies" {
      searchResults = await fetchResults(for: searchText, type: "movie")
    } else {
      searchResults = await fetchResults(for: searchText, type: searchType)
    }
  }

  private func fetchResults(for searchText: String, type: String) async -> [SearchResult] {
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
      // TODO: Send to Sentry
      return []
    }
  }
}

#Preview {
  SearchResults(searchText: .constant(""), searchCategory: .constant(.all))
}

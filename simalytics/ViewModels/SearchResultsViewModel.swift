import Foundation
import Observation

enum SearchCategory: String, Codable, CaseIterable, Identifiable, Hashable {
  case all = "All"
  case tv = "TV"
  case movie = "Movies"
  case anime = "Anime"
  var id: String { rawValue }
}

struct MediaSearchRequest: Hashable {
  let query: String
  let category: SearchCategory
  let hideAnime: Bool
  var retry = 0

  var endpoints: [String] {
    switch category {
    case .all: hideAnime ? ["tv", "movie"] : ["tv", "movie", "anime"]
    case .movie: ["movie"]
    case .tv: ["tv"]
    case .anime: hideAnime ? [] : ["anime"]
    }
  }
}

@MainActor
@Observable
final class SearchResultsViewModel {
  private(set) var results: [SearchResultModel] = []
  private(set) var completedRequest: MediaSearchRequest?
  private(set) var errorMessage: String?
  private var generation = 0

  func search(
    _ request: MediaSearchRequest,
    session: URLSession = .shared,
    debounce: Duration = .milliseconds(300)
  ) async {
    generation += 1
    let currentGeneration = generation
    // Keep the previous results on screen while typing; `completedRequest`
    // tells the view whether they still match the current query.

    do {
      let query = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
      var matches: [SearchResultModel] = []
      if !query.isEmpty {
        try await Task.sleep(for: debounce)
        for endpoint in request.endpoints {
          try Task.checkCancellation()
          matches += try await fetchMediaSearchResults(
            searchText: query, type: endpoint, session: session)
        }
      }
      try Task.checkCancellation()
      guard generation == currentGeneration else { return }
      results = matches
      errorMessage = nil
      completedRequest = request
    } catch {
      guard !isSimklCancellationError(error), !Task.isCancelled,
        generation == currentGeneration
      else { return }
      results = []
      errorMessage = "Couldn't load search results. Check your connection and try again."
      completedRequest = request
    }
  }
}

func fetchMediaSearchResults(
  searchText: String, type: String, session: URLSession = .shared
) async throws -> [SearchResultModel] {
  let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !query.isEmpty else { return [] }
  let url = simklAPIURL(
    path: "search/\(type)",
    queryItems: [
      URLQueryItem(name: "q", value: query.lowercased()),
      URLQueryItem(name: "limit", value: "10"),
    ])
  let (data, _) = try await performSimklRequest(
    URLRequest(url: url), retryCount: 0, session: session)
  try Task.checkCancellation()
  return try JSONDecoder().decode([SearchResultModel].self, from: data)
}

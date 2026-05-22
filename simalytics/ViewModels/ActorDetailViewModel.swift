//
//  ActorDetailViewModel.swift
//  simalytics
//
//  Created by Codex on 5/17/26.
//

import Foundation

// Stateless task delegate used to capture 3xx responses without following them.
// Required for the /redirect endpoint, which encodes the simkl id in the
// Location header rather than returning a JSON body.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
  static let shared = NoRedirectDelegate()

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}

extension ActorDetailView {
  static func getActorDetails(_ accessToken: String, personID: Int) async -> TMDBPersonDetails? {
    do {
      let url = URL(string: "https://api.simalytics.kyter.com/tmdb-person")!
      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
      request.setValue(String(personID), forHTTPHeaderField: "x-id")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      return try JSONDecoder().decode(TMDBPersonDetails.self, from: data)
    } catch {
      reportError(error)
      return nil
    }
  }

  static func filmographyItems(from details: TMDBPersonDetails) async -> [ActorFilmographyItem] {
    let credits = details.sortedFilmographyCredits
    return await withTaskGroup(of: (Int, ActorFilmographyItem).self) { group in
      for (index, credit) in credits.prefix(80).enumerated() {
        group.addTask {
          let destination = await resolveDestination(for: credit)
          return (index, ActorFilmographyItem(credit: credit, destination: destination))
        }
      }

      var indexedItems: [(Int, ActorFilmographyItem)] = []
      for await item in group {
        indexedItems.append(item)
      }

      return indexedItems
        .sorted { $0.0 < $1.0 }
        .map(\.1)
    }
  }

  private static func resolveDestination(for credit: TMDBPersonCredit) async -> MediaDestination? {
    let lookupType = credit.media_type == "movie" ? "movie" : "show"
    guard var urlComponents = URLComponents(string: "https://api.simkl.com/redirect") else {
      return nil
    }

    urlComponents.queryItems = [
      URLQueryItem(name: "to", value: "Simkl"),
      URLQueryItem(name: "tmdb", value: String(credit.id)),
      URLQueryItem(name: "type", value: lookupType),
      URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
    ]

    do {
      guard let url = urlComponents.url else { return nil }
      let request = URLRequest(url: url)

      // Simkl recommends /redirect over the legacy /search/id endpoint: it returns
      // 301 with the simkl id in the Location URL — no JSON body to parse. We
      // need to capture that 301 instead of letting URLSession follow it.
      let (_, response) = try await URLSession.shared.data(for: request, delegate: NoRedirectDelegate.shared)
      guard let http = response as? HTTPURLResponse,
            http.statusCode == 301,
            let location = http.value(forHTTPHeaderField: "Location"),
            let parsed = parseSimklRedirectLocation(location) else {
        return await resolveDestinationByTitle(for: credit)
      }

      return mediaDestination(type: parsed.type, simklID: parsed.simklID, fallbackMediaType: credit.media_type)
    } catch {
      reportError(error)
      return await resolveDestinationByTitle(for: credit)
    }
  }

  // Parses the Location header from /redirect, which looks like
  // "//simkl.com/{tv|movies|anime}/{simklID}/{slug}?client_id=…".
  // Returns nil for the not-found case ("//simkl.com?client_id=…").
  fileprivate static func parseSimklRedirectLocation(_ location: String) -> (type: String, simklID: Int)? {
    let normalized = location.hasPrefix("//") ? "https:" + location : location
    guard let url = URL(string: normalized) else { return nil }

    let segments = url.pathComponents.filter { $0 != "/" }
    guard segments.count >= 2 else { return nil }
    let type = segments[0]
    guard ["tv", "movies", "anime"].contains(type), let simklID = Int(segments[1]) else { return nil }
    return (type: type, simklID: simklID)
  }

  private static func resolveDestinationByTitle(for credit: TMDBPersonCredit) async -> MediaDestination? {
    let searchType = credit.media_type == "movie" ? "movie" : "tv"
    let results = await SearchResultsView.fetchResults(searchText: credit.displayTitle, type: searchType)
    let match = results.first { result in
      guard let creditYear = credit.year, let resultYear = result.year else { return false }
      return String(resultYear) == creditYear
    } ?? results.first

    guard let match else { return nil }
    return mediaDestination(
      type: match.endpoint_type,
      simklID: match.ids.simkl_id,
      fallbackMediaType: credit.media_type
    )
  }

  private static func mediaDestination(type: String?, simklID: Int, fallbackMediaType: String) -> MediaDestination {
    switch type {
      case "movie", "movies":
        return .movie(simklID)
      case "anime":
        return .anime(simklID)
      case "tv":
        return .show(simklID)
      default:
        return fallbackMediaType == "movie" ? .movie(simklID) : .show(simklID)
    }
  }
}

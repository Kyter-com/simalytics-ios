//
//  ActorDetailViewModel.swift
//  simalytics
//
//  Created by Codex on 5/17/26.
//

import Foundation

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
    guard var urlComponents = URLComponents(string: "https://api.simkl.com/search/id") else {
      return nil
    }

    urlComponents.queryItems = [
      URLQueryItem(name: "tmdb", value: String(credit.id)),
      URLQueryItem(name: "type", value: lookupType),
      URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
    ]

    do {
      guard let url = urlComponents.url else { return nil }
      var request = URLRequest(url: url)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

      let results = try JSONDecoder().decode([SimklIDLookupResponse].self, from: data)
      guard let result = results.first, let simklID = result.ids?.simkl else {
        return await resolveDestinationByTitle(for: credit)
      }

      return mediaDestination(type: result.type, simklID: simklID, fallbackMediaType: credit.media_type)
    } catch {
      reportError(error)
      return await resolveDestinationByTitle(for: credit)
    }
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

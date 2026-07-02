//
//  CastModel.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/14/26.
//

import Foundation
import Sentry

struct TMDBCreditsResponse: Codable {
  let id: Int?
  let cast: [TMDBCastMember]?
}

struct TMDBCastMember: Codable, Identifiable {
  let id: Int
  let name: String?
  let character: String?
  let profile_path: String?
  let order: Int?
}

func getCast(_ accessToken: String, _ tmdbId: String?, mediaType: String) async -> [TMDBCastMember] {
  guard let tmdbId else { return [] }
  do {
    let url = URL(string: "https://api.simalytics.kyter.com/tmdb-credits")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(mediaType, forHTTPHeaderField: "x-type")
    request.setValue(tmdbId, forHTTPHeaderField: "x-id")

    let (data, response) = try await URLSession.shared.simklData(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }

    let res = try JSONDecoder().decode(TMDBCreditsResponse.self, from: data)
    return (res.cast ?? []).sorted { ($0.order ?? .max) < ($1.order ?? .max) }
  } catch {
    SentrySDK.capture(error: error)
    return []
  }
}

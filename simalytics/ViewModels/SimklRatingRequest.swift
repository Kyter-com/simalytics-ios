import Foundation
import SwiftData

func setSimklRating(
  simklID: Int, type: RatingMediaType, rating: Int, accessToken: String,
  session: URLSession = .shared
) async -> SimklMutationResult {
  guard simklID > 0, (0...10).contains(rating) else {
    return .failed(userMessage: simklMutationUserMessage(for: SimklMutationError.invalidRating))
  }
  do {
    var request = URLRequest(
      url: simklAPIURL(path: rating == 0 ? "sync/ratings/remove" : "sync/ratings"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    var item: [String: Any] = ["ids": ["simkl": simklID]]
    if rating > 0 { item["rating"] = rating }
    request.httpBody = try JSONSerialization.data(withJSONObject: [type.payloadKey: [item]])
    let (data, _) = try await performSimklRequest(request, session: session)
    let acknowledgement: RatingAcknowledgement
    do {
      acknowledgement = try JSONDecoder().decode(RatingAcknowledgement.self, from: data)
    } catch {
      throw SimklMutationError.invalidResponse
    }
    guard acknowledgement.notFound.movies.isEmpty, acknowledgement.notFound.shows.isEmpty else {
      throw SimklMutationError.mediaNotFound
    }
    let counts = rating == 0 ? acknowledgement.deleted : acknowledgement.added
    guard counts?[type.payloadKey] == 1 else { throw SimklMutationError.invalidResponse }
    return .succeeded
  } catch {
    if isSimklCancellationError(error) { return .cancelled }
    reportError(error)
    return .failed(userMessage: simklMutationUserMessage(for: error))
  }
}

private struct RatingAcknowledgement: Decodable {
  let added: Counts?
  let deleted: Counts?
  let notFound: Rejections

  enum CodingKeys: String, CodingKey {
    case added, deleted
    case notFound = "not_found"
  }

  struct Counts: Decodable {
    let movies: Int
    let shows: Int
    subscript(key: String) -> Int { key == "movies" ? movies : shows }
  }
  struct Rejections: Decodable {
    let movies: [RejectedItem]
    let shows: [RejectedItem]
  }
  struct RejectedItem: Decodable {}
}

/// Update a confirmed rating immediately; a sync delta for removed ratings may
/// omit the now-unrated row, so don't rely on it to clear the local score.
@MainActor
func storeConfirmedRating(_ rating: Int, simklID: Int, type: RatingMediaType, context: ModelContext)
  throws
{
  let value: Int? = rating == 0 ? nil : rating
  let date: String? = rating == 0 ? nil : Date().ISO8601Format()
  switch type {
  case .movie:
    if let row = try context.fetch(
      FetchDescriptor<V1.SDMovies>(predicate: #Predicate { $0.simkl == simklID })
    ).first {
      row.user_rating = value
      row.user_rated_at = date
    }
  case .show:
    if let row = try context.fetch(
      FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == simklID })
    ).first {
      row.user_rating = value
      row.user_rated_at = date
    }
  case .anime:
    if let row = try context.fetch(
      FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.simkl == simklID })
    ).first {
      row.user_rating = value
      row.user_rated_at = date
    }
  }
  try context.save()
  NotificationCenter.default.post(name: .localMediaSnapshotsDidChange, object: nil)
}

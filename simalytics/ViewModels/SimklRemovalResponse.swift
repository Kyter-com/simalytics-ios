import Foundation

/// Remove responses may omit not_found.episodes in the documented schema,
/// while live responses include it. Validate it whenever it is present.
func validateSimklRemovalResponse(_ data: Data, countKey: String, singleEpisode: Bool = false)
  throws
{
  let response: SimklRemovalResponse
  do {
    response = try JSONDecoder().decode(SimklRemovalResponse.self, from: data)
  } catch {
    throw SimklMutationError.invalidResponse
  }
  guard let count = response.deleted[countKey], (0...1).contains(count),
    response.deleted.values.allSatisfy({ $0 >= 0 })
  else { throw SimklMutationError.invalidResponse }
  if !response.notFound.movies.isEmpty || !response.notFound.shows.isEmpty
    || !(response.notFound.episodes ?? []).isEmpty || !(response.notFound.anime ?? []).isEmpty
  {
    throw singleEpisode ? SimklMutationError.episodeNotFound : SimklMutationError.mediaNotFound
  }
}

private struct SimklRemovalResponse: Decodable {
  let deleted: [String: Int]
  let notFound: Rejections

  enum CodingKeys: String, CodingKey {
    case deleted
    case notFound = "not_found"
  }

  struct Rejections: Decodable {
    let movies: [RejectedItem]
    let shows: [RejectedItem]
    let episodes: [RejectedItem]?
    let anime: [RejectedItem]?
  }
  struct RejectedItem: Decodable {}
}

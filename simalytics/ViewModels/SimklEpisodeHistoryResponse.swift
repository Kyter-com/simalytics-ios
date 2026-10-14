import Foundation

/// Zero additions is valid for an idempotent already-watched retry. Typed
/// decoding rejects booleans and fractional counts as malformed acknowledgements.
func validateSimklEpisodeHistoryResponse(_ data: Data) throws {
  let response: SimklEpisodeHistoryResponse
  do {
    response = try JSONDecoder().decode(SimklEpisodeHistoryResponse.self, from: data)
  } catch {
    throw SimklMutationError.invalidResponse
  }
  guard (0...1).contains(response.added.episodes) else { throw SimklMutationError.invalidResponse }
  guard response.notFound.movies.isEmpty, response.notFound.shows.isEmpty,
    response.notFound.episodes.isEmpty
  else { throw SimklMutationError.episodeNotFound }
}

private struct SimklEpisodeHistoryResponse: Decodable {
  let added: Added
  let notFound: Rejections

  enum CodingKeys: String, CodingKey {
    case added
    case notFound = "not_found"
  }

  struct Added: Decodable { let episodes: Int }
  struct Rejections: Decodable {
    let movies: [RejectedItem]
    let shows: [RejectedItem]
    let episodes: [RejectedItem]
  }
  struct RejectedItem: Decodable {}
}

import Foundation

/// A missing scope key is valid only for SIMKL's documented empty response `{}`.
/// Do not mistake an error envelope, explicit null, or another bucket for emptiness.
func decodeSimklWatchingResponse<T: Decodable>(
  _ type: T.Type, from data: Data, key: String
) throws -> [T] {
  guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    throw SimklMutationError.invalidResponse
  }
  if root.isEmpty { return [] }
  guard root.count == 1, root[key] is [Any] else {
    throw SimklMutationError.invalidResponse
  }
  let entries = try JSONSerialization.data(withJSONObject: root[key]!)
  return try JSONDecoder().decode([T].self, from: entries)
}

import Foundation

/// Accept documented `{}` and observed HTTP-200 top-level `null` for empty lists.
/// Do not mistake an error envelope, null bucket array, or another bucket for emptiness.
func decodeSimklLibraryResponse<T: Decodable>(
  _ type: T.Type, from data: Data, key: String
) throws -> [T] {
  let object = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
  if object is NSNull { return [] }
  guard let root = object as? [String: Any] else {
    throw SimklMutationError.invalidResponse
  }
  if root.isEmpty { return [] }
  guard root.count == 1, root[key] is [Any] else {
    throw SimklMutationError.invalidResponse
  }
  let entries = try JSONSerialization.data(withJSONObject: root[key]!)
  return try JSONDecoder().decode([T].self, from: entries)
}

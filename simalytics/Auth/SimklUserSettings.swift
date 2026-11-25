//
//  SimklUserSettings.swift
//  simalytics
//

import Foundation

/// `GET /users/settings`: the signed-in person's account and plan. Rewatches
/// need a `pro` or `vip` plan.
struct SimklUserSettingsModel: Decodable, Sendable {
  struct Account: Decodable, Sendable {
    let id: Int?
    let type: String?
  }

  struct User: Decodable, Sendable {
    let name: String?
  }

  let account: Account?
  let user: User?

  /// Who this is, for telling the same person apart on reconnect.
  var simklAccount: SimklAccount? {
    guard let id = account?.id, id > 0 else { return nil }
    return SimklAccount(id: id, name: user?.name)
  }
}

/// The signed-in person's profile and plan.
func fetchSimklUserSettings(session: URLSession = .shared) async throws -> SimklUserSettingsModel {
  var request = URLRequest(url: simklAPIURL(path: "users/settings"))
  request.simklAuth = .user
  let (data, _) = try await performSimklRequest(request, session: session)
  do {
    return try JSONDecoder().decode(SimklUserSettingsModel.self, from: data)
  } catch {
    throw SimklMutationError.invalidResponse
  }
}

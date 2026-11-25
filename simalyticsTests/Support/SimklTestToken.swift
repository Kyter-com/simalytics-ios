import Foundation

@testable import Simalytics

/// A session holding an AUTH V1 credential whose access token is `token`. V1
/// can't refresh, so a fixture's 401 ends the attempt instead of reaching for a
/// token endpoint that no fixture serves.
func simklTestSession(
  token: String, version: SimklAuthVersion = .v1, account: SimklAccount? = SimklAccount(id: 1)
) -> SimklSession {
  SimklSession(
    store: SimklMemoryCredentialStore(
      SimklCredential(
        version: version, accessToken: token,
        scope: version == .v2 ? "media:read media:write" : nil, account: account)))
}

/// Runs `operation` with requests signed by `token`. The contract fixtures read
/// the scenario they should play from the `Authorization` header, so the token
/// doubles as the scenario name.
nonisolated(nonsending) func withSimklToken<T>(
  _ token: String,
  _ operation: nonisolated(nonsending) () async throws -> T
) async rethrows -> T {
  try await SimklAPI.$scopedSession.withValue(simklTestSession(token: token), operation: operation)
}

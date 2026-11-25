//
//  LocalLibrary.swift
//  simalytics
//

import AuthenticationServices
import SwiftData
import SwiftUI

/// This device's copy of a Simkl library.
@MainActor
enum LocalLibrary {
  /// Clears the downloaded library and rewatch sessions. Used by sign-out, and
  /// when another account replaces this one. Nothing on Simkl changes.
  static func reset(_ context: ModelContext) {
    func clearAll<T: PersistentModel>(_ type: T.Type) {
      if let results = try? context.fetch(FetchDescriptor<T>()) {
        for item in results {
          context.delete(item)
        }
      }
    }

    clearAll(V1.SDLastSync.self)
    clearAll(V1.SDMovies.self)
    clearAll(V1.SDShows.self)
    clearAll(V1.SDAnimes.self)
    clearAll(V1.TrendingShows.self)
    clearAll(V1.TrendingMovies.self)
    clearAll(V1.TrendingAnimes.self)

    try? context.save()
    RewatchStore.shared.reset()
  }
}

extension WebAuthenticationSession {
  /// Opens Simkl's consent page in the system's secure web session. It shares
  /// Safari's cookies, so someone already signed in to simkl.com only approves,
  /// and iOS shows its own "wants to use simkl.com to sign in" prompt, which a
  /// lookalike page can't fake.
  func simklAuthenticate() -> SimklSignInFlow.Authenticate {
    { url in
      do {
        return try await authenticate(
          using: url, callbackURLScheme: SimklOAuthConfig.callbackScheme)
      } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
        throw SimklSignInError.cancelled
      }
    }
  }
}

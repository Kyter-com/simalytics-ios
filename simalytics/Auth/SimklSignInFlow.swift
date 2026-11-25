//
//  SimklSignInFlow.swift
//  simalytics
//

import Foundation

/// One AUTH V2 browser sign-in: PKCE, Simkl's consent page, the callback
/// checks, the code exchange, and confirming which account approved it.
///
/// The browser step is passed in, so the app uses `ASWebAuthenticationSession`
/// (Simkl recommends it, and its system prompt is chrome a phishing page can't
/// fake) while tests hand back a callback URL directly.
@MainActor
struct SimklSignInFlow {
  /// Opens the consent page and returns Simkl's redirect. Throws
  /// `SimklSignInError.cancelled` when the person closes the sheet.
  typealias Authenticate = @MainActor (URL) async throws -> URL

  struct Result: Sendable {
    let credential: SimklCredential
    let account: SimklAccount
    let plan: String?
  }

  let oauth: SimklOAuthClient

  func run(authenticate: Authenticate) async throws(SimklSignInError) -> Result {
    let pkce: SimklPKCE
    let state: String
    do {
      pkce = try SimklPKCE.generate()
      state = try SimklPKCE.randomURLSafeString(byteCount: 16)
    } catch {
      throw .randomGenerationFailed
    }

    let callback: URL
    do {
      callback = try await authenticate(oauth.authorizationURL(state: state, pkce: pkce))
    } catch let error as SimklSignInError {
      throw error
    } catch {
      throw isTransientNetworkError(error) ? .network : .authorizationRejected(code: "web_session")
    }

    let code = try oauth.authorizationCode(from: callback, expectedState: state)
    var credential = try await oauth.exchange(code: code, verifier: pkce.verifier)

    // Omitting or misspelling the scope quietly yields a read-only token, which
    // would only fail on the first write. Catch it here instead.
    guard credential.canWrite else {
      await revoke(credential)
      throw .missingWriteAccess
    }

    do {
      let settings = try await oauth.fetchAccount(for: credential)
      credential.account = settings.account
      return Result(credential: credential, account: settings.account, plan: settings.plan)
    } catch {
      await revoke(credential)
      throw isTransientNetworkError(error) ? .network : .accountLookupFailed
    }
  }

  private func revoke(_ credential: SimklCredential) async {
    await oauth.revoke(credential.refreshToken ?? credential.accessToken)
  }
}

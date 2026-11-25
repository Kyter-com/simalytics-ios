//
//  SimklCredentialStore.swift
//  simalytics
//

import Foundation
import SimpleKeychain

/// Where the signed-in credential lives between launches.
protocol SimklCredentialStore: Sendable {
  /// Nil when there's no credential. Throws when one may exist but can't be read
  /// right now, which must never be mistaken for "signed out".
  func load() throws -> SimklCredential?
  func save(_ credential: SimklCredential) throws
  func delete() throws
}

/// The Keychain store.
///
/// AUTH V2 credentials go in one item that stays on this device
/// (`afterFirstUnlockThisDeviceOnly`). A refresh invalidates the previous access
/// token, so two devices restored from one backup would keep cutting each other
/// off; each device signs in for itself instead.
///
/// Older builds kept a bare AUTH V1 token under `simkl-access-token`. That item
/// is read as a V1 credential and left in place, so a build from before AUTH V2
/// still finds it, until an AUTH V2 sign-in replaces it.
struct SimklKeychainCredentialStore: SimklCredentialStore {
  static let credentialKey = "simkl-credential"
  static let legacyTokenKey = "simkl-access-token"

  /// The app's bundle ID, which is SimpleKeychain's default service. Spelled out
  /// so a process without one (a test runner) gets an error, not a crash.
  private static var service: String { Bundle.main.bundleIdentifier ?? "com.kyter.simalytics" }

  private var keychain: SimpleKeychain {
    SimpleKeychain(service: Self.service, accessibility: .afterFirstUnlockThisDeviceOnly)
  }

  /// Older builds wrote the V1 token with SimpleKeychain's defaults.
  private var legacyKeychain: SimpleKeychain { SimpleKeychain(service: Self.service) }

  func load() throws -> SimklCredential? {
    do {
      let data = try keychain.data(forKey: Self.credentialKey)
      do {
        return try JSONDecoder().decode(SimklCredential.self, from: data)
      } catch {
        // An unreadable item can't become readable later; drop it and fall back
        // to the legacy token, or to "reconnect" if there's a library.
        try? keychain.deleteItem(forKey: Self.credentialKey)
        reportError(error)
      }
    } catch let error as SimpleKeychainError where error == .itemNotFound {
      // Nothing saved by this build yet; look for an older build's token.
    }

    do {
      let token = try legacyKeychain.string(forKey: Self.legacyTokenKey)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return token.isEmpty ? nil : SimklCredential(version: .v1, accessToken: token)
    } catch let error as SimpleKeychainError where error == .itemNotFound {
      return nil
    }
  }

  func save(_ credential: SimklCredential) throws {
    try keychain.set(try JSONEncoder().encode(credential), forKey: Self.credentialKey)
    // The saved item now wins over the legacy token. Leave the legacy token only
    // while it is still the credential in use.
    if credential.version == .v2 || credential.invalidatedAt != nil {
      deleteLegacyToken()
    }
  }

  func delete() throws {
    var failure: Error?
    do {
      try keychain.deleteItem(forKey: Self.credentialKey)
    } catch let error as SimpleKeychainError where error == .itemNotFound {
    } catch {
      failure = error
    }
    do {
      try legacyKeychain.deleteItem(forKey: Self.legacyTokenKey)
    } catch let error as SimpleKeychainError where error == .itemNotFound {
    } catch {
      failure = failure ?? error
    }
    if let failure { throw failure }
  }

  private func deleteLegacyToken() {
    try? legacyKeychain.deleteItem(forKey: Self.legacyTokenKey)
  }
}

/// A store that lives only in memory, for tests and the screenshot harness.
final class SimklMemoryCredentialStore: SimklCredentialStore, @unchecked Sendable {
  private let lock = NSLock()
  private var credential: SimklCredential?
  private var loadError: Error?

  init(_ credential: SimklCredential? = nil, loadError: Error? = nil) {
    self.credential = credential
    self.loadError = loadError
  }

  var saved: SimklCredential? { lock.withLock { credential } }

  func load() throws -> SimklCredential? {
    try lock.withLock {
      if let loadError { throw loadError }
      return credential
    }
  }

  func save(_ credential: SimklCredential) throws { lock.withLock { self.credential = credential } }

  func delete() throws { lock.withLock { credential = nil } }
}

/// The account whose library is on this device, kept outside the Keychain.
///
/// It outlives the credential where that matters: a backup restored to a new
/// iPhone brings the library and this marker but not the device-only
/// credential, and the app then asks to reconnect instead of looking signed
/// out over a full library.
struct SimklLibraryOwnerStore: Sendable {
  private let suiteName: String?
  private let key: String

  init(suiteName: String? = nil, key: String = "simklLibraryOwner") {
    self.suiteName = suiteName
    self.key = key
  }

  private var defaults: UserDefaults { suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard }

  func load() -> SimklAccount? {
    defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SimklAccount.self, from: $0) }
  }

  func save(_ account: SimklAccount) {
    guard let data = try? JSONEncoder().encode(account) else { return }
    defaults.set(data, forKey: key)
  }

  func clear() { defaults.removeObject(forKey: key) }
}

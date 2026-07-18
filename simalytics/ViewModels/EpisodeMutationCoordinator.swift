//
//  EpisodeMutationCoordinator.swift
//  simalytics
//

import Observation

@Observable @MainActor
final class EpisodeMutationCoordinator {
  enum RunResult: Equatable {
    case succeeded
    case failed(userMessage: String)
    case cancelled
    case suppressed
  }

  private(set) var isUpdating = false

  func run(
    optimisticUpdate: () -> Void,
    rollback: () -> Void,
    mutation: () async -> SimklMutationResult,
    commit: () -> Void,
    reconcile: () async -> Void
  ) async -> RunResult {
    guard !isUpdating else { return .suppressed }
    isUpdating = true
    defer { isUpdating = false }

    optimisticUpdate()
    let mutationResult = await mutation()

    switch mutationResult {
    case .cancelled:
      rollback()
      return .cancelled

    case .failed(let userMessage):
      rollback()
      guard !Task.isCancelled else { return .cancelled }
      await reconcile()
      guard !Task.isCancelled else { return .cancelled }
      return .failed(userMessage: userMessage)

    case .succeeded:
      // A server-acknowledged mutation must not be rolled back merely because
      // the sheet disappeared after the response arrived. The invalidated
      // cache will reconcile it on the next active sync.
      guard !Task.isCancelled else { return .cancelled }
      commit()
      await reconcile()
      guard !Task.isCancelled else { return .cancelled }
      return .succeeded
    }
  }
}

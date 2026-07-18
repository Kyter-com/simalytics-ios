import Testing

@testable import Simalytics

@MainActor
@Suite("Episode mutation coordination")
struct EpisodeMutationCoordinatorTests {
  @Test("A second mutation is suppressed while the first owns the update")
  func suppressesDoubleSubmission() async {
    let coordinator = EpisodeMutationCoordinator()
    let gate = TestGate()
    let events = EventLog()

    let first = Task { @MainActor in
      await coordinator.run(
        optimisticUpdate: { events.append("optimistic") },
        rollback: { events.append("rollback") },
        mutation: {
          await gate.wait()
          return .succeeded
        },
        commit: { events.append("commit") },
        reconcile: { events.append("reconcile") }
      )
    }

    while !gate.isWaiting {
      await Task.yield()
    }

    let second = await coordinator.run(
      optimisticUpdate: { events.append("unexpected optimistic") },
      rollback: { events.append("unexpected rollback") },
      mutation: { .succeeded },
      commit: { events.append("unexpected commit") },
      reconcile: { events.append("unexpected reconcile") }
    )
    #expect(second == .suppressed)

    gate.open()
    #expect(await first.value == .succeeded)
    #expect(events.values == ["optimistic", "commit", "reconcile"])
    #expect(coordinator.isUpdating == false)
  }

  @Test("Failure rolls back once and reconciles once")
  func rollsBackFailure() async {
    let coordinator = EpisodeMutationCoordinator()
    let events = EventLog()

    let result = await coordinator.run(
      optimisticUpdate: { events.append("optimistic") },
      rollback: { events.append("rollback") },
      mutation: { .failed(userMessage: "safe") },
      commit: { events.append("commit") },
      reconcile: { events.append("reconcile") }
    )

    #expect(result == .failed(userMessage: "safe"))
    #expect(events.values == ["optimistic", "rollback", "reconcile"])
  }

  @Test("Cancellation restores the optimistic value without refresh work")
  func rollsBackCancellation() async {
    let coordinator = EpisodeMutationCoordinator()
    let gate = TestGate()
    let events = EventLog()
    let task = Task { @MainActor in
      await coordinator.run(
        optimisticUpdate: { events.append("optimistic") },
        rollback: { events.append("rollback") },
        mutation: {
          await gate.wait()
          return Task.isCancelled ? .cancelled : .succeeded
        },
        commit: { events.append("commit") },
        reconcile: { events.append("reconcile") }
      )
    }

    while !gate.isWaiting {
      await Task.yield()
    }
    task.cancel()
    gate.open()

    #expect(await task.value == .cancelled)
    #expect(events.values == ["optimistic", "rollback"])
    #expect(coordinator.isUpdating == false)
  }
}

@MainActor
private final class TestGate {
  private var continuation: CheckedContinuation<Void, Never>?
  private(set) var isWaiting = false

  func wait() async {
    isWaiting = true
    await withCheckedContinuation { continuation = $0 }
  }

  func open() {
    continuation?.resume()
    continuation = nil
  }
}

@MainActor
private final class EventLog {
  private(set) var values: [String] = []

  func append(_ value: String) {
    values.append(value)
  }
}

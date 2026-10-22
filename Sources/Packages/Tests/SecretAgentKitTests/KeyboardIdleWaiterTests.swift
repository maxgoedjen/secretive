import Foundation
import Testing
@testable import SecretAgentKit

@MainActor final class ControlledKeyboardActivity {

    var idleTime: TimeInterval?
    var onSleep: (() -> Void)?
    private(set) var sampleCount = 0
    private(set) var sleepCount = 0
    private var sleepers: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private var sleepObservers: [(Int, CheckedContinuation<Void, Never>)] = []

    init(idleTime: TimeInterval?) {
        self.idleTime = idleTime
    }

    var waiter: KeyboardIdleWaiter {
        KeyboardIdleWaiter(secondsSinceLastKeyboardEvent: {
            self.sampleCount += 1
            return self.idleTime
        }, waitForNextCheck: {
            try await self.sleep()
        })
    }

    func waitUntilSleepCount(_ expected: Int) async {
        guard sleepCount < expected else { return }
        await withCheckedContinuation { continuation in
            sleepObservers.append((expected, continuation))
        }
    }

    func resumeAll() {
        let current = sleepers
        sleepers.removeAll()
        for continuation in current.values {
            continuation.resume()
        }
    }

    private func sleep() async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                sleepers[id] = continuation
                sleepCount += 1
                onSleep?()
                let ready = sleepObservers.filter { $0.0 <= sleepCount }
                sleepObservers.removeAll { $0.0 <= sleepCount }
                for observer in ready {
                    observer.1.resume()
                }
            }
        } onCancel: {
            Task { @MainActor in
                self.sleepers.removeValue(forKey: id)?.resume(throwing: CancellationError())
            }
        }
    }

}

@MainActor final class TestSignal {

    private var signaled = false
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func signal() {
        signaled = true
        let current = continuations
        continuations.removeAll()
        for continuation in current {
            continuation.resume()
        }
    }

    func wait() async {
        guard !signaled else { return }
        await withCheckedContinuation { continuations.append($0) }
    }

}

@MainActor @Suite(.timeLimit(.minutes(1))) struct KeyboardIdleWaiterTests {

    @Test func waitsUntilKeyboardHasBeenIdleForOneSecond() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0.4)
        let task = Task { try await activity.waiter.waitUntilIdle() }
        await activity.waitUntilSleepCount(1)
        activity.idleTime = 0.9
        activity.resumeAll()
        await activity.waitUntilSleepCount(2)
        #expect(activity.sampleCount == 2)
        activity.idleTime = 1
        activity.resumeAll()
        #expect(try await task.value == .idle)
    }

    @Test func cancellationStopsWaiting() async {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let task = Task { try await activity.waiter.waitUntilIdle() }
        await activity.waitUntilSleepCount(1)
        task.cancel()
        if case .failure(let error) = await task.result {
            #expect(error is CancellationError)
        } else {
            Issue.record("A cancelled keyboard wait completed successfully")
        }
    }

    @Test func stopsWhenPresentationIsNoLongerNeeded() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        var needed = true
        let task = Task { try await activity.waiter.waitUntilIdle { needed } }
        await activity.waitUntilSleepCount(1)
        needed = false
        activity.resumeAll()
        #expect(try await task.value == .noLongerNeeded)
    }

    @Test func retriesUnavailableActivityBeforeReturning() async throws {
        let activity = ControlledKeyboardActivity(idleTime: nil)
        let task = Task { try await activity.waiter.waitUntilIdle() }
        await activity.waitUntilSleepCount(1)
        activity.resumeAll()
        #expect(try await task.value == .unavailable)
        #expect(activity.sampleCount == 2)
    }

}

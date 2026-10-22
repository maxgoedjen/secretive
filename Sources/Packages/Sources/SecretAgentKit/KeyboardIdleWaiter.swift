import CoreGraphics
import Foundation

/// Waits for a short pause in keyboard activity before presenting automatic UI.
@MainActor struct KeyboardIdleWaiter {

    enum Result: Equatable {
        case idle
        case unavailable
        case noLongerNeeded
    }

    private static let quietPeriod: TimeInterval = 1

    private let secondsSinceLastKeyboardEvent: () -> TimeInterval?
    private let waitForNextCheck: () async throws -> Void

    init() {
        self.init(secondsSinceLastKeyboardEvent: Self.currentKeyboardIdleTime) {
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    init(
        secondsSinceLastKeyboardEvent: @escaping () -> TimeInterval?,
        waitForNextCheck: @escaping () async throws -> Void
    ) {
        self.secondsSinceLastKeyboardEvent = secondsSinceLastKeyboardEvent
        self.waitForNextCheck = waitForNextCheck
    }

    func waitUntilIdle(continuingWhile shouldContinue: () -> Bool = { true }) async throws -> Result {
        var unavailableSamples = 0
        while true {
            try Task.checkCancellation()
            guard shouldContinue() else { return .noLongerNeeded }
            guard let idleTime = secondsSinceLastKeyboardEvent() else {
                unavailableSamples += 1
                guard unavailableSamples < 2 else { return .unavailable }
                try await waitForNextCheck()
                continue
            }
            unavailableSamples = 0
            guard idleTime < Self.quietPeriod else { return .idle }
            try await waitForNextCheck()
        }
    }

    private static func currentKeyboardIdleTime() -> TimeInterval? {
        let eventTypes: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let idleTimes = eventTypes.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }
        guard idleTimes.allSatisfy({ !$0.isNaN && $0 >= 0 }) else { return nil }
        // Core Graphics has no error return for this query. An all-zero result
        // is ambiguous and has been observed in restricted environments. The
        // waiter retries it once before preserving existing presentation behavior.
        guard idleTimes.contains(where: { $0 > 0 }) else { return nil }
        return idleTimes.min()
    }

}

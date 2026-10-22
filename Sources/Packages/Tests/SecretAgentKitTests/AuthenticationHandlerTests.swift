import Testing
import Foundation
import LocalAuthentication
import SecretKit
@testable import SecretAgentKit
import SSHProtocolKit

public struct TestSecret: Secret {

    public let id = UUID()
    public let name = "Test"
    public let publicKey = Data()
    public var attributes: Attributes

}

@MainActor final class TestContext: @preconcurrency AuthenticationContextProtocol, Sendable {

    let id = UUID()
    private var testEvaluationResult: Bool

    private(set) var canceled: Bool
    private(set) var cancellationCount = 0
    private(set) var evaluationStarted = false
    private(set) var evaluationResult: Bool? = nil
    var onCancel: (() -> Void)?
    var cancellationGate: TestSignal?
    private let evaluationSignal = TestSignal()
    private let cancellationStartedSignal = TestSignal()
    private let cancellationSignal = TestSignal()

    let approval: ApprovalMode
    let secret: AnySecret
    let laContext: LAContext? = nil

    enum ApprovalMode {
        case manual
        case duration(Duration)
    }

    init(authenticationRequirement: AuthenticationRequirement, testEvaluationResult: Bool, approval: ApprovalMode = .manual) {
        self.canceled = false
        self.testEvaluationResult = testEvaluationResult
        self.secret = AnySecret(TestSecret(attributes: .init(keyType: .ecdsa256, authentication: authenticationRequirement)))
        self.approval = approval
    }

    nonisolated func valid(for request: SecretKit.SignatureRequest) -> Bool {
        true
    }

    func evaluate(requireBiometrics: Bool) async throws -> Bool {
        evaluationStarted = true
        evaluationSignal.signal()
        if case let .duration(duration) = approval {
            try await Task.sleep(for: duration)
        } else {
            while true {
                try await Task.sleep(for: .milliseconds(10))
                guard !canceled else { return false }
            }
        }
        guard !canceled else { return false }
        evaluationResult = testEvaluationResult
        return testEvaluationResult
    }
    
    func cancel() async {
        cancellationCount += 1
        onCancel?()
        cancellationStartedSignal.signal()
        await cancellationGate?.wait()
        canceled = true
        cancellationSignal.signal()
    }

    func waitUntilEvaluationStarts() async {
        await evaluationSignal.wait()
    }

    func waitUntilCanceled() async {
        await cancellationSignal.wait()
    }

    func waitUntilCancellationStarts() async {
        await cancellationStartedSignal.wait()
    }


}

@MainActor @Suite(.timeLimit(.minutes(1))) struct AuthenticationHandlerTests {

    let handler = AuthenticationHandler(keyboardIdleWaiter: KeyboardIdleWaiter(
        secondsSinceLastKeyboardEvent: { 1 },
        waitForNextCheck: {}
    ))

    @Test func singleImmediatelyRequests() async throws {
        var calledPresentPending = false
        handler.setPendingRequestHandler {
            calledPresentPending = true
        }
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.zero))
        _ = try await handler.authenticatedContext(for: .init(secret: .init(context.secret), provenance: .test, target: nil), context: context)
        #expect(context.evaluationResult == true)
        #expect(!calledPresentPending)
    }

    @Test func sequentialRequestsDoNotBlock() async throws {
        var calledPresentPending = false
        handler.setPendingRequestHandler {
            calledPresentPending = true
        }
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
        _ = try await handler.authenticatedContext(for: .init(secret: .init(context.secret), provenance: .test, target: nil), context: context)
        #expect(context.evaluationResult == true)
        let second = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
        _ = try await handler.authenticatedContext(for: .init(secret: .init(second.secret), provenance: .test, target: nil), context: second)
        #expect(context.evaluationResult == true)
        #expect(second.evaluationResult == true)
        #expect(!calledPresentPending)
    }

    @Test func secondRetractsAndPresentsBatch() async throws {
        var calledPresentPending = false
        let presented = TestSignal()
        handler.setPendingRequestHandler {
            calledPresentPending = true
            presented.signal()
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let taskA = Task {
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        await contextA.waitUntilEvaluationStarts()
        let taskB = Task {
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
        }
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == nil)
        await presented.wait()
        #expect(contextA.canceled)
        #expect(calledPresentPending)
        taskA.cancel()
        taskB.cancel()
        await taskA.value
        await taskB.value
    }

    @Test func authRequiredDoesNotBlockNoAuthRequired() async throws {
        var calledPresentPending = false
        handler.setPendingRequestHandler {
            calledPresentPending = true
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .manual)
        let contextB = TestContext(authenticationRequirement: .notRequired, testEvaluationResult: true)
        var unauthenticatedResult = false
        Task {
            Task {
                _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
                unauthenticatedResult = true
            }
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        try await Task.sleep(for: .milliseconds(10))
        #expect(contextA.evaluationResult == nil)
        #expect(unauthenticatedResult)
        #expect(!contextA.canceled)
        #expect(!contextB.canceled)
        #expect(!calledPresentPending)
    }

    @Test func batchDoesNotBlockNoAuthRequired() async throws {
        var calledPresentPending = false
        let presented = TestSignal()
        handler.setPendingRequestHandler {
            calledPresentPending = true
            presented.signal()
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextC = TestContext(authenticationRequirement: .notRequired, testEvaluationResult: true)
        let taskA = Task {
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        await contextA.waitUntilEvaluationStarts()
        let taskB = Task {
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
        }
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == nil)
        await presented.wait()
        #expect(contextA.canceled)
        #expect(calledPresentPending)
        _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextC.secret), provenance: .test, target: nil), context: contextA)
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == nil)
        taskA.cancel()
        taskB.cancel()
        await taskA.value
        await taskB.value
    }

    @Test func batching() async throws {

    }

    @Test func automaticAuthenticationWaitsUntilIdle() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        var presentationCount = 0
        handler.setPendingRequestHandler { presentationCount += 1 }
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.zero))
        let task = Task {
            try await handler.authenticatedContext(for: .init(secret: context.secret, provenance: .test, target: nil), context: context)
        }
        await activity.waitUntilSleepCount(1)
        #expect(!context.evaluationStarted)
        activity.idleTime = 1
        activity.resumeAll()
        _ = try await task.value
        #expect(context.evaluationResult == true)
        #expect(presentationCount == 0)
    }

    @Test func noAuthenticationRequiredDoesNotReadKeyboardActivity() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let context = TestContext(authenticationRequirement: .notRequired, testEvaluationResult: true)
        _ = try await handler.authenticatedContext(for: .init(secret: context.secret, provenance: .test, target: nil), context: context)
        #expect(activity.sampleCount == 0)
    }

    @Test func unavailableActivityPreservesAutomaticAuthentication() async throws {
        let activity = ControlledKeyboardActivity(idleTime: nil)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.zero))
        let task = Task {
            try await handler.authenticatedContext(for: .init(secret: context.secret, provenance: .test, target: nil), context: context)
        }
        await activity.waitUntilSleepCount(1)
        activity.resumeAll()
        _ = try await task.value
        #expect(context.evaluationResult == true)
        #expect(activity.sampleCount == 2)
    }

    @Test func cancellingWhileTypingDoesNotAuthenticateOrPresent() async {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        var presentationCount = 0
        handler.setPendingRequestHandler { presentationCount += 1 }
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.zero))
        let task = Task {
            try await handler.authenticatedContext(for: .init(secret: context.secret, provenance: .test, target: nil), context: context)
        }
        await activity.waitUntilSleepCount(1)
        task.cancel()
        if case .failure(let error) = await task.result {
            #expect(error is CancellationError)
        } else {
            Issue.record("A cancelled request returned an authentication context")
        }
        await context.waitUntilCanceled()
        #expect(!context.evaluationStarted)
        #expect(context.cancellationCount == 1)
        #expect(handler.batchableRequests.isEmpty)
        #expect(presentationCount == 0)
    }

    @Test func batchTransitionCancelsBeforeWaitingAndPresentsOnce() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 1)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let presented = TestSignal()
        var events: [String] = []
        var presentationCount = 0
        handler.setPendingRequestHandler {
            events.append("present")
            presentationCount += 1
            presented.signal()
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextC = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        contextA.onCancel = { events.append("cancel") }
        let taskA = Task {
            try await handler.authenticatedContext(for: .init(secret: contextA.secret, provenance: .test, target: nil), context: contextA)
        }
        await contextA.waitUntilEvaluationStarts()
        activity.idleTime = 0
        activity.onSleep = { events.append("wait") }
        let taskB = Task {
            try await handler.authenticatedContext(for: .init(secret: contextB.secret, provenance: .test, target: nil), context: contextB)
        }
        await activity.waitUntilSleepCount(1)
        #expect(events == ["cancel", "wait"])
        let taskC = Task {
            try await handler.authenticatedContext(for: .init(secret: contextC.secret, provenance: .test, target: nil), context: contextC)
        }
        for _ in 0..<100 where handler.batchableRequests.flatMap({ $0 }).count < 3 {
            await Task.yield()
        }
        #expect(handler.batchableRequests.flatMap({ $0 }).count == 3)
        #expect(activity.sleepCount == 1)
        #expect(!contextB.evaluationStarted)
        #expect(!contextC.evaluationStarted)
        activity.idleTime = 1
        activity.resumeAll()
        await presented.wait()
        #expect(events == ["cancel", "wait", "present"])
        #expect(presentationCount == 1)
        taskA.cancel()
        taskB.cancel()
        taskC.cancel()
        _ = await taskA.result
        _ = await taskB.result
        _ = await taskC.result
        #expect(handler.batchableRequests.isEmpty)
        #expect(presentationCount == 1)
        #expect(contextA.cancellationCount == 1)
    }

    @Test func cancellingPendingWaitAllowsAnotherPresenter() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let presented = TestSignal()
        var presentationCount = 0
        handler.setPendingRequestHandler {
            presentationCount += 1
            presented.signal()
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let taskA = Task {
            try await handler.authenticatedContext(for: .init(secret: contextA.secret, provenance: .test, target: nil), context: contextA)
        }
        await activity.waitUntilSleepCount(1)
        let taskB = Task {
            try await handler.authenticatedContext(for: .init(secret: contextB.secret, provenance: .test, target: nil), context: contextB)
        }
        await activity.waitUntilSleepCount(2)
        taskB.cancel()
        _ = await taskB.result
        await activity.waitUntilSleepCount(3)
        activity.idleTime = 1
        activity.resumeAll()
        await presented.wait()
        #expect(presentationCount == 1)
        taskA.cancel()
        _ = await taskA.result
        #expect(handler.batchableRequests.isEmpty)
        #expect(contextA.cancellationCount == 1)
    }

    @Test func callerAndBatchCancellationAwaitTheSameContextCancellation() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 1)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let presented = TestSignal()
        var presentationCount = 0
        handler.setPendingRequestHandler {
            presentationCount += 1
            presented.signal()
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let cancellationGate = TestSignal()
        contextA.cancellationGate = cancellationGate
        let taskA = Task {
            try await handler.authenticatedContext(for: .init(secret: contextA.secret, provenance: .test, target: nil), context: contextA)
        }
        await contextA.waitUntilEvaluationStarts()
        activity.idleTime = 0
        taskA.cancel()
        await contextA.waitUntilCancellationStarts()
        let taskB = Task {
            try await handler.authenticatedContext(for: .init(secret: contextB.secret, provenance: .test, target: nil), context: contextB)
        }
        for _ in 0..<100 where handler.batchableRequests.flatMap({ $0 }).count < 2 {
            await Task.yield()
        }
        #expect(handler.batchableRequests.flatMap({ $0 }).count == 2)
        #expect(activity.sleepCount == 0)
        #expect(contextA.cancellationCount == 1)
        cancellationGate.signal()
        _ = await taskA.result
        await activity.waitUntilSleepCount(1)
        #expect(contextA.canceled)
        #expect(contextA.cancellationCount == 1)
        activity.idleTime = 1
        activity.resumeAll()
        await presented.wait()
        #expect(presentationCount == 1)
        taskB.cancel()
        _ = await taskB.result
        #expect(handler.batchableRequests.isEmpty)
        #expect(contextA.cancellationCount == 1)
    }

    @Test func authorizationDuringIndividualWaitReturnsWithoutAnotherEvaluation() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let request = SignatureRequest(secret: context.secret, provenance: .test, target: nil)
        let task = Task { try await handler.authenticatedContext(for: request, context: context) }
        await activity.waitUntilSleepCount(1)
        let granted = AuthenticationContext(secret: context.secret, requests: [request])
        handler.recordAuthenticatedContext(granted)
        activity.resumeAll()
        let result = try await task.value
        #expect((result as? AuthenticationContext) === granted)
        #expect(!context.evaluationStarted)
        #expect(handler.batchableRequests.isEmpty)
    }

    @Test func authorizationDuringPendingWaitReturnsAndRemainingRequestPresents() async throws {
        let activity = ControlledKeyboardActivity(idleTime: 0)
        let handler = AuthenticationHandler(keyboardIdleWaiter: activity.waiter)
        let presented = TestSignal()
        var presentationCount = 0
        handler.setPendingRequestHandler {
            presentationCount += 1
            presented.signal()
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let requestA = SignatureRequest(secret: contextA.secret, provenance: .test, target: nil)
        let requestB = SignatureRequest(secret: contextB.secret, provenance: .test, target: nil)
        let taskA = Task { try await handler.authenticatedContext(for: requestA, context: contextA) }
        await activity.waitUntilSleepCount(1)
        let taskB = Task { try await handler.authenticatedContext(for: requestB, context: contextB) }
        await activity.waitUntilSleepCount(2)
        let granted = AuthenticationContext(secret: contextB.secret, requests: [requestB])
        handler.recordAuthenticatedContext(granted)
        #expect(Set(handler.batchableRequests.flatMap { $0 }.map(\.id)) == Set([requestA.id]))
        activity.resumeAll()
        let result = try await taskB.value
        #expect((result as? AuthenticationContext) === granted)
        #expect(presentationCount == 0)
        await activity.waitUntilSleepCount(3)
        activity.idleTime = 1
        activity.resumeAll()
        await presented.wait()
        #expect(presentationCount == 1)
        #expect(Set(handler.batchableRequests.flatMap { $0 }.map(\.id)) == Set([requestA.id]))
        taskA.cancel()
        _ = await taskA.result
        #expect(handler.batchableRequests.isEmpty)
    }

}

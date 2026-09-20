import Testing
import Foundation
import LocalAuthentication
import SecretKit
import SecretAgentKit
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
    private(set) var evaluationResult: Bool? = nil

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
    

    func evaluate() async throws -> Bool {
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
        assert(!canceled)
        assert(evaluationResult == nil)
        canceled = true
    }


}

@MainActor @Suite struct AuthenticationHandlerTests {

    let handler = AuthenticationHandler()

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
        handler.setPendingRequestHandler {
            calledPresentPending = true
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        Task {
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        Task {
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
        }
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == nil)
        await Task.yield()
        #expect(contextA.canceled)
        #expect(calledPresentPending)
    }

    @Test func authRequiredDoesNotBlockNoAuthRequired() async throws {
        var calledPresentPending = false
        handler.setPendingRequestHandler {
            calledPresentPending = true
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(10)))
        let contextB = TestContext(authenticationRequirement: .notRequired, testEvaluationResult: true)
        Task {
            Task {
                _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
            }
            _ = try? await handler.authenticatedContext(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == true)
        await Task.yield()
        #expect(!contextA.canceled)
        #expect(!calledPresentPending)
    }

    @Test func batchDoesNotBlockNoAuthRequired() async throws {
//        var calledPresentPending = false
//        handler.setPendingRequestHandler {
//            calledPresentPending = true
//        }
//        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticatedContext(for: .init(secret: .init(context.secret), provenance: .test, target: nil), context: context)
//        #expect(context.evaluationResult == true)
//        let second = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticatedContext(for: .init(secret: .init(second.secret), provenance: .test, target: nil), context: second)
//        #expect(context.evaluationResult == true)
//        #expect(second.evaluationResult == true)
//        #expect(!calledPresentPending)
    }

    @Test func batchDoesNotRequestApproval() async throws {
//        var calledPresentPending = false
//        handler.setPendingRequestHandler {
//            calledPresentPending = true
//        }
//        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticatedContext(for: .init(secret: .init(context.secret), provenance: .test, target: nil), context: context)
//        #expect(context.evaluationResult == true)
//        let second = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticatedContext(for: .init(secret: .init(second.secret), provenance: .test, target: nil), context: second)
//        #expect(context.evaluationResult == true)
//        #expect(second.evaluationResult == true)
//        #expect(!calledPresentPending)
    }

    @Test func batching() async throws {

    }

}

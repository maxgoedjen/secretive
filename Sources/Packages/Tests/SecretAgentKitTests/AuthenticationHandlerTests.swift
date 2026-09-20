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

extension AnySecret {

    static var testNoAuth: Self {
        AnySecret(TestSecret(attributes: .init(keyType: .ecdsa256, authentication: .notRequired)))
    }

    static var testAuth: Self {
        AnySecret(TestSecret(attributes: .init(keyType: .ecdsa256, authentication: .presenceRequired)))
    }
}

@MainActor @Suite struct AuthenticationHandlerTests {

    let handler = AuthenticationHandler()

    private func createContext() -> any AuthenticationContextProtocol {
        TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.zero))
    }

    @Test func singleImmediatelyRequests() async throws {
        var calledBatch = false
        handler.setPendingRequestHandler {
            calledBatch = true
        }
        let context = try await handler.authenticatedContext(for: .init(secret: .testAuth, provenance: .test, target: nil), createContext: createContext) as? TestContext
        #expect(context?.evaluationResult == true)
        #expect(!calledBatch)
    }

    @Test func sequentialRequestsDoNotBlock() async throws {
        var calledBatch = false
        handler.setPendingRequestHandler {
            calledBatch = true
        }
        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
        let context = try await handler.authenticatedContext(for: .init(secret: .testAuth, provenance: .test, target: nil), createContext: createContext) as? TestContext
        #expect(context.evaluationResult == true)
        let second = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
        _ = try await handler.authenticate(for: .init(secret: .init(second.secret), provenance: .test, target: nil), context: second)
        #expect(context.evaluationResult == true)
        #expect(second.evaluationResult == true)
        #expect(!calledBatch)
    }

    @Test func secondRetractsAndPresentsBatch() async throws {
        var calledBatch = false
        handler.setPendingRequestHandler {
            calledBatch = true
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        let contextB = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true)
        Task {
            _ = try? await handler.authenticate(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        Task {
            _ = try? await handler.authenticate(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
        }
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == nil)
        await Task.yield()
        #expect(contextA.canceled)
        #expect(calledBatch)
    }

    @Test func authRequiredDoesNotBlockNoAuthRequired() async throws {
        var calledBatch = false
        handler.setPendingRequestHandler {
            calledBatch = true
        }
        let contextA = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(10)))
        let contextB = TestContext(authenticationRequirement: .notRequired, testEvaluationResult: true)
        Task {
            Task {
                _ = try? await handler.authenticate(for: .init(secret: .init(contextB.secret), provenance: .test, target: nil), context: contextB)
            }
            _ = try? await handler.authenticate(for: .init(secret: .init(contextA.secret), provenance: .test, target: nil), context: contextA)
        }
        #expect(contextA.evaluationResult == nil)
        #expect(contextB.evaluationResult == true)
        await Task.yield()
        #expect(!contextA.canceled)
        #expect(!calledBatch)
    }

    @Test func batchDoesNotBlockNoAuthRequired() async throws {
//        var calledBatch = false
//        handler.setPendingRequestHandler {
//            calledBatch = true
//        }
//        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticate(for: .init(secret: .init(context.secret), provenance: .test, target: nil), context: context)
//        #expect(context.evaluationResult == true)
//        let second = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticate(for: .init(secret: .init(second.secret), provenance: .test, target: nil), context: second)
//        #expect(context.evaluationResult == true)
//        #expect(second.evaluationResult == true)
//        #expect(!calledBatch)
    }

    @Test func batchDoesNotRequestApproval() async throws {
//        var calledBatch = false
//        handler.setPendingRequestHandler {
//            calledBatch = true
//        }
//        let context = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticate(for: .init(secret: .init(context.secret), provenance: .test, target: nil), context: context)
//        #expect(context.evaluationResult == true)
//        let second = TestContext(authenticationRequirement: .presenceRequired, testEvaluationResult: true, approval: .duration(.milliseconds(1)))
//        _ = try await handler.authenticate(for: .init(secret: .init(second.secret), provenance: .test, target: nil), context: second)
//        #expect(context.evaluationResult == true)
//        #expect(second.evaluationResult == true)
//        #expect(!calledBatch)
    }

    @Test func batching() async throws {

    }

}

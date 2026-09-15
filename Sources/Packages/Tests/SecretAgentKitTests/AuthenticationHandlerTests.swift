import Testing
import Foundation
import LocalAuthentication
import SecretKit
import SecretAgentKit

public struct TestSecret: Secret {

    public let id: UUID
    public let name: String
    public let publicKey: Data
    public var attributes: Attributes

}

@MainActor final class TestContext: AuthenticationContextProtocol, Sendable {

    let id = UUID()
    private var testEvaluationResult: Bool

    var evaluated: Bool
    var canceled: Bool
    var evaluationResult: Bool

    let secret: AnySecret
    let laContext: LAContext? = nil


    init(authenticationRequirement: AuthenticationRequirement, testEvaluationResult: Bool) {
        self.evaluated = false
        self.canceled = false
        self.testEvaluationResult = testEvaluationResult
        self.secret = AnySecret(TestSecret(id: UUID(), name: "Test Secret", publicKey: Data(), attributes: .init(keyType: .ecdsa256, authentication: authenticationRequirement)))
    }

    nonisolated func valid(for request: SecretKit.SignatureRequest) -> Bool {
        true
    }
    

    func evaluate() async throws -> Bool {
        evaluationResult = testEvaluationResult
        evaluated = true
    }
    
    func cancel() async {
        canceled = true
    }
    


}

@MainActor @Suite struct AuthenticationHandlerTests {

    let handler = AuthenticationHandler()

    @Test func singleImmediatelyRequests() async throws {
        var calledBatch = false
        handler.setBatchAuthHandler {
            calledBatch = true
        }
//        handler.waitForAuthentication(for: .init(secret: <#T##AnySecret#>, provenance: ., target: <#T##SigningRequestTarget?#>))
        #expect(!calledBatch)
    }

    @Test func secondRetractsAndPresentsBatch() async throws {

    }

    @Test func authRequiredDoesntBlockNoAuthRequired() async throws {

    }

    @Test func batching() async throws {

    }

    @Test func batching() async throws {

    }

}

import Testing
@testable import SecretKit

@Suite struct SecretiveCLITests {

    @Test func parsesCreateSecretCommand() throws {
        let invocation = try SecretiveCLIInvocation.parse(arguments: [
            "create-secret",
            "--name", "Fleet Deploy Key",
            "--protection-level", "1",
            "--key-type", "ecdsa-256",
            "--key-attribution", "deploy@example.com",
        ])

        guard case let .createSecret(command) = invocation else {
            Issue.record("Expected create-secret invocation")
            return
        }

        #expect(command.name == "Fleet Deploy Key")
        #expect(command.protectionLevel == .requireAuthentication)
        #expect(command.attributes.authentication == .presenceRequired)
        #expect(command.keyType == .ecdsa256)
        #expect(command.keyAttribution == "deploy@example.com")
    }

    @Test func parsesNotificationProtectionLevel() throws {
        let invocation = try SecretiveCLIInvocation.parse(arguments: [
            "create-secret",
            "--name", "Fleet Deploy Key",
            "--protection-level", "2",
            "--key-type", "mldsa-65",
        ])

        guard case let .createSecret(command) = invocation else {
            Issue.record("Expected create-secret invocation")
            return
        }

        #expect(command.protectionLevel == .notification)
        #expect(command.attributes.authentication == .notRequired)
        #expect(command.keyType == .mldsa65)
        #expect(command.keyAttribution == nil)
    }

    @Test func usesDefaultsWhenOnlyNameIsProvided() throws {
        let invocation = try SecretiveCLIInvocation.parse(arguments: [
            "create-secret",
            "--name", "Fleet Deploy Key",
        ])

        guard case let .createSecret(command) = invocation else {
            Issue.record("Expected create-secret invocation")
            return
        }

        #expect(command.protectionLevel == .requireAuthentication)
        #expect(command.attributes.authentication == .presenceRequired)
        #expect(command.keyType == .ecdsa256)
        #expect(command.keyAttribution == nil)
    }

    @Test func supportsCurrentBiometricsAndCommonKeyTypeTypo() throws {
        let invocation = try SecretiveCLIInvocation.parse(arguments: [
            "create-secret",
            "--name", "Fleet Deploy Key",
            "--protection-level", "3",
            "--key-type", "edcsa-256",
        ])

        guard case let .createSecret(command) = invocation else {
            Issue.record("Expected create-secret invocation")
            return
        }

        #expect(command.protectionLevel == .currentBiometrics)
        #expect(command.attributes.authentication == .biometryCurrent)
        #expect(command.keyType == .ecdsa256)
    }

    @Test func rejectsInvalidProtectionLevel() throws {
        #expect(throws: SecretiveCLIInvocation.ParseError.invalidProtectionLevel("4")) {
            try SecretiveCLIInvocation.parse(arguments: [
                "create-secret",
                "--name", "Fleet Deploy Key",
                "--protection-level", "4",
                "--key-type", "ecdsa-256",
            ])
        }
    }

    @Test func ignoresLaunchServicesProcessSerialNumber() throws {
        let invocation = try SecretiveCLIInvocation.parse(arguments: ["-psn_0_12345"])
        #expect(invocation == .none)
    }

    @Test func parsesAgentCommands() throws {
        #expect(try SecretiveCLIInvocation.parse(arguments: ["list-secrets"]) == .listSecrets)
        #expect(try SecretiveCLIInvocation.parse(arguments: ["install-agent"]) == .installAgent)
        #expect(try SecretiveCLIInvocation.parse(arguments: ["uninstall-agent"]) == .uninstallAgent)
        #expect(try SecretiveCLIInvocation.parse(arguments: ["agent-status"]) == .agentStatus)
        #expect(try SecretiveCLIInvocation.parse(arguments: ["socket-path"]) == .socketPath)
    }

    @Test func parsesPrintIntegrationCommand() throws {
        let invocation = try SecretiveCLIInvocation.parse(arguments: [
            "print-integration",
            "--tool", "ssh",
        ])

        guard case let .printIntegration(command) = invocation else {
            Issue.record("Expected print-integration invocation")
            return
        }

        #expect(command.tool == .ssh)
    }

    @Test func rejectsInvalidIntegrationTool() throws {
        #expect(throws: SecretiveCLIInvocation.ParseError.invalidIntegrationTool("powershell")) {
            try SecretiveCLIInvocation.parse(arguments: [
                "print-integration",
                "--tool", "powershell",
            ])
        }
    }

    @Test func parsesSecretSelectorCommands() throws {
        let byID = try SecretiveCLIInvocation.parse(arguments: [
            "public-key-path",
            "--id", "1234",
        ])
        guard case let .publicKeyPath(selectorByID) = byID else {
            Issue.record("Expected public-key-path invocation")
            return
        }
        #expect(selectorByID.id == "1234")
        #expect(selectorByID.name == nil)

        let byName = try SecretiveCLIInvocation.parse(arguments: [
            "export-public-key",
            "--name", "Fleet Deploy Key",
        ])
        guard case let .exportPublicKey(selectorByName) = byName else {
            Issue.record("Expected export-public-key invocation")
            return
        }
        #expect(selectorByName.name == "Fleet Deploy Key")
        #expect(selectorByName.id == nil)
    }

    @Test func rejectsMissingSecretSelector() throws {
        #expect(throws: SecretiveCLIInvocation.ParseError.missingSecretSelector) {
            try SecretiveCLIInvocation.parse(arguments: [
                "public-key-path",
            ])
        }
    }

    @Test func rejectsConflictingSecretSelectors() throws {
        #expect(throws: SecretiveCLIInvocation.ParseError.conflictingOptions("--id", "--name")) {
            try SecretiveCLIInvocation.parse(arguments: [
                "export-public-key",
                "--name", "Fleet Deploy Key",
                "--id", "1234",
            ])
        }
    }
}

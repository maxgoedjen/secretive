import Testing
@testable import SecretiveCLI

// MARK: - Command Router Tests

@Suite("CommandRouter") @MainActor
struct CommandRouterTests {
    // MARK: - value(for:in:)

    @Test("Extracts flag value with space separator")
    func flagValueSpaceSeparator() {
        let args = ["key", "list", "--store", "Secure Enclave", "--json"]
        #expect(CommandRouter.value(for: "--store", in: args) == "Secure Enclave")
    }

    @Test("Extracts flag value with equals separator")
    func flagValueEqualsSeparator() {
        let args = ["key", "create", "--type=mldsa-65"]
        #expect(CommandRouter.value(for: "--type", in: args) == "mldsa-65")
    }

    @Test("Returns nil for absent flag")
    func missingFlagReturnsNil() {
        let args = ["key", "list"]
        #expect(CommandRouter.value(for: "--store", in: args) == nil)
    }

    @Test("Returns nil when flag is last element with no value")
    func flagAtEnd() {
        let args = ["key", "list", "--store"]
        #expect(CommandRouter.value(for: "--store", in: args) == nil)
    }

    @Test("Returns first value when flag appears multiple times")
    func flagAppearsMultipleTimes() {
        let args = ["--store", "first", "--store", "second"]
        #expect(CommandRouter.value(for: "--store", in: args) == "first")
    }

    @Test("Equals form does not consume the following token")
    func equalsFormNoConsume() {
        let args = ["--type=ecdsa-256", "next-token"]
        #expect(CommandRouter.value(for: "--type", in: args) == "ecdsa-256")
        #expect(CommandRouter.positional(args: args) == ["next-token"])
    }

    // MARK: - flag(_:in:)

    @Test("Detects present boolean flag")
    func booleanFlagPresent() {
        let args = ["key", "list", "--json"]
        #expect(CommandRouter.flag("--json", in: args) == true)
    }

    @Test("Returns false for absent boolean flag")
    func booleanFlagAbsent() {
        let args = ["key", "list"]
        #expect(CommandRouter.flag("--json", in: args) == false)
    }

    @Test("Short flag -h detected")
    func shortFlagDetected() {
        let args = ["key", "-h"]
        #expect(CommandRouter.flag("-h", in: args) == true)
    }

    // MARK: - positional(args:)

    @Test("Extracts single positional argument")
    func singlePositional() {
        let args = ["show", "github", "--json"]
        #expect(CommandRouter.positional(args: args) == ["show", "github"])
    }

    @Test("Extracts positional after flag-value pair")
    func positionalAfterFlagValue() {
        let args = ["--store", "Secure Enclave", "github"]
        #expect(CommandRouter.positional(args: args) == ["github"])
    }

    @Test("Returns empty for all-flag args")
    func allFlags() {
        let args = ["--json", "--force"]
        #expect(CommandRouter.positional(args: args).isEmpty)
    }

    @Test("Handles equals-form flags correctly (no next-skip)")
    func equalsFormDoesNotSkipNext() {
        let args = ["--type=ecdsa-256", "mykey"]
        #expect(CommandRouter.positional(args: args) == ["mykey"])
    }

    @Test("Empty args returns empty positionals")
    func emptyArgs() {
        #expect(CommandRouter.positional(args: []).isEmpty)
    }

    // MARK: - removeFirst(_:from:)

    @Test("removeFirst removes only the first occurrence")
    func removeFirstOnlyFirst() {
        let result = CommandRouter.removeFirst("key", from: ["key", "list", "key"])
        #expect(result == ["list", "key"])
    }

    @Test("removeFirst is a no-op when target is absent")
    func removeFirstMissingTarget() {
        let args = ["list", "--json"]
        #expect(CommandRouter.removeFirst("key", from: args) == args)
    }

    @Test("removeFirst on empty array returns empty")
    func removeFirstEmptyArray() {
        #expect(CommandRouter.removeFirst("key", from: []) == [])
    }

    // MARK: - levenshtein(a:b:)

    @Test("Levenshtein: exact match = 0")
    func levenshteinExactMatch() {
        #expect(CommandRouter.levenshtein(a: "key", b: "key") == 0)
    }

    @Test("Levenshtein: one deletion = 1")
    func levenshteinOneDeletion() {
        #expect(CommandRouter.levenshtein(a: "ky", b: "key") == 1)
    }

    @Test("Levenshtein: one insertion = 1")
    func levenshteinOneInsertion() {
        #expect(CommandRouter.levenshtein(a: "keys", b: "key") == 1)
    }

    @Test("Levenshtein: one substitution = 1")
    func levenshteinOneSubstitution() {
        #expect(CommandRouter.levenshtein(a: "kez", b: "key") == 1)
    }

    @Test("Levenshtein: completely different strings")
    func levenshteinFarStrings() {
        #expect(CommandRouter.levenshtein(a: "xyz", b: "key") == 3)
    }

    @Test("Levenshtein: empty vs non-empty = length")
    func levenshteinEmptyString() {
        #expect(CommandRouter.levenshtein(a: "", b: "key") == 3)
        #expect(CommandRouter.levenshtein(a: "key", b: "") == 3)
    }

    // MARK: - suggest(command:candidates:)

    @Test("suggest returns nil for strings beyond edit-distance threshold")
    func suggestNoMatchFarString() {
        #expect(CommandRouter.suggest(command: "xyz123", candidates: ["key", "cert", "agent"]) == nil)
    }

    @Test("suggest returns closest candidate within threshold")
    func suggestBestMatch() {
        #expect(CommandRouter.suggest(command: "kye", candidates: ["key", "cert", "agent"]) == "key")
    }

    @Test("suggest handles typo in 'cert'")
    func suggestCertTypo() {
        #expect(CommandRouter.suggest(command: "cret", candidates: ["key", "cert", "agent"]) == "cert")
    }

    @Test("suggest returns nil when no candidates")
    func suggestNoCandidates() {
        #expect(CommandRouter.suggest(command: "key", candidates: []) == nil)
    }
}

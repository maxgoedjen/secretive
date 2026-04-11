import Foundation

public enum SecretiveCLIInvocation: Sendable, Equatable {
    case none
    case help
    case createSecret(CreateSecret)

    public static func parse(arguments: [String]) throws -> Self {
        let filtered = arguments.filter { !$0.hasPrefix("-psn_") }
        guard let subcommand = filtered.first else {
            return .none
        }

        switch subcommand {
        case "help", "--help", "-h":
            return .help
        case "create-secret":
            return .createSecret(try CreateSecret.parse(arguments: Array(filtered.dropFirst())))
        default:
            return .none
        }
    }

    public static var usage: String {
        """
        Usage:
          Secretive create-secret --name <name> [--protection-level <1|2|3>] [--key-type <\(CreateSecret.supportedKeyTypes.map(\.description).joined(separator: "|"))>] [--key-attribution <value>]

        Protection levels:
          1  require authentication
          2  notification
          3  current biometrics

        Defaults:
          protection-level: 1
          key-type: ecdsa-256
          key-attribution: omitted
        """
    }

    public struct CreateSecret: Sendable, Equatable {
        public let name: String
        public let protectionLevel: ProtectionLevel
        public let keyType: KeyType
        public let keyAttribution: String?

        public var attributes: Attributes {
            Attributes(
                keyType: keyType,
                authentication: protectionLevel.authenticationRequirement,
                publicKeyAttribution: keyAttribution
            )
        }

        public static let supportedKeyTypes: [KeyType] = [
            .ecdsa256,
            .mldsa65,
            .mldsa87,
        ]

        public static let defaultProtectionLevel: ProtectionLevel = .requireAuthentication
        public static let defaultKeyType: KeyType = .ecdsa256

        static func parse(arguments: [String]) throws -> Self {
            var name: String?
            var protectionLevel: ProtectionLevel?
            var keyType: KeyType?
            var keyAttribution: String?

            var index = 0
            while index < arguments.count {
                let argument = arguments[index]
                switch argument {
                case "--help", "-h":
                    throw ParseError.helpRequested
                case "--name":
                    name = try value(after: argument, arguments: arguments, index: &index)
                case "--protection-level":
                    let rawValue = try value(after: argument, arguments: arguments, index: &index)
                    guard let parsedLevel = ProtectionLevel(rawValue: rawValue) else {
                        throw ParseError.invalidProtectionLevel(rawValue)
                    }
                    protectionLevel = parsedLevel
                case "--key-type":
                    let rawValue = try value(after: argument, arguments: arguments, index: &index)
                    guard let parsedType = KeyType(secretiveCLIValue: rawValue),
                          supportedKeyTypes.contains(parsedType) else {
                        throw ParseError.invalidKeyType(rawValue)
                    }
                    keyType = parsedType
                case "--key-attribution":
                    let rawValue = try value(after: argument, arguments: arguments, index: &index)
                    keyAttribution = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : rawValue
                default:
                    throw ParseError.unexpectedArgument(argument)
                }
                index += 1
            }

            guard let name else {
                throw ParseError.missingRequiredOption("--name")
            }
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ParseError.emptyValue("--name")
            }
            return Self(
                name: name,
                protectionLevel: protectionLevel ?? defaultProtectionLevel,
                keyType: keyType ?? defaultKeyType,
                keyAttribution: keyAttribution
            )
        }

        private static func value(after option: String, arguments: [String], index: inout Int) throws -> String {
            let valueIndex = index + 1
            guard arguments.indices.contains(valueIndex) else {
                throw ParseError.missingValue(option)
            }
            index = valueIndex
            return arguments[valueIndex]
        }
    }

    public enum ProtectionLevel: String, Sendable, Equatable, CaseIterable {
        case requireAuthentication = "1"
        case notification = "2"
        case currentBiometrics = "3"

        public var authenticationRequirement: AuthenticationRequirement {
            switch self {
            case .requireAuthentication:
                .presenceRequired
            case .notification:
                .notRequired
            case .currentBiometrics:
                .biometryCurrent
            }
        }

        public var summary: String {
            switch self {
            case .requireAuthentication:
                "require authentication"
            case .notification:
                "notification"
            case .currentBiometrics:
                "current biometrics"
            }
        }
    }

    public enum ParseError: Error, LocalizedError, Equatable {
        case helpRequested
        case missingValue(String)
        case missingRequiredOption(String)
        case emptyValue(String)
        case invalidProtectionLevel(String)
        case invalidKeyType(String)
        case unexpectedArgument(String)

        public var errorDescription: String? {
            let validKeyTypes = CreateSecret.supportedKeyTypes.map(\.description).joined(separator: ", ")
            switch self {
            case .helpRequested:
                return SecretiveCLIInvocation.usage
            case let .missingValue(option):
                return "Missing value for \(option)."
            case let .missingRequiredOption(option):
                return "Missing required option \(option)."
            case let .emptyValue(option):
                return "Option \(option) cannot be empty."
            case let .invalidProtectionLevel(value):
                return "Invalid protection level '\(value)'. Valid values: 1, 2, 3."
            case let .invalidKeyType(value):
                return "Invalid key type '\(value)'. Valid values: \(validKeyTypes)."
            case let .unexpectedArgument(argument):
                return "Unexpected argument '\(argument)'."
            }
        }
    }
}

public extension KeyType {
    init?(secretiveCLIValue value: String) {
        let normalized = value.lowercased().filter { !$0.isWhitespace && $0 != "-" && $0 != "_" }
        switch normalized {
        case "ecdsa256", "edcsa256":
            self = .ecdsa256
        case "mldsa65":
            self = .mldsa65
        case "mldsa87":
            self = .mldsa87
        default:
            return nil
        }
    }
}

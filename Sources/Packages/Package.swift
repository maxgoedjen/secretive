// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecretivePackages",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SecretKit",
            targets: ["SecretKit"]),
        .library(
            name: "SecureEnclaveSecretKit",
            targets: ["SecureEnclaveSecretKit"]),
        .library(
            name: "SmartCardSecretKit",
            targets: ["SmartCardSecretKit"]),
        .library(
            name: "SecretAgentKit",
            targets: ["SecretAgentKit"]),
        .library(
            name: "Common",
            targets: ["Common"]),
        .library(
            name: "Brief",
            targets: ["Brief"]),
        .library(
            name: "XPCWrappers",
            targets: ["XPCWrappers"]),
        .library(
            name: "SSHProtocolKit",
            targets: ["SSHProtocolKit"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SecretKit",
            dependencies: [],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecretAgentKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["SecretKit", "SSHProtocolKit", "Common"],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "SecretAgentKitTests",
            dependencies: ["SecretAgentKit"],
        ),
        .target(
            name: "SSHProtocolKit",
            dependencies: ["SecretKit"],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "SSHProtocolKitTests",
            dependencies: ["SSHProtocolKit"],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "Common",
            dependencies: ["SSHProtocolKit", "SecretKit"],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "Brief",
            dependencies: ["XPCWrappers", "SSHProtocolKit"],
            resources: [localization],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "BriefTests",
            dependencies: ["Brief"],
        ),
        .target(
            name: "XPCWrappers",
            swiftSettings: swiftSettings,
        ),
    ]
)

var localization: Resource {
    .process("../../Resources/Localizable.xcstrings")
}

var swiftSettings: [PackageDescription.SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        .treatAllWarnings(as: .error),
        .strictMemorySafety()
    ]
}

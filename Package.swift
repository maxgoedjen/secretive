// swift-tools-version:6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

/// This is basically the same package as `Sources/Packages/Package.swift`, but thinned slightly.
/// Ideally this would be the same package, but SPM requires it to be at the root of the project,
/// and Xcode does _not_ like that, so they're separate.
let package = Package(
    name: "SecretKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SecretKit",
            targets: ["SecretKit"],
        ),
        .library(
            name: "SecureEnclaveSecretKit",
            targets: ["SecureEnclaveSecretKit"],
        ),
        .library(
            name: "SmartCardSecretKit",
            targets: ["SmartCardSecretKit"],
        ),
        .library(
            name: "CertificateKit",
            targets: ["CertificateKit"],
        ),
        .library(
            name: "SSHProtocolKit",
            targets: ["SSHProtocolKit"],
        ),
        .library(
            name: "Formatters",
            targets: ["Formatters"],
        ),
        .executable(
            name: "secretive",
            targets: ["SecretiveCLI"],
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SecretKit",
            dependencies: [],
            path: "Sources/Packages/Sources/SecretKit",
            swiftSettings: swiftSettings,
        ),
        // SecretKitTests uses XCTest (unavailable in CLT swift-test context).
        // Run via: xcrun xcodebuild -project Sources/Secretive.xcodeproj -scheme PackageTests test
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            path: "Sources/Packages/Sources/SecureEnclaveSecretKit",
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"],
            path: "Sources/Packages/Sources/SmartCardSecretKit",
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "CertificateKit",
            dependencies: ["SecretKit", "Formatters"],
            path: "Sources/Packages/Sources/CertificateKit",
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "SSHProtocolKit",
            dependencies: ["SecretKit", "CertificateKit"],
            path: "Sources/Packages/Sources/SSHProtocolKit",
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "SSHProtocolKitTests",
            dependencies: ["SSHProtocolKit"],
            path: "Sources/Packages/Tests/SSHProtocolKitTests",
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "Formatters",
            dependencies: [],
            path: "Sources/Packages/Sources/Formatters",
            swiftSettings: swiftSettings,
        ),

        // MARK: - CLI

        .executableTarget(
            name: "SecretiveCLI",
            dependencies: [
                "SecretKit",
                "SecureEnclaveSecretKit",
                "SmartCardSecretKit",
                "SSHProtocolKit",
                "CertificateKit",
                "Formatters",
            ],
            path: "Sources/CLI",
            exclude: ["Info.plist", "Secretive.entitlements"],
            swiftSettings: swiftSettings + cliSwiftSettings,
        ),
        .testTarget(
            name: "SecretiveCLITests",
            dependencies: ["SecretiveCLI"],
            path: "Tests/CLITests",
            resources: [.copy("Snapshots")],
            swiftSettings: swiftSettings,
        ),
    ],
)

var swiftSettings: [PackageDescription.SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        .define("CLI_SPM_BUILD"),
        // This freaks out Xcode in a dependency context.
        // .treatAllWarnings(as: .error),
    ]
}

/// Additional Swift settings applied only to the CLI executable target.
/// SE-0466: enables default @MainActor isolation for the executable entry point,
/// which matches the isolation requirements of SecureEnclave.Store and SmartCard.Store.
/// MUST NOT be applied to library targets (breaks consumer isolation boundaries — constraint S3).
var cliSwiftSettings: [PackageDescription.SwiftSetting] {
    [
        .defaultIsolation(MainActor.self),
    ]
}

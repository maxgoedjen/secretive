// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// This is basically the same package as `Sources/Packages/Package.swift`, but thinned slightly.
// Ideally this would be the same package, but SPM requires it to be at the root of the project,
// and Xcode does _not_ like that, so they're separate.
let package = Package(
    name: "SecretKit",
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
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SecretKit",
            dependencies: [],
            path: "Sources/Packages/Sources/SecretKit",
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            path: "Sources/Packages/Tests/SecretKitTests",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            path: "Sources/Packages/Sources/SecureEnclaveSecretKit",
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"],
            path: "Sources/Packages/Sources/SmartCardSecretKit",
            resources: [localization],
            swiftSettings: swiftSettings
        ),
    ]
)

var localization: Resource {
    .process("../../Resources/Localizable.xcstrings")
}

var swiftSettings: [PackageDescription.SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        // This freaks out Xcode in a dependency context.
        // .treatAllWarnings(as: .error),
    ]
}

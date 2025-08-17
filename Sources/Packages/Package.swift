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
            name: "SecretAgentKitHeaders",
            targets: ["SecretAgentKitHeaders"]),
        .library(
            name: "Brief",
            targets: ["Brief"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SecretKit",
            dependencies: [],
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"],
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["SecretKit", "SecretAgentKitHeaders"],
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .systemLibrary(
            name: "SecretAgentKitHeaders"
        ),
        .testTarget(
            name: "SecretAgentKitTests",
            dependencies: ["SecretAgentKit"])
        ,
        .target(
            name: "Brief",
            dependencies: [],
            resources: [localization],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BriefTests",
            dependencies: ["Brief"]
        ),
    ]
)

var localization: Resource {
    .process("../../Localizable.xcstrings")
}

var swiftSettings: [PackageDescription.SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        .unsafeFlags(["-warnings-as-errors"]),
    ]
}

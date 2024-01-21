// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecretivePackages",
    platforms: [
        .macOS(.v12)
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
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency"), .unsafeFlags(["-warnings-as-errors"])]
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency"), .unsafeFlags(["-warnings-as-errors"])]
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency"), .unsafeFlags(["-warnings-as-errors"])]
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["SecretKit", "SecretAgentKitHeaders"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency"), .unsafeFlags(["-warnings-as-errors"])]
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
            dependencies: []
        ),
        .testTarget(
            name: "BriefTests",
            dependencies: ["Brief"]
        ),
    ]
)

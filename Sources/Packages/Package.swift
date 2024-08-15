// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let secretiveDefaults: [PackageDescription.SwiftSetting]? = [.swiftLanguageMode(.v6), .unsafeFlags(["-warnings-as-errors"])]

let package = Package(
    name: "SecretivePackages",
    platforms: [
        .macOS(.v13)
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
            swiftSettings: secretiveDefaults
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            swiftSettings: secretiveDefaults
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            swiftSettings: secretiveDefaults
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"],
            swiftSettings: secretiveDefaults
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["SecretKit", "SecretAgentKitHeaders"],
            swiftSettings: secretiveDefaults
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


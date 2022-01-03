// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecretivePackages",
    platforms: [
        .macOS(.v11)
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
            name: "SecretAgentKitProtocol",
            targets: ["SecretAgentKitProtocol"]),
        .library(
            name: "Brief",
            targets: ["Brief"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SecretKit"
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"]
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"]
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["SecretKit"]
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["SecretKit", "SecretAgentKitHeaders", "SecretAgentKitProtocol"]
        ),
        .systemLibrary(
            name: "SecretAgentKitHeaders"
        ),
        .target(
            name: "SecretAgentKitProtocol"
        ),
        .testTarget(
            name: "SecretAgentKitTests",
            dependencies: ["SecretAgentKit"])
        ,
        .target(
            name: "Brief"
        ),
        .testTarget(
            name: "BriefTests",
            dependencies: ["Brief"]
        ),
    ]
)

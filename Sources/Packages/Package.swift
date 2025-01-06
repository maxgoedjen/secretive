// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecretivePackages",
    platforms: [
        .macOS(.v15)
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
        .library(
            name: "Backports",
            targets: ["Backports"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Backports",
            dependencies: [],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecretKit",
            dependencies: ["Backports"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["Backports", "SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["SecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["Backports", "SecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["Backports", "SecretKit", "SecretAgentKitHeaders"],
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
            dependencies: ["Backports"]
        ),
        .testTarget(
            name: "BriefTests",
            dependencies: ["Brief"]
        ),
    ]
)

var swiftSettings: [PackageDescription.SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        .unsafeFlags(["-warnings-as-errors"])
    ]
}

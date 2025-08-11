// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SecretivePackages",
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
        .library(
            name: "Common",
            targets: ["Common"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SecretKit",
            dependencies: ["Common"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit", "SecureEnclaveSecretKit", "SmartCardSecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecureEnclaveSecretKit",
            dependencies: ["Common", "SecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SmartCardSecretKit",
            dependencies: ["Common", "SecretKit"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: ["Common", "SecretKit", "SecretAgentKitHeaders"],
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
            dependencies: ["Common"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BriefTests",
            dependencies: ["Brief"]
        ),
        .target(
            name: "Common",
            dependencies: [],
            swiftSettings: swiftSettings
        ),
    ]
)

var swiftSettings: [PackageDescription.SwiftSetting] {
    [
        .swiftLanguageMode(.v6),
        .unsafeFlags(["-warnings-as-errors"])
    ]
}

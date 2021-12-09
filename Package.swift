// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Secretive",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "SecretKit",
            targets: ["SecretKit"]),
        .library(
            name: "SecretAgentKit",
            targets: ["SecretKit"]),
        .library(
            name: "Brief",
            targets: ["Brief"]),
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "Secretive",
            dependencies: ["SecretKit", "Brief"],
            exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/Credits.rtf"),
                .process("Resources/InternetAccessPolicy.plist"),
                .process("Resources/Secretive.entitlements"),
            ],
            // https://forums.swift.org/t/swift-package-manager-use-of-info-plist-use-for-apps/6532/8
            linkerSettings: [.unsafeFlags( ["-sectcreate",
                                            "__TEXT",
                                            "__info_plist",
                                            "Sources/SecretAgent/Resources/Info.plist"])
                            ]
        ),
        .testTarget(
            name: "SecretiveTests",
            dependencies: ["Secretive"]),
        .executableTarget(
            name: "SecretAgent",
            dependencies: ["SecretAgentKit", "Brief"], exclude: ["Resources/Info.plist"],
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/InternetAccessPolicy.plist"),
                .process("Resources/SecretAgent.entitlements")
            ],
            // https://forums.swift.org/t/swift-package-manager-use-of-info-plist-use-for-apps/6532/8
            linkerSettings: [.unsafeFlags( ["-sectcreate",
                                            "__TEXT",
                                            "__info_plist",
                                            "Sources/TesTest    SecretAgent/Resources/Info.plist"])
                            ]
        ),
        .target(
            name: "SecretKit",
            dependencies: []
        ),
        .testTarget(
            name: "SecretKitTests",
            dependencies: ["SecretKit"]
        ),
        .target(
            name: "SecretAgentKit",
            dependencies: []
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

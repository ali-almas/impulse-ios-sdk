// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ImpulseSDK",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ImpulseSDK",
            targets: ["ImpulseSDK"]
        ),
    ],
    targets: [
        .target(name: "ImpulseSDK", path: "Sources/ImpulseSDK"),
        .testTarget(
            name: "ImpulseSDKTests",
            dependencies: ["ImpulseSDK"],
            path: "Tests/ImpulseSDKTests"
        ),
    ]
)

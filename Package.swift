// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "StateViewController",
    platforms: [
        .iOS(.v8),
        .tvOS(.v9)
    ],
    products: [
        .library(
            name: "StateViewController",
            targets: ["StateViewController"])
    ],
    targets: [
        .target(
            name: "StateViewController",
            dependencies: [])
    ]
)

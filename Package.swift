// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SenseLayer",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "SenseLayer", targets: ["SenseLayer"])
    ],
    targets: [
        .target(
            name: "SenseLayer",
            path: "Sources/SenseLayer"
        ),
        .testTarget(
            name: "SenseLayerTests",
            dependencies: ["SenseLayer"],
            path: "Tests/SenseLayerTests"
        )
    ]
)

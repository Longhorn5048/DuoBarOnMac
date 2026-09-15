// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DuoBarOnMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DuoBarOnMac", targets: ["DuoBarOnMac"])
    ],
    targets: [
        .executableTarget(
            name: "DuoBarOnMac",
            path: "Sources/DuoBarOnMac"
        ),
        .testTarget(
            name: "DuoBarOnMacTests",
            dependencies: ["DuoBarOnMac"],
            path: "Tests/DuoBarOnMacTests"
        )
    ]
)

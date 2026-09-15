// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DuoBarOnMac",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DuoBarOnMac", targets: ["DuoBarOnMac"])
    ],
    targets: [
        .executableTarget(
            name: "DuoBarOnMac",
            path: "Sources/DuoBarOnMac",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DuoBarOnMacTests",
            dependencies: ["DuoBarOnMac"],
            path: "Tests/DuoBarOnMacTests"
        )
    ]
)

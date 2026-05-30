// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftXLSX",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SwiftXLSX", targets: ["SwiftXLSX"]),
    ],
    targets: [
        .target(
            name: "SwiftXLSX",
            path: "Sources/SwiftXLSX"
        ),
        .testTarget(
            name: "SwiftXLSXTests",
            dependencies: ["SwiftXLSX"],
            path: "Tests/SwiftXLSXTests"
        ),
    ]
)

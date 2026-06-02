// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftXLSX",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SwiftXLSX", targets: ["SwiftXLSX"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
        .package(path: "../SwiftZIP"),
    ],
    targets: [
        .target(
            name: "SwiftXLSX",
            dependencies: [
                .product(name: "SwiftZIP", package: "SwiftZIP"),
            ],
            path: "Sources/SwiftXLSX"
        ),
        .testTarget(
            name: "SwiftXLSXTests",
            dependencies: ["SwiftXLSX"],
            path: "Tests/SwiftXLSXTests"
        ),
    ]
)

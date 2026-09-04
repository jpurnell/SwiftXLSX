// swift-tools-version: 6.2
// legibility:description: Pure-Swift library for generating and evaluating Excel (.xlsx) files.

import PackageDescription

let package = Package(
    name: "SwiftXLSX",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "SwiftXLSX", targets: ["SwiftXLSX"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
        .package(url: "https://github.com/jpurnell/SwiftZIP.git", from: "0.6.0"),
        .package(url: "https://github.com/jpurnell/SwiftExcelCore", exact: "0.1.0"),
    ],
    targets: [
        .target(
            name: "SwiftXLSX",
            dependencies: [
                .product(name: "SwiftZIP", package: "SwiftZIP"),
                .product(name: "SwiftExcelCore", package: "SwiftExcelCore"),
            ],
            path: "Sources/SwiftXLSX",
            resources: [.process("SwiftXLSX.docc")]
        ),
        .testTarget(
            name: "SwiftXLSXTests",
            dependencies: ["SwiftXLSX"],
            path: "Tests/SwiftXLSXTests"
        ),
    ]
)

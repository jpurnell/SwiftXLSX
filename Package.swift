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
        // The shared vocabulary, and deliberately not `exact:`. Three packages depend
        // on this one and SwiftPM must unify them on a single version — two
        // SwiftExcelCore versions would mean two `CellValue` types and nothing would
        // typecheck. `from:` lets it pick the highest that satisfies everyone; `exact:`
        // made the family unresolvable whenever Core moved ahead of one consumer.
        .package(url: "https://github.com/jpurnell/SwiftExcelCore", from: "0.6.0"),
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

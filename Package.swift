// swift-tools-version:5.9
// For reference only - use Xcode's UI to add these packages

import PackageDescription

let package = Package(
    name: "VizionGateway",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "VizionGateway",
            targets: ["VizionGateway"]
        ),
    ],
    dependencies: [
        // Add any external dependencies here
    ],
    targets: [
        .target(
            name: "VizionGateway",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "VizionGatewayTests",
            dependencies: ["VizionGateway"],
            path: "Tests"
        ),
    ],
    swiftLanguageVersions: [.v5]
) 
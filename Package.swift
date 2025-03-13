// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "VizionGateway",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "VizionGateway",
            targets: ["VizionGateway"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VizionGateway",
            dependencies: [],
            path: "Sources/VizionGateway"),
        .testTarget(
            name: "VizionGatewayTests",
            dependencies: ["VizionGateway"],
            path: "Tests/VizionGatewayTests"),
    ],
    swiftLanguageVersions: [.v5]
)

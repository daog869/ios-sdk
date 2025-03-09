// swift-tools-version:5.7
// For reference only - use Xcode's UI to add these packages

import PackageDescription

let package = Package(
    name: "VizionGateway",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        // Firebase dependencies
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.18.0")
    ],
    targets: [
        .target(
            name: "VizionGateway",
            dependencies: [
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk")
                // Do NOT add FirebaseFirestoreSwift as per your requirements
            ]
        )
    ]
) 
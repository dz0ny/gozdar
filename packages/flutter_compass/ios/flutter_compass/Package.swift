// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "flutter_compass",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-compass", targets: ["flutter_compass"]),
    ],
    targets: [
        .target(
            name: "flutter_compass",
            path: "Sources/flutter_compass"
        ),
    ]
)

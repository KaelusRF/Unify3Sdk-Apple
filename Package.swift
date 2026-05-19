// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Unify3Sdk",
    platforms: [
        .iOS("15.6"),
        .macOS("15.0")
    ],
    products: [
        .library(
            name: "Unify3Sdk",
            targets: [
                "Unify3Sdk",
                "Unify3Core"
            ]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Unify3Sdk",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.4/Unify3Sdk-0.1.4.xcframework.zip",
            checksum: "3857cfa796dcfb4dbb49d0021845e59bddd4e65238df09cd14b975d1461cbf94"
        ),
        .binaryTarget(
            name: "Unify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.4/Unify3Core-0.1.4.xcframework.zip",
            checksum: "418b9ea8c50370df753c0365bafa88e019780ff5d6fb933ae29d15260a99fc1d"
        )
    ]
)

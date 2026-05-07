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
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.0/Unify3Sdk-0.1.0.xcframework.zip",
            checksum: "1fa820dc6f205c84b6955b56c02a85460906e2abd5927393a5d3007745623d26"
        ),
        .binaryTarget(
            name: "Unify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.0/Unify3Core-0.1.0.xcframework.zip",
            checksum: "def9a7eaafaf7e475847476c66d05e7a33625ca1331cb8d289b03ed4391cce80"
        )
    ]
)

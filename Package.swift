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
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.1/Unify3Sdk-0.1.1.xcframework.zip",
            checksum: "368992eb91e1ee8618d5d9a1d40c579f80ea40eb2ff300da757e22264847dddf"
        ),
        .binaryTarget(
            name: "Unify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.1/Unify3Core-0.1.1.xcframework.zip",
            checksum: "89989ff2da01ba4fb07f77a7bd306da732c29a88d71d7b74e178647182e53728"
        )
    ]
)

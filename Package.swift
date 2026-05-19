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
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.5/Unify3Sdk-0.1.5.xcframework.zip",
            checksum: "9d2b10648c29627f916050cdcfeaa31cb091a3abbad80399c05994a67b72f45b"
        ),
        .binaryTarget(
            name: "Unify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.5/Unify3Core-0.1.5.xcframework.zip",
            checksum: "f429d0c9506aca64609ba277ca5d9c8b9332fa136e0d694a90936ddc37a5035d"
        )
    ]
)

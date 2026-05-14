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
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.2/Unify3Sdk-0.1.2.xcframework.zip",
            checksum: "59729416f722df2b4bc5c08a7f986dd9e324f41f783f9ec426fb5b73a780181b"
        ),
        .binaryTarget(
            name: "Unify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.2/Unify3Core-0.1.2.xcframework.zip",
            checksum: "209634e05cfee426d5469332cbd65674bcdfe4d6c28ae43da0001208e62db834"
        )
    ]
)

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
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.3/Unify3Sdk-0.1.3.xcframework.zip",
            checksum: "ebeba15141ed724a0abb48d505a19076291a1b37d2af2a7f3ef7fdff12bd79ea"
        ),
        .binaryTarget(
            name: "Unify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.3/Unify3Core-0.1.3.xcframework.zip",
            checksum: "cfa72f9dd69e3d8bb47a5832ab8e35512408e9b62ea17b9b1cea28e4367098a5"
        )
    ]
)

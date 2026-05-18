// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IwaOslCalibrationExample",
    
    platforms: [
        .macOS(.v15)
    ],

    dependencies: [
        .package(
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple.git",
            from: "0.1.3"
        )
    ],

    targets: [
        .executableTarget(
            name: "IwaOslCalibrationExample",
            dependencies: [
                .product(
                    name: "Unify3Sdk",
                    package: "Unify3Sdk-Apple"
                )
            ]
        )
    ]
)

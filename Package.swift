// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Unify3Sdk",
    platforms: [
        .iOS("16.6")
    ],
    products: [
        .library(
            name: "Unify3Sdk",
            targets: [
                "Unify3Sdk",
                "libUnify3Core",
                "libSkiaSharp",
                "libHarfBuzzSharp"
            ]
        )
    ],
    targets: [
        .binaryTarget(
            name: "Unify3Sdk",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.6/Unify3Sdk-0.1.6.xcframework.zip",
            checksum: "4860ceff5b0b3d99db13a04f8099fff7098baec1640fd2c3c0b28d1103754c61"
        ),
        .binaryTarget(
            name: "libUnify3Core",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.6/libUnify3Core-0.1.6.xcframework.zip",
            checksum: "eaa63b6543fef6106ca386974eec807a51cd3aaa2e076c88b575459580581ff3"
        ),
        .binaryTarget(
            name: "libSkiaSharp",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.6/libSkiaSharp-0.1.6.xcframework.zip",
            checksum: "8cb6f0fb5e221a65dad0a4409efbb959ea12d89d7b05b550a0615af1aaa18268"
        ),
        .binaryTarget(
            name: "libHarfBuzzSharp",
            url: "https://github.com/KaelusRF/Unify3Sdk-Apple/releases/download/0.1.6/libHarfBuzzSharp-0.1.6.xcframework.zip",
            checksum: "950ce28b458c9492d8e45c004c159ff339ad63748fef05c2a770817f887e872d"
        )
    ]
)

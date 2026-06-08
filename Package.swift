// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "UmbraScaleSupport",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "UmbraScaleSupport",
            targets: ["UmbraScaleSupport"]
        )
    ],
    targets: [
        .target(
            name: "UmbraScaleSupport",
            path: "PackageSupport/UmbraScaleSupport",
            sources: [
                "ScaleHUDMode.swift"
            ]
        ),
        .testTarget(
            name: "UmbraScaleSupportTests",
            dependencies: ["UmbraScaleSupport"],
            path: "PackageSupport/UmbraScaleSupportTests",
            sources: [
                "ScaleHUDPresentationTests.swift"
            ]
        )
    ]
)

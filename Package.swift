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
        ),
        .library(
            name: "FellowKettleSupport",
            targets: ["FellowKettleSupport"]
        )
    ],
    targets: [
        .target(
            name: "UmbraScaleSupport",
            path: "UmbraScale/MenuBar",
            sources: [
                "ScaleHUDMode.swift"
            ]
        ),
        .target(
            name: "FellowKettleSupport",
            path: "UmbraScale/FellowSupport",
            sources: [
                "FellowKettleCLIRequest.swift",
                "FellowKettleMode.swift",
                "FellowKettleParser.swift",
                "FellowKettleSnapshot.swift"
            ]
        ),
        .testTarget(
            name: "UmbraScaleSupportTests",
            dependencies: ["UmbraScaleSupport"],
            path: "UmbraScaleTests",
            sources: [
                "ScaleHUDPresentationTests.swift"
            ]
        ),
        .testTarget(
            name: "FellowKettleSupportTests",
            dependencies: ["FellowKettleSupport"],
            path: "UmbraScaleTests",
            sources: [
                "FellowKettleSupportTests.swift"
            ]
        )
    ]
)

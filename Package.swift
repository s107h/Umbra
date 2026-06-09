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
            exclude: [
                "ConnectionTransitionGate.swift",
                "ScaleHUDCompactContent.swift",
                "ScaleHUDExpandedContent.swift",
                "ScaleHUDRootView.swift",
                "ScaleHUDSections.swift",
                "ScaleHUDWindowController.swift",
                "ScaleMenuBarContent.swift",
                "ScaleMenuBarController.swift"
            ],
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
            exclude: [
                "AcaiaPhase1Tests.swift",
                "FellowKettleSupportTests.swift"
            ],
            sources: [
                "ScaleHUDPresentationTests.swift"
            ]
        ),
        .testTarget(
            name: "FellowKettleSupportTests",
            dependencies: ["FellowKettleSupport"],
            path: "UmbraScaleTests",
            exclude: [
                "AcaiaPhase1Tests.swift",
                "ScaleHUDPresentationTests.swift"
            ],
            sources: [
                "FellowKettleSupportTests.swift"
            ]
        )
    ]
)

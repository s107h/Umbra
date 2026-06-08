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
        .testTarget(
            name: "UmbraScaleSupportTests",
            dependencies: ["UmbraScaleSupport"],
            path: "UmbraScaleTests",
            exclude: [
                "AcaiaPhase1Tests.swift"
            ],
            sources: [
                "ScaleHUDPresentationTests.swift"
            ]
        )
    ]
)

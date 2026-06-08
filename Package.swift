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
            path: "UmbraScale",
            exclude: [
                "Assets.xcassets",
                "Bluetooth",
                "ContentView.swift",
                "MenuBar/ConnectionTransitionGate.swift",
                "MenuBar/ScaleMenuBarContent.swift",
                "MenuBar/ScaleMenuBarController.swift",
                "Models",
                "UmbraScale.entitlements",
                "UmbraScaleApp.swift"
            ],
            sources: [
                "MenuBar/ScaleHUDMode.swift"
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

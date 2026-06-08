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
                "Bluetooth/AcaiaScaleManager.swift",
                "Bluetooth/AcaiaBLEUUIDs.swift",
                "Bluetooth/AcaiaProtocol.swift",
                "Bluetooth/AcaiaScaleState.swift",
                "Bluetooth/AcaiaWeightParser.swift",
                "ContentView.swift",
                "MenuBar/ConnectionTransitionGate.swift",
                "MenuBar/ScaleHUDCompactContent.swift",
                "MenuBar/ScaleHUDExpandedContent.swift",
                "MenuBar/ScaleHUDRootView.swift",
                "MenuBar/ScaleHUDSections.swift",
                "MenuBar/ScaleHUDWindowController.swift",
                "MenuBar/ScaleMenuBarContent.swift",
                "MenuBar/ScaleMenuBarController.swift",
                "Models/DiscoveredScale.swift",
                "Models/ScaleReading.swift",
                "UmbraScaleApp.swift",
                "UmbraScale.entitlements"
            ],
            sources: [
                "Bluetooth/BLELogger.swift",
                "FellowSupport/FellowKettleCLIRequest.swift",
                "FellowSupport/FellowKettleMode.swift",
                "FellowSupport/FellowKettleParser.swift",
                "FellowSupport/FellowKettleSnapshot.swift",
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
                "FellowKettleSupportTests.swift",
                "ScaleHUDPresentationTests.swift"
            ]
        )
    ]
)

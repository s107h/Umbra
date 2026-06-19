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
            name: "FellowKettleManagerSupport",
            targets: ["FellowKettleManagerSupport"]
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
                "FellowKettleSection.swift",
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
            name: "FellowKettleManagerSupport",
            dependencies: ["FellowKettleSupport"],
            path: "UmbraScale/Bluetooth",
            exclude: [
                "AcaiaBLEUUIDs.swift",
                "AcaiaProtocol.swift",
                "AcaiaScaleManager.swift",
                "AcaiaScaleState.swift",
                "AcaiaWeightParser.swift"
            ],
            sources: [
                "BLELogger.swift",
                "FellowKettleDiscoveryCandidate.swift",
                "FellowKettleDiscoveryState.swift",
                "FellowKettleManager.swift",
                "FellowKettleState.swift"
            ]
        ),
        .target(
            name: "FellowKettleSupport",
            path: "UmbraScale/FellowSupport",
            sources: [
                "FellowKettleCLIRequest.swift",
                "FellowKettleHoldDuration.swift",
                "FellowKettleMode.swift",
                "FellowKettleParser.swift",
                "FellowKettleSettingsSnapshot.swift",
                "FellowKettleSnapshot.swift",
                "FellowKettleUnits.swift"
            ]
        ),
        .testTarget(
            name: "FellowKettleManagerSupportTests",
            dependencies: ["FellowKettleManagerSupport"],
            path: "UmbraScaleTests",
            exclude: [
                "AcaiaPhase1Tests.swift",
                "FellowKettleSupportTests.swift",
                "ScaleHUDPresentationTests.swift"
            ],
            sources: [
                "FellowKettleDiscoverySupportTests.swift",
                "FellowKettleManagerTests.swift"
            ]
        ),
        .testTarget(
            name: "UmbraScaleSupportTests",
            dependencies: ["UmbraScaleSupport"],
            path: "UmbraScaleTests",
            exclude: [
                "AcaiaPhase1Tests.swift",
                "FellowKettleDiscoverySupportTests.swift",
                "FellowKettleManagerTests.swift",
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
                "FellowKettleDiscoverySupportTests.swift",
                "FellowKettleManagerTests.swift",
                "ScaleHUDPresentationTests.swift"
            ],
            sources: [
                "FellowKettleSupportTests.swift"
            ]
        )
    ]
)

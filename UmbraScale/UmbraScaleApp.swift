//
//  UmbraScaleApp.swift
//  UmbraScale
//
//  Created by Sid McDonald on 6/4/26.
//

import SwiftUI

@main
struct UmbraScaleApp: App {
    @StateObject private var scale: AcaiaScaleManager
    @StateObject private var kettle: FellowKettleManager
    @StateObject private var kettleBLEResearch: FellowKettleBLEResearchManager
    private let menuBarController: ScaleMenuBarController

    @MainActor
    init() {
        let scale = AcaiaScaleManager()
        let kettle = FellowKettleManager(
            discoveryManager: FellowKettleDiscoveryManager(
                mdnsBrowser: FellowKettleMDNSBrowser(),
                bleResolver: NoopFellowKettleBLEResolver()
            )
        )
        let kettleBLEResearch = FellowKettleBLEResearchManager()
        kettle.beginAutomaticDiscoveryIfNeeded()
        _scale = StateObject(wrappedValue: scale)
        _kettle = StateObject(wrappedValue: kettle)
        _kettleBLEResearch = StateObject(wrappedValue: kettleBLEResearch)
        menuBarController = ScaleMenuBarController(scale: scale, kettle: kettle, kettleBLEResearch: kettleBLEResearch)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

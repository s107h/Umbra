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
    private let menuBarController: ScaleMenuBarController

    @MainActor
    init() {
        let scale = AcaiaScaleManager()
        let kettle = FellowKettleManager()
        _scale = StateObject(wrappedValue: scale)
        _kettle = StateObject(wrappedValue: kettle)
        menuBarController = ScaleMenuBarController(scale: scale)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

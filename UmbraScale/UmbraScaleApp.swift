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
    private let menuBarController: ScaleMenuBarController

    @MainActor
    init() {
        let scale = AcaiaScaleManager()
        _scale = StateObject(wrappedValue: scale)
        menuBarController = ScaleMenuBarController(scale: scale)
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

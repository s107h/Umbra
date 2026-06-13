//
//  ContentView.swift
//  UmbraScale
//
//  Created by Sid McDonald on 6/4/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var scale: AcaiaScaleManager
    @ObservedObject var kettle: FellowKettleManager

    var body: some View {
        ScaleHUDExpandedContent(scale: scale, kettle: kettle, onToggleGear: {})
            .padding(24)
    }
}

#Preview {
    ContentView(scale: AcaiaScaleManager(), kettle: FellowKettleManager())
}

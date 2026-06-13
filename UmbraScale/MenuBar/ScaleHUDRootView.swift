import SwiftUI

struct ScaleHUDRootView: View {
    @ObservedObject var scale: AcaiaScaleManager
    @ObservedObject var kettle: FellowKettleManager
    let mode: ScaleHUDMode
    let onToggleGear: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .compact:
                ScaleHUDCompactContent(scale: scale, onToggleGear: onToggleGear)
            case .expanded:
                ScaleHUDExpandedContent(scale: scale, kettle: kettle, onToggleGear: onToggleGear)
            }
        }
        .padding(20)
    }
}

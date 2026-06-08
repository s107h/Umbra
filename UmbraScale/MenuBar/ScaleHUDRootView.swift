import SwiftUI

struct ScaleHUDRootView: View {
    @ObservedObject var scale: AcaiaScaleManager
    let mode: ScaleHUDMode
    let onToggleGear: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .compact:
                ScaleHUDCompactContent(scale: scale, onToggleGear: onToggleGear)
            case .expanded:
                ScaleHUDExpandedContent(scale: scale, onToggleGear: onToggleGear)
            }
        }
        .padding(20)
    }
}

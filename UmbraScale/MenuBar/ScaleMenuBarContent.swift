import AppKit
import SwiftUI

struct ScaleMenuBarContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    let onOpenExpandedHUD: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(scale.isConnected ? String(format: "%.1f g", scale.displayedReading.grams) : "Disconnected")
                .font(.system(size: scale.isConnected ? 30 : 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button(action: onOpenExpandedHUD) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 250)
    }
}

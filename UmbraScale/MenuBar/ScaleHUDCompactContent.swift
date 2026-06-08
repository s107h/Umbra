import SwiftUI

struct ScaleHUDCompactContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    let onToggleGear: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(scale.isConnected ? String(format: "%.1f g", scale.displayedReading.grams) : "Disconnected")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer()
                Button(action: onToggleGear) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

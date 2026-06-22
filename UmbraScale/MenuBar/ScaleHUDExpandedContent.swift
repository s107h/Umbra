import SwiftUI

struct ScaleHUDExpandedContent: View {
    @ObservedObject var scale: AcaiaScaleManager
    @ObservedObject var kettle: FellowKettleManager
    @ObservedObject var kettleBLEResearch: FellowKettleBLEResearchManager
    let onToggleGear: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(scale.isConnected ? String(format: "%.1f g", scale.displayedReading.grams) : "Disconnected")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(scale.state.displayText)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onToggleGear) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }

                ScaleStatusSection(scale: scale)
                ScaleControlsSection(scale: scale)
                FellowKettleSection(kettle: kettle, researchManager: kettleBLEResearch)
                DiscoveredScalesSection(scale: scale)
                DebugLogSection(scale: scale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: ScaleHUDMode.expanded.contentSize.height - 40, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

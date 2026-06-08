import AppKit
import SwiftUI

struct ScaleStatusSection: View {
    @ObservedObject var scale: AcaiaScaleManager

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Status", value: scale.state.displayText)
                LabeledContent("Connected Device", value: scale.connectedDeviceName ?? "None")
                LabeledContent("Weight", value: String(format: "%.1f g", scale.displayedReading.grams))
                LabeledContent("Raw Weight", value: String(format: "%.1f g", scale.reading.grams))
                LabeledContent("Zero Offset", value: String(format: "%.1f g", scale.zeroOffsetGrams))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ScaleControlsSection: View {
    @ObservedObject var scale: AcaiaScaleManager

    var body: some View {
        HStack(spacing: 12) {
            Button("Scan") {
                scale.startScanning()
            }

            Button("Stop") {
                scale.stopScanning()
            }
            .disabled(!scanCanStop)

            Button("Disconnect") {
                scale.disconnect()
            }
            .disabled(!scale.isConnected)

            Button("Zero Display") {
                scale.zeroDisplay()
            }
            .disabled(!scale.isConnected)

            Button("Clear Zero") {
                scale.clearZeroOffset()
            }
            .disabled(scale.zeroOffsetGrams == 0)

            Spacer()

            Button("Copy Log") {
                copyLogToPasteboard()
            }
            .disabled(scale.logger.lines.isEmpty)

            Button("Clear Log") {
                scale.logger.clear()
            }
        }
    }

    private var scanCanStop: Bool {
        switch scale.state {
        case .scanning, .discovered:
            return true
        default:
            return false
        }
    }

    private func copyLogToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(scale.logger.exportText, forType: .string)
    }
}

struct DiscoveredScalesSection: View {
    @ObservedObject var scale: AcaiaScaleManager

    var body: some View {
        GroupBox("Candidate Acaia Peripherals") {
            if scale.discoveredScales.isEmpty {
                Text("No likely Acaia devices found yet. Turn on the Umbra, keep the Acaia phone app disconnected, and click Scan.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List(scale.discoveredScales) { device in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                            Text("RSSI \(device.rssi)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Connect") {
                            scale.connect(to: device)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 180)
            }
        }
    }
}

struct DebugLogSection: View {
    @ObservedObject var scale: AcaiaScaleManager

    var body: some View {
        GroupBox("Debug Log") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(scale.logger.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 240)
        }
    }
}

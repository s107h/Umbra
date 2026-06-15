import AppKit
import SwiftUI

struct FellowKettleSection: View {
    @ObservedObject var kettle: FellowKettleManager

    @State private var hostInput: String
    @State private var targetTemperatureInput: String
    @State private var isLogExpanded = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case host
        case targetTemperature
    }

    init(kettle: FellowKettleManager) {
        self.kettle = kettle
        _hostInput = State(initialValue: kettle.host)
        _targetTemperatureInput = State(
            initialValue: Self.editableTemperatureString(for: kettle.snapshot?.targetTemperatureCelsius)
        )
    }

    var body: some View {
        GroupBox("Fellow Kettle") {
            VStack(alignment: .leading, spacing: 14) {
                hostControls
                statusRows
                heatControls
                targetControls
                debugLogDisclosure
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: kettle.host) { _, newValue in
            guard focusedField != .host else { return }
            hostInput = newValue
        }
        .onChange(of: kettle.state) { _, _ in
            syncTargetTemperatureInput()
        }
        .onChange(of: kettle.snapshot) { _, _ in
            syncTargetTemperatureInput()
        }
    }

    private var hostControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            TextField("Host or URL", text: $hostInput)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .host)
                .onSubmit(saveHost)

            Button("Save") {
                saveHost()
            }

            Button("Refresh") {
                Task {
                    await kettle.refresh()
                }
            }
            .disabled(kettle.configuredHost == nil || isKettleBusy)
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Status", value: kettle.state.displayText)
            LabeledContent("Configured Host", value: kettle.configuredHost ?? "None")
            LabeledContent("Current Temp", value: formattedTemperature(visibleSnapshot?.currentTemperatureCelsius))
            LabeledContent("Target Temp", value: formattedTemperature(visibleSnapshot?.targetTemperatureCelsius))
            LabeledContent("Heat State", value: heatStateText)
        }
    }

    private var heatControls: some View {
        HStack(spacing: 12) {
            Button("Heat On") {
                Task {
                    await kettle.setHeatEnabled(true)
                }
            }
            .disabled(kettle.configuredHost == nil || isKettleBusy)

            Button("Heat Off") {
                Task {
                    await kettle.setHeatEnabled(false)
                }
            }
            .disabled(kettle.configuredHost == nil || isKettleBusy)
        }
    }

    private var targetControls: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            TextField("Target °C", text: $targetTemperatureInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 120)
                .focused($focusedField, equals: .targetTemperature)
                .onSubmit(submitTargetTemperature)

            Button("Set") {
                submitTargetTemperature()
            }
            .disabled(parsedTargetTemperature == nil || kettle.configuredHost == nil || isKettleBusy)
        }
    }

    private var debugLogDisclosure: some View {
        DisclosureGroup("Debug Log", isExpanded: $isLogExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                FellowKettleLogControls(logger: kettle.logger)
                FellowKettleLogView(logger: kettle.logger)
            }
            .padding(.top, 8)
        }
    }

    private var parsedTargetTemperature: Double? {
        Double(targetTemperatureInput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isKettleBusy: Bool {
        if case .polling = kettle.state {
            return true
        }

        if case .commandInFlight = kettle.state {
            return true
        }

        return false
    }

    private var visibleSnapshot: FellowKettleSnapshot? {
        guard isReadyForConfiguredHost else { return nil }
        return kettle.snapshot
    }

    private var isReadyForConfiguredHost: Bool {
        guard let configuredHost = kettle.configuredHost else { return false }

        guard case .ready(let readyHost) = kettle.state else {
            return false
        }

        return readyHost == configuredHost
    }

    private var heatStateText: String {
        guard let snapshot = visibleSnapshot else { return "Unknown" }

        switch snapshot.mode {
        case .off:
            return "Off"
        case .heating:
            return "Heating"
        case .hold:
            return "Hold"
        case .other(let mode):
            return mode
        }
    }

    private func saveHost() {
        let previousHost = kettle.configuredHost
        kettle.host = hostInput
        kettle.saveHost()
        hostInput = kettle.host

        if previousHost != kettle.configuredHost {
            targetTemperatureInput = ""
        }

        syncTargetTemperatureInput()
    }

    private func submitTargetTemperature() {
        guard let targetTemperature = parsedTargetTemperature else { return }

        focusedField = nil
        Task {
            await kettle.setTargetTemperature(targetTemperature)
        }
    }

    private func formattedTemperature(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return Self.temperatureString(for: value)
    }

    private func syncTargetTemperatureInput() {
        guard focusedField != .targetTemperature else { return }

        if let snapshot = visibleSnapshot {
            targetTemperatureInput = Self.editableTemperatureString(for: snapshot.targetTemperatureCelsius)
        } else {
            targetTemperatureInput = ""
        }
    }

    private static func temperatureString(for value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f °C", value)
    }

    private static func editableTemperatureString(for value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f", value)
    }
}

private struct FellowKettleLogControls: View {
    @ObservedObject var logger: BLELogger

    var body: some View {
        HStack(spacing: 12) {
            Button("Copy Kettle Log") {
                copyLogToPasteboard()
            }
            .disabled(logger.lines.isEmpty)

            Button("Clear Kettle Log") {
                logger.clear()
            }
            .disabled(logger.lines.isEmpty)
        }
    }

    private func copyLogToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logger.exportText, forType: .string)
    }
}

private struct FellowKettleLogView: View {
    @ObservedObject var logger: BLELogger

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(logger.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minHeight: 160, maxHeight: 220)
    }
}

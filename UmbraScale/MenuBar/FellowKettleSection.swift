import AppKit
import SwiftUI

struct FellowKettleSection: View {
    @ObservedObject var kettle: FellowKettleManager
    @ObservedObject var researchManager: FellowKettleBLEResearchManager

    @State private var hostInput: String
    @State private var targetTemperatureInput: String
    @State private var selectedUnits: FellowKettleUnits
    @State private var selectedHoldDuration: FellowKettleHoldDuration
    @State private var isLogExpanded = false
    @State private var isResearchExpanded = false
    @State private var isResearchLogExpanded = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case host
        case targetTemperature
    }

    init(kettle: FellowKettleManager, researchManager: FellowKettleBLEResearchManager) {
        self.kettle = kettle
        self.researchManager = researchManager
        _hostInput = State(initialValue: kettle.host)
        _targetTemperatureInput = State(
            initialValue: Self.editableTemperatureString(for: kettle.snapshot?.targetTemperatureCelsius)
        )
        _selectedUnits = State(initialValue: kettle.snapshot?.units ?? .celsius)
        _selectedHoldDuration = State(initialValue: kettle.snapshot?.holdDuration ?? .off)
    }

    var body: some View {
        GroupBox("Fellow Kettle") {
            VStack(alignment: .leading, spacing: 14) {
                discoveryStatusRows
                hostControls
                statusRows
                heatControls
                targetControls
                settingsControls
                bleResearchDisclosure
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
            syncSettingsInputs()
        }
    }

    private var discoveryStatusRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Discovery", value: discoveryStatusText)
            LabeledContent("Candidates", value: "\(kettle.discoveryCandidates.count)")
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
            LabeledContent("Configured Host", value: kettle.configuredHost ?? "Auto-discovering")
            LabeledContent("Current Temp", value: formattedTemperature(visibleSnapshot?.currentTemperatureCelsius))
            LabeledContent("Target Temp", value: formattedTemperature(visibleSnapshot?.targetTemperatureCelsius))
            LabeledContent("Heat State", value: heatStateText)
            LabeledContent("Units", value: unitsText)
            LabeledContent("Hold", value: holdDurationText)
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

    private var settingsControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Picker("Units", selection: $selectedUnits) {
                    Text("Celsius").tag(FellowKettleUnits.celsius)
                    Text("Fahrenheit").tag(FellowKettleUnits.fahrenheit)
                }
                .pickerStyle(.menu)

                Button("Set Units") {
                    Task {
                        await kettle.setUnits(selectedUnits)
                    }
                }
                .disabled(kettle.configuredHost == nil || isKettleBusy)
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Picker("Hold", selection: $selectedHoldDuration) {
                    Text("Off").tag(FellowKettleHoldDuration.off)
                    Text("15 min").tag(FellowKettleHoldDuration.minutes15)
                    Text("30 min").tag(FellowKettleHoldDuration.minutes30)
                    Text("45 min").tag(FellowKettleHoldDuration.minutes45)
                    Text("60 min").tag(FellowKettleHoldDuration.minutes60)
                }
                .pickerStyle(.menu)

                Button("Set Hold") {
                    Task {
                        await kettle.setHoldDuration(selectedHoldDuration)
                    }
                }
                .disabled(kettle.configuredHost == nil || isKettleBusy)
            }
        }
    }

    private var bleResearchDisclosure: some View {
        DisclosureGroup("BLE Research", isExpanded: $isResearchExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Research Status", value: researchManager.state.displayText)
                LabeledContent("BLE Candidates", value: "\(researchManager.candidates.count)")
                LabeledContent("Services", value: "\(researchManager.session.serviceSummaries.count)")
                LabeledContent("Characteristics", value: "\(researchManager.session.characteristicSummaries.count)")
                LabeledContent("Reads", value: "\(researchManager.session.readEvents.count)")
                LabeledContent("Notifications", value: "\(researchManager.session.notificationEvents.count)")
                LabeledContent("Endpoint Candidates", value: "\(researchManager.session.endpointCandidates.count)")

                HStack(spacing: 12) {
                    Button("Scan BLE") {
                        researchManager.startScanning()
                    }

                    Button("Disconnect BLE") {
                        researchManager.disconnect()
                    }
                }

                FellowKettleBLECandidateList(manager: researchManager)
                FellowKettleBLEEndpointCandidateList(candidates: researchManager.session.endpointCandidates)

                DisclosureGroup("BLE Debug Log", isExpanded: $isResearchLogExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        FellowKettleLogControls(logger: researchManager.logger, copyTitle: "Copy BLE Log", clearTitle: "Clear BLE Log")
                        FellowKettleLogView(logger: researchManager.logger)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.top, 8)
        }
    }

    private var debugLogDisclosure: some View {
        DisclosureGroup("Debug Log", isExpanded: $isLogExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                FellowKettleLogControls(logger: kettle.logger, copyTitle: "Copy Kettle Log", clearTitle: "Clear Kettle Log")
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
        guard isSnapshotStateForConfiguredHost else { return nil }
        return kettle.snapshot
    }

    private var isSnapshotStateForConfiguredHost: Bool {
        guard let configuredHost = kettle.configuredHost else { return false }

        switch kettle.state {
        case .ready(let host),
             .polling(let host),
             .commandInFlight(let host, _):
            return host == configuredHost
        case .error(let host, _):
            return host == configuredHost
        case .configured,
             .discovering,
             .conflict,
             .unconfigured:
            return false
        }
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

    private var discoveryStatusText: String {
        switch kettle.discoveryState {
        case .idle:
            return kettle.configuredHost == nil ? "Idle" : "Stopped"
        case .discovering:
            return "Searching"
        case .conflict:
            return "Multiple candidates"
        }
    }

    private var unitsText: String {
        switch visibleSnapshot?.units {
        case .celsius:
            return "Celsius"
        case .fahrenheit:
            return "Fahrenheit"
        case nil:
            return "Unavailable"
        }
    }

    private var holdDurationText: String {
        switch visibleSnapshot?.holdDuration {
        case .off:
            return "Off"
        case .minutes15:
            return "15 min"
        case .minutes30:
            return "30 min"
        case .minutes45:
            return "45 min"
        case .minutes60:
            return "60 min"
        case nil:
            return "Unavailable"
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

    private func syncSettingsInputs() {
        if let units = visibleSnapshot?.units {
            selectedUnits = units
        }

        if let holdDuration = visibleSnapshot?.holdDuration {
            selectedHoldDuration = holdDuration
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

private struct FellowKettleBLECandidateList: View {
    @ObservedObject var manager: FellowKettleBLEResearchManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if manager.candidates.isEmpty {
                Text("No BLE candidates yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.candidates) { candidate in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.name)
                            Text("RSSI \(candidate.rssi)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Inspect") {
                            manager.inspectCandidate(candidate.id)
                        }
                    }
                }
            }
        }
    }
}

private struct FellowKettleBLEEndpointCandidateList: View {
    let candidates: [FellowKettleBLEEndpointCandidate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if candidates.isEmpty {
                Text("No endpoint-like payloads captured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.value)
                            .font(.system(.body, design: .monospaced))
                        Text(candidate.source)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct FellowKettleLogControls: View {
    @ObservedObject var logger: BLELogger
    let copyTitle: String
    let clearTitle: String

    var body: some View {
        HStack(spacing: 12) {
            Button(copyTitle) {
                copyLogToPasteboard()
            }
            .disabled(logger.lines.isEmpty)

            Button(clearTitle) {
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

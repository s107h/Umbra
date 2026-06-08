@preconcurrency import CoreBluetooth
import Foundation
import Combine

@MainActor
final class AcaiaScaleManager: NSObject, ObservableObject {
    private static let startupOutlierWindow: TimeInterval = 2
    private static let startupOutlierThresholdGrams: Double = 20
    private static let lastConnectedPeripheralIDKey = "lastConnectedPeripheralID"
    private static let lastConnectedScaleNameKey = "lastConnectedScaleName"

    @Published private(set) var state: AcaiaScaleState = .idle
    @Published private(set) var reading: ScaleReading = .zero
    @Published private(set) var discoveredScales: [DiscoveredScale] = []
    @Published private(set) var connectedDeviceName: String?
    @Published private(set) var zeroOffsetGrams: Double = 0
    @Published var logger = BLELogger()

    var isConnected: Bool {
        activePeripheral?.state == .connected
    }

    var displayedReading: ScaleReading {
        ScaleReading(
            grams: reading.grams - zeroOffsetGrams,
            isStable: reading.isStable,
            timestamp: reading.timestamp
        )
    }

    private var central: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var heartbeatTimer: Timer?
    private var handshakeSent = false
    private var streamStartedAt: Date?
    private var hasAcceptedStableReading = false
    private var manualDisconnectRequested = false

    var menuBarTitle: String {
        if isConnected {
            return String(format: "%.1f g", displayedReading.grams)
        }
        return "Umbra"
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        logger.log("Initializing Bluetooth manager")
    }

    func startScanning() {
        guard central.state == .poweredOn else {
            let message = bluetoothUnavailableReason(for: central.state)
            state = .bluetoothUnavailable(message)
            logger.log("Cannot scan: \(message)")
            return
        }

        manualDisconnectRequested = false
        discoveredScales = []
        peripheralsByID.removeAll()
        state = .scanning
        logger.log("Starting BLE scan without service filtering")
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() {
        guard central.isScanning else { return }
        central.stopScan()
        logger.log("Stopped BLE scan")
        if connectedDeviceName != nil {
            state = .connected(name: connectedDeviceName ?? "Scale")
        } else {
            state = .bluetoothReady
        }
    }

    func connect(to discoveredScale: DiscoveredScale) {
        guard let peripheral = peripheralsByID[discoveredScale.id] else {
            state = .error("Selected peripheral is no longer available.")
            logger.log("Cannot connect: peripheral \(discoveredScale.id) not retained")
            return
        }

        manualDisconnectRequested = false
        stopScanning()
        clearDiscoveredCharacteristics()
        activePeripheral = peripheral
        connectedDeviceName = discoveredScale.name
        peripheral.delegate = self
        state = .connecting(name: discoveredScale.name)
        logger.log("Connecting to \(discoveredScale.name) (\(peripheral.identifier.uuidString))")
        central.connect(peripheral)
    }

    func disconnect() {
        guard let activePeripheral else { return }
        manualDisconnectRequested = true
        logger.log("Disconnecting from \(connectedDeviceName ?? activePeripheral.identifier.uuidString)")
        central.cancelPeripheralConnection(activePeripheral)
    }

    func zeroDisplay() {
        zeroOffsetGrams = reading.grams
        logger.log(String(format: "Set software zero offset to %.1f g", zeroOffsetGrams))
    }

    func clearZeroOffset() {
        guard zeroOffsetGrams != 0 else { return }
        logger.log(String(format: "Cleared software zero offset from %.1f g", zeroOffsetGrams))
        zeroOffsetGrams = 0
    }

    #if DEBUG
    func replaceReadingForTesting(_ reading: ScaleReading) {
        self.reading = reading
    }

    static func shouldIgnoreStartupOutlier(
        reading: ScaleReading,
        elapsedSinceStreamStart: TimeInterval,
        hasAcceptedStableReading: Bool
    ) -> Bool {
        guard !hasAcceptedStableReading else { return false }
        guard elapsedSinceStreamStart < startupOutlierWindow else { return false }
        guard reading.isStable != true else { return false }
        return abs(reading.grams) >= startupOutlierThresholdGrams
    }
    #endif

    private func clearDiscoveredCharacteristics() {
        writeCharacteristic = nil
        notifyCharacteristic = nil
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        handshakeSent = false
        streamStartedAt = nil
        hasAcceptedStableReading = false
    }

    private func ensureBackgroundScanIfNeeded() {
        guard !manualDisconnectRequested else { return }
        guard central.state == .poweredOn else { return }
        guard activePeripheral == nil else { return }
        guard !central.isScanning else { return }
        startScanning()
    }

    private func rememberConnectedScale(id: UUID, name: String) {
        UserDefaults.standard.set(id.uuidString, forKey: Self.lastConnectedPeripheralIDKey)
        UserDefaults.standard.set(name, forKey: Self.lastConnectedScaleNameKey)
    }

    private func preferredScaleMatches(_ scale: DiscoveredScale) -> Bool {
        let defaults = UserDefaults.standard
        let preferredID = defaults.string(forKey: Self.lastConnectedPeripheralIDKey)
        let preferredName = defaults.string(forKey: Self.lastConnectedScaleNameKey)

        if let preferredID, scale.id.uuidString.caseInsensitiveCompare(preferredID) == .orderedSame {
            return true
        }

        if let preferredName, scale.name.caseInsensitiveCompare(preferredName) == .orderedSame {
            return true
        }

        return false
    }

    private func shouldAutoReconnect(to scale: DiscoveredScale) -> Bool {
        guard !manualDisconnectRequested else { return false }
        guard activePeripheral == nil else { return false }

        switch state {
        case .connecting, .discoveringServices, .subscribing, .handshaking:
            return false
        default:
            break
        }

        return preferredScaleMatches(scale)
    }

    private func bluetoothUnavailableReason(for state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "Bluetooth state is still initializing."
        case .resetting:
            return "Bluetooth is resetting."
        case .unsupported:
            return "This Mac does not support Bluetooth LE."
        case .unauthorized:
            return "Bluetooth access is not authorized."
        case .poweredOff:
            return "Bluetooth is powered off."
        case .poweredOn:
            return "Bluetooth is ready."
        @unknown default:
            return "Unknown Bluetooth state."
        }
    }

    private func addOrUpdateDiscoveredScale(
        peripheral: CBPeripheral,
        displayName: String,
        rssi: Int,
        advertisementName: String?
    ) {
        peripheralsByID[peripheral.identifier] = peripheral
        let scale = DiscoveredScale(peripheral: peripheral, name: displayName, rssi: rssi)

        if let index = discoveredScales.firstIndex(where: { $0.id == scale.id }) {
            discoveredScales[index] = scale
        } else {
            discoveredScales.append(scale)
        }

        discoveredScales.sort { lhs, rhs in
            if lhs.rssi == rhs.rssi {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.rssi > rhs.rssi
        }

        state = .discovered(name: displayName)
        let advertised = advertisementName ?? "nil"
        logger.log("Discovered candidate \(displayName) RSSI \(rssi) advertisedName=\(advertised)")
    }

    private func selectCharacteristics(from characteristics: [CBCharacteristic], for peripheral: CBPeripheral) {
        for characteristic in characteristics {
            let uuidString = characteristic.uuid.uuidString.uppercased()
            logger.log(
                "Characteristic \(uuidString) properties=\(propertySummary(for: characteristic.properties))"
            )

            guard let role = AcaiaProtocol.characteristicRole(
                uuidString: uuidString,
                canWrite: characteristic.properties.contains(.write),
                canWriteWithoutResponse: characteristic.properties.contains(.writeWithoutResponse),
                canNotify: characteristic.properties.contains(.notify),
                canIndicate: characteristic.properties.contains(.indicate)
            ) else {
                continue
            }

            if role.useForWrite {
                writeCharacteristic = characteristic
                logger.log("Selected write characteristic \(uuidString)")
            }

            if role.useForNotify {
                notifyCharacteristic = characteristic
                logger.log("Selected notify characteristic \(uuidString)")
            }
        }

        if let notifyCharacteristic, !notifyCharacteristic.isNotifying {
            state = .subscribing(name: connectedDeviceName ?? peripheral.name ?? "Scale")
            logger.log("Subscribing to notify characteristic \(notifyCharacteristic.uuid.uuidString.uppercased())")
            peripheral.setNotifyValue(true, for: notifyCharacteristic)
        }
    }

    private func propertySummary(for properties: CBCharacteristicProperties) -> String {
        var names: [String] = []

        if properties.contains(.read) { names.append("read") }
        if properties.contains(.write) { names.append("write") }
        if properties.contains(.writeWithoutResponse) { names.append("writeWithoutResponse") }
        if properties.contains(.notify) { names.append("notify") }
        if properties.contains(.indicate) { names.append("indicate") }

        return names.isEmpty ? "[]" : names.joined(separator: ",")
    }

    private func sendHandshakeIfReady() {
        guard !handshakeSent else { return }
        guard activePeripheral != nil else { return }
        guard writeCharacteristic != nil else {
            logger.log("Handshake deferred: missing write characteristic")
            return
        }
        guard notifyCharacteristic?.isNotifying == true else {
            logger.log("Handshake deferred: notify characteristic not enabled")
            return
        }

        handshakeSent = true
        streamStartedAt = .now
        hasAcceptedStableReading = false
        state = .handshaking(name: connectedDeviceName ?? "Scale")

        write(AcaiaProtocol.identify, label: "identify")
        write(AcaiaProtocol.notificationRequest, label: "notification request")
        startHeartbeat()
    }

    private func write(_ bytes: [UInt8], label: String) {
        guard let peripheral = activePeripheral,
              let characteristic = writeCharacteristic else {
            logger.log("Cannot write \(label): missing peripheral or write characteristic")
            return
        }

        let writeType: CBCharacteristicWriteType =
            characteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse
            : .withResponse

        logger.log("TX \(label): \(Data(bytes).hexString)")
        peripheral.writeValue(Data(bytes), for: characteristic, type: writeType)
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.75, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.write(AcaiaProtocol.heartbeat, label: "heartbeat")
            }
        }
        logger.log("Started heartbeat loop")
    }
}

extension AcaiaScaleManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            let message = self.bluetoothUnavailableReason(for: central.state)
            self.logger.log("Central state changed to \(central.state.rawValue): \(message)")

            switch central.state {
            case .poweredOn:
                self.state = .bluetoothReady
                self.ensureBackgroundScanIfNeeded()
            default:
                self.state = .bluetoothUnavailable(message)
                self.discoveredScales = []
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let advertisementName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let peripheralName = peripheral.name
        let rssiValue = RSSI.intValue

        Task { @MainActor in
            let displayName = advertisementName ?? peripheralName ?? "Unnamed Peripheral"
            guard AcaiaProtocol.isLikelyScaleName(displayName) else { return }

            self.addOrUpdateDiscoveredScale(
                peripheral: peripheral,
                displayName: displayName,
                rssi: rssiValue,
                advertisementName: advertisementName
            )

            let scale = DiscoveredScale(peripheral: peripheral, name: displayName, rssi: rssiValue)
            if self.shouldAutoReconnect(to: scale) {
                self.logger.log("Auto-connecting to remembered scale \(displayName)")
                self.connect(to: scale)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            let name = self.connectedDeviceName ?? peripheral.name ?? "Scale"
            self.logger.log("Connected to \(name)")
            self.activePeripheral = peripheral
            self.rememberConnectedScale(id: peripheral.identifier, name: name)
            self.state = .discoveringServices(name: name)
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            let message = error?.localizedDescription ?? "Unknown CoreBluetooth error"
            self.logger.log("Failed to connect: \(message)")
            self.state = .error(message)
            self.activePeripheral = nil
            self.connectedDeviceName = nil
            self.clearDiscoveredCharacteristics()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.logger.log("Disconnected with error: \(error.localizedDescription)")
            } else {
                self.logger.log("Disconnected from \(self.connectedDeviceName ?? peripheral.identifier.uuidString)")
            }

            self.activePeripheral = nil
            self.connectedDeviceName = nil
            self.clearDiscoveredCharacteristics()
            self.state = .disconnected
            self.ensureBackgroundScanIfNeeded()
        }
    }
}

extension AcaiaScaleManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                self.logger.log("Service discovery failed: \(error.localizedDescription)")
                self.state = .error(error.localizedDescription)
                return
            }

            guard let services = peripheral.services, !services.isEmpty else {
                self.logger.log("No services discovered")
                self.state = .error("No BLE services discovered.")
                return
            }

            for service in services {
                self.logger.log("Service \(service.uuid.uuidString)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.logger.log("Characteristic discovery failed for \(service.uuid.uuidString): \(error.localizedDescription)")
                self.state = .error(error.localizedDescription)
                return
            }

            guard let characteristics = service.characteristics, !characteristics.isEmpty else {
                self.logger.log("No characteristics found for service \(service.uuid.uuidString)")
                return
            }

            self.selectCharacteristics(from: characteristics, for: peripheral)

            if self.writeCharacteristic != nil || self.notifyCharacteristic != nil {
                self.state = .connected(name: self.connectedDeviceName ?? peripheral.name ?? "Scale")
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.logger.log("Notify update failed for \(characteristic.uuid.uuidString): \(error.localizedDescription)")
                self.state = .error(error.localizedDescription)
                return
            }

            self.logger.log(
                "Notification state for \(characteristic.uuid.uuidString.uppercased()): \(characteristic.isNotifying ? "enabled" : "disabled")"
            )

            if characteristic.isNotifying {
                self.sendHandshakeIfReady()
            } else {
                self.state = .connected(name: self.connectedDeviceName ?? peripheral.name ?? "Scale")
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.logger.log("Value update failed for \(characteristic.uuid.uuidString): \(error.localizedDescription)")
                return
            }

            guard let data = characteristic.value else {
                self.logger.log("Received empty value for \(characteristic.uuid.uuidString)")
                return
            }

            self.logger.log(
                AcaiaProtocol.incomingPayloadLog(
                    uuidString: characteristic.uuid.uuidString,
                    data: data
                )
            )

            switch AcaiaWeightParser.parse(data) {
            case .weight(let parsedPacket):
                let elapsedSinceStreamStart = self.streamStartedAt.map { Date.now.timeIntervalSince($0) } ?? .infinity

                if Self.shouldIgnoreStartupOutlier(
                    reading: parsedPacket.reading,
                    elapsedSinceStreamStart: elapsedSinceStreamStart,
                    hasAcceptedStableReading: self.hasAcceptedStableReading
                ) {
                    self.logger.log(
                        String(format: "Ignored startup outlier %.1f g", parsedPacket.reading.grams)
                    )
                    return
                }

                self.reading = parsedPacket.reading
                if parsedPacket.reading.isStable == true {
                    self.hasAcceptedStableReading = true
                }
                let stability = parsedPacket.reading.isStable == true ? "stable" : "unstable"
                self.logger.log(
                    String(
                        format: "Parsed %@ reading %.1f g (%@)",
                        parsedPacket.packetKind,
                        parsedPacket.reading.grams,
                        stability
                    )
                )
                self.state = .connected(name: self.connectedDeviceName ?? peripheral.name ?? "Scale")
            case .status(let kind):
                self.logger.log("Observed \(kind) packet")
            case .unknown(let reason):
                self.logger.log("Unhandled packet: \(reason)")
            }
        }
    }
}

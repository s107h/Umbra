import Combine
@preconcurrency import CoreBluetooth
import Foundation

protocol FellowKettleBLEResearchEnvironment: Sendable {
    var discoveries: AsyncStream<FellowKettleBLECandidate> { get }
    var serviceDiscoveries: AsyncStream<[String]> { get }
    var characteristicDiscoveries: AsyncStream<[FellowKettleBLECharacteristicDiscovery]> { get }
    var readEvents: AsyncStream<(String, Data)> { get }
    var notifyEvents: AsyncStream<(String, Data)> { get }

    func startScanning() async
    func stopScanning() async
    func connect(id: UUID) async
    func disconnect() async
}

@MainActor
final class FellowKettleBLEResearchManager: ObservableObject {
    @Published private(set) var state: FellowKettleBLEResearchState = .idle
    @Published private(set) var candidates: [FellowKettleBLECandidate] = []
    @Published private(set) var session: FellowKettleBLEResearchSession = .empty
    @Published private(set) var selectedCandidateID: UUID?
    @Published var logger = BLELogger()

    private let environment: FellowKettleBLEResearchEnvironment
    private var tasks: [Task<Void, Never>] = []

    init() {
        self.environment = CoreBluetoothFellowKettleBLEEnvironment()
    }

    init(environment: FellowKettleBLEResearchEnvironment) {
        self.environment = environment
    }

    deinit {
        tasks.forEach { $0.cancel() }
    }

    func startScanning() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        candidates = []
        session = .empty
        selectedCandidateID = nil
        state = .scanning
        logger.log("Starting Fellow BLE research scan")

        tasks.append(
            Task { [environment] in
                for await candidate in environment.discoveries {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.handleDiscovery(candidate)
                    }
                }
            }
        )

        tasks.append(
            Task { [environment] in
                for await services in environment.serviceDiscoveries {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.handleServices(services)
                    }
                }
            }
        )

        tasks.append(
            Task { [environment] in
                for await characteristics in environment.characteristicDiscoveries {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.handleCharacteristics(characteristics)
                    }
                }
            }
        )

        tasks.append(
            Task { [environment] in
                for await (uuid, data) in environment.readEvents {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.handleRead(uuid: uuid, data: data)
                    }
                }
            }
        )

        tasks.append(
            Task { [environment] in
                for await (uuid, data) in environment.notifyEvents {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        self.handleNotify(uuid: uuid, data: data)
                    }
                }
            }
        )

        tasks.append(
            Task { [environment] in
                await environment.startScanning()
            }
        )
    }

    func inspectCandidate(_ id: UUID) {
        guard let candidate = candidates.first(where: { $0.id == id }) else { return }
        selectedCandidateID = id
        state = .connecting(name: candidate.name)
        logger.log("Connecting to Fellow BLE research candidate \(candidate.name)")

        tasks.append(
            Task { [environment] in
                await environment.connect(id: id)
            }
        )
    }

    func disconnect() {
        tasks.append(
            Task { [environment] in
                await environment.disconnect()
                await environment.stopScanning()
            }
        )
        state = .disconnected
        logger.log("Disconnected Fellow BLE research session")
    }

    private var selectedCandidateName: String {
        candidates.first(where: { $0.id == selectedCandidateID })?.name ?? "Fellow kettle"
    }

    private func handleDiscovery(_ candidate: FellowKettleBLECandidate) {
        if let index = candidates.firstIndex(where: { $0.id == candidate.id }) {
            candidates[index] = candidate
        } else {
            candidates.append(candidate)
        }

        let advertisementEvent = FellowKettleBLEAdvertisementEvent(
            candidateID: candidate.id,
            name: candidate.name,
            rssi: candidate.rssi,
            serviceUUIDs: candidate.serviceUUIDs
        )
        if let index = session.advertisementEvents.firstIndex(where: { $0.candidateID == candidate.id }) {
            session.advertisementEvents[index] = advertisementEvent
        } else {
            session.advertisementEvents.append(advertisementEvent)
        }
    }

    private func handleServices(_ services: [String]) {
        session.serviceSummaries = services.map(FellowKettleBLEServiceSummary.init(uuid:))
        if selectedCandidateID != nil {
            state = .discoveringCharacteristics(name: selectedCandidateName)
        }

        for service in services {
            logger.log("Fellow BLE service \(service)")
        }
    }

    private func handleCharacteristics(_ characteristics: [FellowKettleBLECharacteristicDiscovery]) {
        for characteristic in characteristics {
            let summary = FellowKettleBLECharacteristicSummary(
                serviceUUID: characteristic.serviceUUID,
                uuid: characteristic.uuid,
                properties: characteristic.properties
            )
            if let index = session.characteristicSummaries.firstIndex(where: { $0.uuid == summary.uuid }) {
                session.characteristicSummaries[index] = summary
            } else {
                session.characteristicSummaries.append(summary)
            }
            logger.log(
                "Fellow BLE characteristic \(summary.uuid.uppercased()) service=\(summary.serviceUUID.uppercased()) properties=\(summary.properties.joined(separator: ","))"
            )
        }

        if selectedCandidateID != nil {
            state = .capturing(name: selectedCandidateName)
        }
    }

    private func handleRead(uuid: String, data: Data) {
        let event = FellowKettleBLEPayloadEvent(
            characteristicUUID: uuid,
            kind: .read,
            data: data,
            renderedLine: FellowKettleBLEProtocol.payloadLog(kind: "read", characteristicUUID: uuid, data: data)
        )
        session.readEvents.append(event)
        appendEndpointCandidates(from: data, source: "Read \(uuid)")
        logger.log(event.renderedLine)
    }

    private func handleNotify(uuid: String, data: Data) {
        let event = FellowKettleBLEPayloadEvent(
            characteristicUUID: uuid,
            kind: .notify,
            data: data,
            renderedLine: FellowKettleBLEProtocol.payloadLog(kind: "notify", characteristicUUID: uuid, data: data)
        )
        session.notificationEvents.append(event)
        appendEndpointCandidates(from: data, source: "Notify \(uuid)")
        logger.log(event.renderedLine)
    }

    private func appendEndpointCandidates(from data: Data, source: String) {
        for value in FellowKettleBLEProtocol.endpointCandidates(in: data) {
            let candidate = FellowKettleBLEEndpointCandidate(source: source, value: value)
            if !session.endpointCandidates.contains(candidate) {
                session.endpointCandidates.append(candidate)
            }
            logger.log("Fellow BLE endpoint candidate source=\(source) value=\(value)")
        }
    }
}

@MainActor
final class CoreBluetoothFellowKettleBLEEnvironment: NSObject, FellowKettleBLEResearchEnvironment {
    nonisolated let discoveries: AsyncStream<FellowKettleBLECandidate>
    nonisolated let serviceDiscoveries: AsyncStream<[String]>
    nonisolated let characteristicDiscoveries: AsyncStream<[FellowKettleBLECharacteristicDiscovery]>
    nonisolated let readEvents: AsyncStream<(String, Data)>
    nonisolated let notifyEvents: AsyncStream<(String, Data)>

    private var discoveryContinuation: AsyncStream<FellowKettleBLECandidate>.Continuation?
    private var serviceContinuation: AsyncStream<[String]>.Continuation?
    private var characteristicContinuation: AsyncStream<[FellowKettleBLECharacteristicDiscovery]>.Continuation?
    private var readContinuation: AsyncStream<(String, Data)>.Continuation?
    private var notifyContinuation: AsyncStream<(String, Data)>.Continuation?

    private var central: CBCentralManager!
    private var peripheralsByID: [UUID: CBPeripheral] = [:]
    private var activePeripheral: CBPeripheral?

    override init() {
        var discoveryContinuation: AsyncStream<FellowKettleBLECandidate>.Continuation?
        discoveries = AsyncStream { discoveryContinuation = $0 }

        var serviceContinuation: AsyncStream<[String]>.Continuation?
        serviceDiscoveries = AsyncStream { serviceContinuation = $0 }

        var characteristicContinuation: AsyncStream<[FellowKettleBLECharacteristicDiscovery]>.Continuation?
        characteristicDiscoveries = AsyncStream { characteristicContinuation = $0 }

        var readContinuation: AsyncStream<(String, Data)>.Continuation?
        readEvents = AsyncStream { readContinuation = $0 }

        var notifyContinuation: AsyncStream<(String, Data)>.Continuation?
        notifyEvents = AsyncStream { notifyContinuation = $0 }

        self.discoveryContinuation = discoveryContinuation
        self.serviceContinuation = serviceContinuation
        self.characteristicContinuation = characteristicContinuation
        self.readContinuation = readContinuation
        self.notifyContinuation = notifyContinuation

        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() async {
        peripheralsByID.removeAll()
        activePeripheral = nil

        guard central.state == .poweredOn else { return }

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func stopScanning() async {
        guard central.isScanning else { return }
        central.stopScan()
    }

    func connect(id: UUID) async {
        guard let peripheral = peripheralsByID[id] else { return }
        await stopScanning()
        activePeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func disconnect() async {
        guard let activePeripheral else { return }
        central.cancelPeripheralConnection(activePeripheral)
    }
}

extension CoreBluetoothFellowKettleBLEEnvironment: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let advertisementName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let peripheralName = peripheral.name
        let displayName = advertisementName ?? peripheralName ?? "Unnamed Peripheral"

        guard FellowKettleBLEProtocol.isLikelyKettleName(displayName) else { return }

        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            .map { $0.uuidString.uppercased() }

        Task { @MainActor in
            self.peripheralsByID[peripheral.identifier] = peripheral
            self.discoveryContinuation?.yield(
                FellowKettleBLECandidate(
                    id: peripheral.identifier,
                    name: displayName,
                    rssi: RSSI.intValue,
                    serviceUUIDs: serviceUUIDs
                )
            )
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            if self.activePeripheral?.identifier == peripheral.identifier {
                self.activePeripheral = nil
            }
        }
    }
}

extension CoreBluetoothFellowKettleBLEEnvironment: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        let services = peripheral.services ?? []
        let serviceUUIDs = services.map { $0.uuid.uuidString.uppercased() }

        Task { @MainActor in
            self.serviceContinuation?.yield(serviceUUIDs)
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        let characteristics = service.characteristics ?? []
        let discoveries = characteristics.map {
            FellowKettleBLECharacteristicDiscovery(
                serviceUUID: service.uuid.uuidString.uppercased(),
                uuid: $0.uuid.uuidString.uppercased(),
                properties: FellowKettleBLEProtocol.propertyNames(for: $0.properties)
            )
        }

        Task { @MainActor in
            self.characteristicContinuation?.yield(discoveries)

            for characteristic in characteristics {
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }

                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        let uuid = characteristic.uuid.uuidString.uppercased()

        Task { @MainActor in
            if characteristic.isNotifying {
                self.notifyContinuation?.yield((uuid, data))
            } else {
                self.readContinuation?.yield((uuid, data))
            }
        }
    }
}

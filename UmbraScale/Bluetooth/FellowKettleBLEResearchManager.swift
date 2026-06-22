import Combine
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

    private func handleDiscovery(_ candidate: FellowKettleBLECandidate) {
        if let index = candidates.firstIndex(where: { $0.id == candidate.id }) {
            candidates[index] = candidate
        } else {
            candidates.append(candidate)
        }
    }

    private func handleServices(_ services: [String]) {
        session.serviceSummaries = services.map(FellowKettleBLEServiceSummary.init(uuid:))
    }

    private func handleCharacteristics(_ characteristics: [FellowKettleBLECharacteristicDiscovery]) {
        session.characteristicSummaries = characteristics.map {
            FellowKettleBLECharacteristicSummary(
                serviceUUID: $0.serviceUUID,
                uuid: $0.uuid,
                properties: $0.properties
            )
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

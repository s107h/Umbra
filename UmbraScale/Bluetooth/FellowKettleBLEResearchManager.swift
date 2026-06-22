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
                        self.candidates.append(candidate)
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
}

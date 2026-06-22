import Foundation
import Testing
@testable import FellowKettleManagerSupport

@MainActor
struct FellowKettleBLEResearchManagerTests {
    @Test func startingScanClearsOldEvidenceAndPublishesSearchingState() async {
        let environment = TestFellowKettleBLEEnvironment()
        let manager = FellowKettleBLEResearchManager(environment: environment)

        manager.startScanning()

        #expect(manager.state == .scanning)
        #expect(manager.candidates.isEmpty)
        #expect(manager.session == .empty)
    }

    @Test func selectingCandidateStartsInspectionWithoutChangingConfiguredHost() async throws {
        let environment = TestFellowKettleBLEEnvironment()
        let manager = FellowKettleBLEResearchManager(environment: environment)
        let candidate = FellowKettleBLECandidate(id: UUID(), name: "Fellow Stagg EKG Pro", rssi: -41)

        manager.startScanning()
        await environment.emitDiscovery(candidate)
        try await waitUntil { manager.candidates.count == 1 }

        manager.inspectCandidate(candidate.id)

        #expect(manager.state == .connecting(name: "Fellow Stagg EKG Pro"))
        #expect(manager.session.endpointCandidates.isEmpty)
    }
}

private actor TestFellowKettleBLEEnvironment: FellowKettleBLEResearchEnvironment {
    private var discoveryContinuation: AsyncStream<FellowKettleBLECandidate>.Continuation?
    private var serviceContinuation: AsyncStream<[String]>.Continuation?
    private var characteristicContinuation: AsyncStream<[FellowKettleBLECharacteristicDiscovery]>.Continuation?
    private var readContinuation: AsyncStream<(String, Data)>.Continuation?
    private var notifyContinuation: AsyncStream<(String, Data)>.Continuation?

    nonisolated let discoveries: AsyncStream<FellowKettleBLECandidate>
    nonisolated let serviceDiscoveries: AsyncStream<[String]>
    nonisolated let characteristicDiscoveries: AsyncStream<[FellowKettleBLECharacteristicDiscovery]>
    nonisolated let readEvents: AsyncStream<(String, Data)>
    nonisolated let notifyEvents: AsyncStream<(String, Data)>

    init() {
        var discoveryContinuation: AsyncStream<FellowKettleBLECandidate>.Continuation?
        discoveries = AsyncStream { discoveryContinuation = $0 }
        self.discoveryContinuation = discoveryContinuation

        var serviceContinuation: AsyncStream<[String]>.Continuation?
        serviceDiscoveries = AsyncStream { serviceContinuation = $0 }
        self.serviceContinuation = serviceContinuation

        var characteristicContinuation: AsyncStream<[FellowKettleBLECharacteristicDiscovery]>.Continuation?
        characteristicDiscoveries = AsyncStream { characteristicContinuation = $0 }
        self.characteristicContinuation = characteristicContinuation

        var readContinuation: AsyncStream<(String, Data)>.Continuation?
        readEvents = AsyncStream { readContinuation = $0 }
        self.readContinuation = readContinuation

        var notifyContinuation: AsyncStream<(String, Data)>.Continuation?
        notifyEvents = AsyncStream { notifyContinuation = $0 }
        self.notifyContinuation = notifyContinuation
    }

    func startScanning() {}

    func stopScanning() {}

    func connect(id: UUID) {
        _ = id
    }

    func disconnect() {}

    func emitDiscovery(_ candidate: FellowKettleBLECandidate) {
        discoveryContinuation?.yield(candidate)
    }
}

private enum FellowKettleBLEResearchManagerTestError: Error {
    case timedOut
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(TimeInterval(timeoutNanoseconds) / 1_000_000_000)

    while Date() < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    throw FellowKettleBLEResearchManagerTestError.timedOut
}

import Foundation
import Testing
@testable import FellowKettleManagerSupport

@MainActor
struct FellowKettleDiscoveryManagerTests {
    @Test func mdnsEndpointIsPublishedImmediately() async throws {
        let mdns = TestMDNSBrowser()
        let ble = TestBLEResolver()
        let manager = FellowKettleDiscoveryManager(mdnsBrowser: mdns, bleResolver: ble)

        manager.start()
        await mdns.emit(
            FellowKettleDiscoveryCandidate(
                id: "mdns-1",
                source: .mdns,
                displayName: "Stagg",
                resolvedBaseURL: URL(string: "http://192.168.1.86"),
                bleIdentifier: nil
            )
        )

        try await waitUntil { manager.candidates.count == 1 }
        #expect(manager.autoAdoptableCandidate?.resolvedBaseURL?.absoluteString == "http://192.168.1.86")
        #expect(manager.discoveryState == .discovering(manager.candidates))
    }

    @Test func bleCandidateRequiresResolutionBeforeAdoption() async throws {
        let mdns = TestMDNSBrowser()
        let ble = TestBLEResolver()
        let manager = FellowKettleDiscoveryManager(mdnsBrowser: mdns, bleResolver: ble)

        manager.start()
        let identifier = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        await ble.emitSighting(id: identifier, name: "Fellow")

        try await waitUntil { manager.candidates.count == 1 }
        #expect(manager.autoAdoptableCandidate == nil)

        await ble.setResolvedBaseURL(URL(string: "http://192.168.1.90"))
        await ble.emitSighting(id: identifier, name: "Fellow")

        try await waitUntil { manager.autoAdoptableCandidate != nil }
        #expect(manager.candidates.count == 1)
        #expect(manager.candidates[0].source == .bleResolved)
        #expect(manager.autoAdoptableCandidate?.resolvedBaseURL?.absoluteString == "http://192.168.1.90")
    }
}

private actor TestMDNSBrowser: FellowKettleMDNSBrowsing {
    private var continuation: AsyncStream<FellowKettleDiscoveryCandidate>.Continuation?
    nonisolated let updates: AsyncStream<FellowKettleDiscoveryCandidate>

    init() {
        var capturedContinuation: AsyncStream<FellowKettleDiscoveryCandidate>.Continuation?
        self.updates = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    func start() async {}

    func stop() async {
        continuation?.finish()
    }

    func emit(_ candidate: FellowKettleDiscoveryCandidate) {
        continuation?.yield(candidate)
    }
}

private actor TestBLEResolver: FellowKettleBLEResolving {
    private var continuation: AsyncStream<(UUID, String)>.Continuation?
    private var resolvedBaseURL: URL?
    nonisolated let sightings: AsyncStream<(UUID, String)>

    init() {
        var capturedContinuation: AsyncStream<(UUID, String)>.Continuation?
        self.sightings = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
    }

    func start() async {}

    func stop() async {
        continuation?.finish()
    }

    func resolveBaseURL(for identifier: UUID) async -> URL? {
        _ = identifier
        return resolvedBaseURL
    }

    func setResolvedBaseURL(_ url: URL?) {
        resolvedBaseURL = url
    }

    func emitSighting(id: UUID, name: String) {
        continuation?.yield((id, name))
    }
}

private enum DiscoveryManagerTestError: Error {
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

    throw DiscoveryManagerTestError.timedOut
}

import Foundation
import Testing
@testable import FellowKettleManagerSupport

struct FellowKettleDiscoverySupportTests {
    @Test func singleResolvedEndpointIsAutoAdoptable() {
        let candidate = FellowKettleDiscoveryCandidate(
            id: "mdns-kettle",
            source: .mdns,
            displayName: "Stagg EKG Pro",
            resolvedBaseURL: URL(string: "http://192.168.1.86"),
            bleIdentifier: nil
        )

        #expect(FellowKettleDiscoveryCandidate.autoAdoptableCandidate(from: [candidate]) == candidate)
    }

    @Test func incompleteBleCandidateIsNotAutoAdoptable() {
        let candidate = FellowKettleDiscoveryCandidate(
            id: "ble-only",
            source: .ble,
            displayName: "Fellow",
            resolvedBaseURL: nil,
            bleIdentifier: UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )

        #expect(FellowKettleDiscoveryCandidate.autoAdoptableCandidate(from: [candidate]) == nil)
    }

    @Test func multipleResolvedCandidatesBecomeConflict() {
        let candidates = [
            FellowKettleDiscoveryCandidate(
                id: "a",
                source: .mdns,
                displayName: "Stagg A",
                resolvedBaseURL: URL(string: "http://192.168.1.10"),
                bleIdentifier: nil
            ),
            FellowKettleDiscoveryCandidate(
                id: "b",
                source: .bleResolved,
                displayName: "Stagg B",
                resolvedBaseURL: URL(string: "http://192.168.1.11"),
                bleIdentifier: UUID()
            )
        ]

        #expect(FellowKettleDiscoveryState.from(candidates).isConflict)
    }
}

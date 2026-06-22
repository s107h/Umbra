import CoreBluetooth
import Foundation
import Testing
@testable import FellowKettleManagerSupport

struct FellowKettleBLEResearchSupportTests {
    @Test func likelyKettleNameMatchingUsesStrongTokensOnly() {
        #expect(FellowKettleBLEProtocol.isLikelyKettleName("Fellow Stagg EKG Pro"))
        #expect(FellowKettleBLEProtocol.isLikelyKettleName("stagg"))
        #expect(!FellowKettleBLEProtocol.isLikelyKettleName("Kitchen Speaker"))
        #expect(!FellowKettleBLEProtocol.isLikelyKettleName("   "))
    }

    @Test func payloadFormattingIncludesUppercasedUuidAndHex() {
        let data = Data([0x01, 0xAF, 0x10])
        let line = FellowKettleBLEProtocol.payloadLog(
            kind: "notify",
            characteristicUUID: "180A",
            data: data
        )

        #expect(line == "Fellow BLE notify characteristic=180A bytes=3 hex=01 AF 10")
    }

    @Test func sessionSummaryOnlyReturnsEndpointCandidates() {
        let session = FellowKettleBLEResearchSession(
            advertisementEvents: [],
            serviceSummaries: [],
            characteristicSummaries: [],
            readEvents: [],
            notificationEvents: [],
            endpointCandidates: [
                FellowKettleBLEEndpointCandidate(source: "Manufacturer Data", value: "192.168.1.20"),
                FellowKettleBLEEndpointCandidate(source: "Characteristic 180A", value: "stagg.local")
            ]
        )

        #expect(session.endpointCandidates.count == 2)
    }
}

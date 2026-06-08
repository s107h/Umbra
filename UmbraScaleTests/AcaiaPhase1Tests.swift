import Foundation
import Testing
@testable import UmbraScaleSupport

struct AcaiaPhase1Tests {
    @Test func stateDisplayTextReflectsCurrentStatus() {
        #expect(AcaiaScaleState.bluetoothReady.displayText == "Bluetooth ready")
        #expect(AcaiaScaleState.scanning.displayText == "Scanning for nearby scales...")
        #expect(AcaiaScaleState.subscribing(name: "Umbra").displayText == "Subscribing to Umbra...")
        #expect(AcaiaScaleState.handshaking(name: "Umbra").displayText == "Starting scale stream for Umbra...")
        #expect(AcaiaScaleState.connected(name: "Umbra").displayText == "Connected to Umbra")
    }

    @Test func candidateMatcherAcceptsKnownAcaiaNames() {
        #expect(AcaiaProtocol.isLikelyScaleName("ACAIA UMBRA"))
        #expect(AcaiaProtocol.isLikelyScaleName("Lunar-202"))
        #expect(AcaiaProtocol.isLikelyScaleName("Pearl S"))
    }

    @Test func candidateMatcherRejectsUnrelatedNames() {
        #expect(!AcaiaProtocol.isLikelyScaleName("Kitchen Speaker"))
        #expect(!AcaiaProtocol.isLikelyScaleName("Unknown Device"))
        #expect(!AcaiaProtocol.isLikelyScaleName(""))
    }

    @Test func characteristicSelectionPrefersKnownAcaiaUUIDs() {
        let writeRole = AcaiaProtocol.characteristicRole(
            uuidString: "49535343-8841-43F4-A8D4-ECBE34729BB3",
            canWrite: true,
            canWriteWithoutResponse: true,
            canNotify: false,
            canIndicate: false
        )
        let notifyRole = AcaiaProtocol.characteristicRole(
            uuidString: "49535343-1E4D-4BD9-BA61-23C647249616",
            canWrite: false,
            canWriteWithoutResponse: false,
            canNotify: true,
            canIndicate: false
        )

        #expect(writeRole?.useForWrite == true)
        #expect(writeRole?.useForNotify == false)
        #expect(notifyRole?.useForWrite == false)
        #expect(notifyRole?.useForNotify == true)
    }

    @Test func characteristicSelectionFallsBackToLegacyDualRoleCharacteristic() {
        let legacyRole = AcaiaProtocol.characteristicRole(
            uuidString: "2A80",
            canWrite: true,
            canWriteWithoutResponse: false,
            canNotify: true,
            canIndicate: false
        )

        #expect(legacyRole?.useForWrite == true)
        #expect(legacyRole?.useForNotify == true)
    }

    @Test func characteristicSelectionSupportsUmbraSpecificPair() {
        let writeRole = AcaiaProtocol.characteristicRole(
            uuidString: "0000FE41-8E22-4541-9D4C-21EDAE82ED19",
            canWrite: false,
            canWriteWithoutResponse: true,
            canNotify: false,
            canIndicate: false
        )
        let notifyRole = AcaiaProtocol.characteristicRole(
            uuidString: "0000FE42-8E22-4541-9D4C-21EDAE82ED19",
            canWrite: false,
            canWriteWithoutResponse: false,
            canNotify: true,
            canIndicate: false
        )

        #expect(writeRole?.useForWrite == true)
        #expect(writeRole?.useForNotify == false)
        #expect(notifyRole?.useForWrite == false)
        #expect(notifyRole?.useForNotify == true)
    }

    @Test func incomingPayloadLogIncludesUUIDByteCountAndHex() {
        let message = AcaiaProtocol.incomingPayloadLog(
            uuidString: "49535343-1E4D-4BD9-BA61-23C647249616",
            data: Data([0xEF, 0xDD, 0x01, 0x02])
        )

        #expect(message == "RX characteristic=49535343-1E4D-4BD9-BA61-23C647249616 bytes=4 hex=EF DD 01 02")
    }

    @Test func loggerExportTextJoinsLinesWithNewlines() async {
        let logger = await BLELogger()
        await logger.log("First line")
        await logger.log("Second line")

        let exported = await logger.exportText

        #expect(exported.contains("First line"))
        #expect(exported.contains("Second line"))
        #expect(exported.contains("\n"))
    }

    @Test func softwareZeroSubtractsCurrentBaselineFromDisplayedReading() async {
        let manager = await AcaiaScaleManager()
        await MainActor.run {
            manager.replaceReadingForTesting(ScaleReading(grams: 0.8, isStable: true, timestamp: .now))
            manager.zeroDisplay()
        }

        let displayed = await MainActor.run { manager.displayedReading }
        let zeroOffset = await MainActor.run { manager.zeroOffsetGrams }

        #expect(displayed.grams == 0)
        #expect(zeroOffset == 0.8)
    }

    @Test func clearingSoftwareZeroRestoresRawDisplayedWeight() async {
        let manager = await AcaiaScaleManager()
        await MainActor.run {
            manager.replaceReadingForTesting(ScaleReading(grams: 5.0, isStable: true, timestamp: .now))
            manager.zeroDisplay()
            manager.replaceReadingForTesting(ScaleReading(grams: 7.3, isStable: true, timestamp: .now))
            manager.clearZeroOffset()
        }

        let displayed = await MainActor.run { manager.displayedReading }
        let zeroOffset = await MainActor.run { manager.zeroOffsetGrams }

        #expect(displayed.grams == 7.3)
        #expect(zeroOffset == 0)
    }

    @MainActor
    @Test func startupOutlierFilterRejectsLargeUnstableSpikeBeforeSettling() {
        let shouldIgnore = AcaiaScaleManager.shouldIgnoreStartupOutlier(
            reading: ScaleReading(grams: 145.8, isStable: false, timestamp: .now),
            elapsedSinceStreamStart: 0.2,
            hasAcceptedStableReading: false
        )

        #expect(shouldIgnore)
    }

    @MainActor
    @Test func startupOutlierFilterKeepsStableQuarterReading() {
        let shouldIgnore = AcaiaScaleManager.shouldIgnoreStartupOutlier(
            reading: ScaleReading(grams: 5.7, isStable: true, timestamp: .now),
            elapsedSinceStreamStart: 8,
            hasAcceptedStableReading: true
        )

        #expect(!shouldIgnore)
    }

    @Test func protocolCommandPacketsMatchExpectedBytes() {
        #expect(AcaiaProtocol.identify == [
            0xEF, 0xDD, 0x0B,
            0x30, 0x31, 0x32, 0x33, 0x34,
            0x35, 0x36, 0x37, 0x38, 0x39,
            0x30, 0x31, 0x32, 0x33, 0x34,
            0x9A, 0x6D
        ])
        #expect(AcaiaProtocol.notificationRequest == [
            0xEF, 0xDD, 0x0C, 0x09,
            0x00, 0x01, 0x01, 0x02,
            0x02, 0x05, 0x03, 0x04,
            0x15, 0x06
        ])
        #expect(AcaiaProtocol.heartbeat == [
            0xEF, 0xDD, 0x00, 0x02, 0x00, 0x02, 0x00
        ])
    }

    @Test func weightParserDecodesCapturedUmbraWeightPacket() {
        let packet = Data([0xEF, 0xDD, 0x0C, 0x08, 0x05, 0x00, 0x00, 0x00, 0x56, 0x01, 0x0C, 0x09, 0x67])

        let result = AcaiaWeightParser.parse(packet)

        switch result {
        case .weight(let parsed):
            #expect(parsed.reading.grams == 8.6)
            #expect(parsed.reading.isStable == false)
            #expect(parsed.packetKind == "weight")
        case .status(let kind):
            Issue.record("Expected weight packet, got status: \(kind)")
        case .unknown(let reason):
            Issue.record("Expected weight packet, got unknown: \(reason)")
        }
    }

    @Test func weightParserDetectsStableZeroPacket() {
        let packet = Data([0xEF, 0xDD, 0x0C, 0x08, 0x05, 0x00, 0x00, 0x00, 0x00, 0x01, 0x0D, 0x09, 0x12])

        let result = AcaiaWeightParser.parse(packet)

        switch result {
        case .weight(let parsed):
            #expect(parsed.reading.grams == 0)
            #expect(parsed.reading.isStable == true)
            #expect(parsed.packetKind == "weight")
        case .status(let kind):
            Issue.record("Expected weight packet, got status: \(kind)")
        case .unknown(let reason):
            Issue.record("Expected weight packet, got unknown: \(reason)")
        }
    }

    @Test func weightParserDecodesObservedSubGramPacket() {
        let packet = Data([0xEF, 0xDD, 0x0C, 0x08, 0x05, 0x00, 0x00, 0x00, 0x08, 0x01, 0x0F, 0x09, 0x1C])

        let result = AcaiaWeightParser.parse(packet)

        switch result {
        case .weight(let parsed):
            #expect(parsed.reading.grams == 0.8)
            #expect(parsed.reading.isStable == false)
        case .status(let kind):
            Issue.record("Expected weight packet, got status: \(kind)")
        case .unknown(let reason):
            Issue.record("Expected weight packet, got unknown: \(reason)")
        }
    }

    @Test func weightParserDecodesObservedStableFiveGramPacket() {
        let packet = Data([0xEF, 0xDD, 0x0C, 0x08, 0x05, 0x00, 0x00, 0x00, 0x32, 0x01, 0x0D, 0x09, 0x44])

        let result = AcaiaWeightParser.parse(packet)

        switch result {
        case .weight(let parsed):
            #expect(parsed.reading.grams == 5.0)
            #expect(parsed.reading.isStable == true)
        case .status(let kind):
            Issue.record("Expected weight packet, got status: \(kind)")
        case .unknown(let reason):
            Issue.record("Expected weight packet, got unknown: \(reason)")
        }
    }

    @Test func weightParserRecognizesObservedStatusPacket() {
        let packet = Data([0xEF, 0xDD, 0x07, 0x07, 0x02, 0x1E, 0x01, 0x00, 0x03, 0x00, 0x25, 0x06])

        let result = AcaiaWeightParser.parse(packet)

        #expect(result == .status(kind: "status"))
    }

    @Test func weightParserLeavesUnknownPacketTypesNonFatal() {
        let packet = Data([0xEF, 0xDD, 0x08, 0x0D, 0x5A, 0x07, 0x01, 0x00, 0x01, 0x01, 0x01, 0x01, 0x00, 0x03, 0x20, 0xFF, 0x18, 0x7D])

        let result = AcaiaWeightParser.parse(packet)

        #expect(result == .unknown(reason: "Unsupported packet type 0x08 length=18"))
    }
}

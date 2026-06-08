import Foundation
import Testing
@testable import UmbraScaleSupport

struct FellowKettleSupportTests {
    @Test func requestEncodesStateCommand() throws {
        let url = try FellowKettleCLIRequest(baseURLString: "http://kettle.local", command: .state).url()
        #expect(url.absoluteString == "http://kettle.local/cli?cmd=state")
    }

    @Test func requestConvertsTargetCelsiusToWholeFahrenheit() throws {
        let url = try FellowKettleCLIRequest(
            baseURLString: "http://192.168.1.8",
            command: .setTargetCelsius(96.0)
        ).url()
        #expect(url.absoluteString == "http://192.168.1.8/cli?cmd=setsetting+settempr+205")
    }

    @Test func parserExtractsHeatingSnapshotFromStateOutput() throws {
        let body = """
        tempr=50.491463 C
        temprT=96.111115 C
        mode=S_Heat
        """

        let snapshot = try FellowKettleParser.parseState(body)

        #expect(snapshot.currentTemperatureCelsius == 50.491463)
        #expect(snapshot.targetTemperatureCelsius == 96.111115)
        #expect(snapshot.mode == .heating)
    }

    @Test func parserTreatsOffModeAsOff() throws {
        let body = """
        tempr=25.0 C
        temprT=90.0 C
        mode=S_Off
        """

        let snapshot = try FellowKettleParser.parseState(body)

        #expect(snapshot.mode == .off)
    }

    @Test func parserThrowsWhenStateResponseIsMissingMode() {
        let body = "tempr=50.0 C\ntemprT=95.0 C"
        #expect(throws: FellowKettleParser.ParseError.self) {
            try FellowKettleParser.parseState(body)
        }
    }
}

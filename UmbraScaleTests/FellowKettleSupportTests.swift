import Foundation
import Testing
@testable import FellowKettleSupport

struct FellowKettleSupportTests {
    @Test func requestEncodesStateCommand() throws {
        let url = try FellowKettleCLIRequest(baseURLString: "http://kettle.local", command: .state).url()
        #expect(url.absoluteString == "http://kettle.local/cli?cmd=state")
    }

    @Test func requestEncodesHeatOnCommand() throws {
        let url = try FellowKettleCLIRequest(baseURLString: "http://kettle.local", command: .heatOn).url()
        #expect(url.absoluteString == "http://kettle.local/cli?cmd=setstate%20S_Heat")
    }

    @Test func requestEncodesHeatOffCommand() throws {
        let url = try FellowKettleCLIRequest(baseURLString: "http://kettle.local", command: .heatOff).url()
        #expect(url.absoluteString == "http://kettle.local/cli?cmd=setstate%20S_Off")
    }

    @Test func requestConvertsTargetCelsiusToWholeFahrenheit() throws {
        let url = try FellowKettleCLIRequest(
            baseURLString: "http://192.168.1.8",
            command: .setTargetCelsius(96.0)
        ).url()
        #expect(url.absoluteString == "http://192.168.1.8/cli?cmd=setsetting%20settempr%20205")
    }

    @Test func requestRejectsBareHostString() {
        #expect(throws: URLError.self) {
            try FellowKettleCLIRequest(baseURLString: "kettle.local", command: .state).url()
        }
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

    @Test func parserConvertsFahrenheitValuesToCelsius() throws {
        let body = """
        tempr=122.0 F
        temprT=212.0 F
        mode=S_Heat
        """

        let snapshot = try FellowKettleParser.parseState(body)

        #expect(snapshot.currentTemperatureCelsius == 50.0)
        #expect(snapshot.targetTemperatureCelsius == 100.0)
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

    @Test func parserTreatsHoldModeAsHold() throws {
        let body = """
        tempr=25.0 C
        temprT=90.0 C
        mode=S_Hold
        """

        let snapshot = try FellowKettleParser.parseState(body)

        #expect(snapshot.mode == .hold)
    }

    @Test func parserTreatsStartupToTempModeAsHeating() throws {
        let body = """
        tempr=25.0 C
        temprT=90.0 C
        mode=S_STARTUPTOTEMPR
        """

        let snapshot = try FellowKettleParser.parseState(body)

        #expect(snapshot.mode == .heating)
    }

    @Test func parserThrowsWhenCurrentTemperatureIsMissing() {
        let body = "temprT=95.0 C\nmode=S_Heat"
        #expect(throws: FellowKettleParser.ParseError.missingTemperature) {
            try FellowKettleParser.parseState(body)
        }
    }

    @Test func parserThrowsWhenTargetTemperatureIsMissing() {
        let body = "tempr=50.0 C\nmode=S_Heat"
        #expect(throws: FellowKettleParser.ParseError.missingTargetTemperature) {
            try FellowKettleParser.parseState(body)
        }
    }

    @Test func parserThrowsWhenStateResponseIsMissingMode() {
        let body = "tempr=50.0 C\ntemprT=95.0 C"
        #expect(throws: FellowKettleParser.ParseError.self) {
            try FellowKettleParser.parseState(body)
        }
    }
}

import Foundation

public enum FellowKettleParser {
    public enum ParseError: Error, Equatable {
        case missingTemperature
        case missingTargetTemperature
        case missingMode
    }

    public static func parseState(_ body: String) throws -> FellowKettleSnapshot {
        guard let current = value(for: "tempr", in: body) else {
            throw ParseError.missingTemperature
        }
        guard let target = value(for: "temprT", in: body) else {
            throw ParseError.missingTargetTemperature
        }
        guard let mode = stringValue(for: "mode", in: body) else {
            throw ParseError.missingMode
        }

        return FellowKettleSnapshot(
            currentTemperatureCelsius: current,
            targetTemperatureCelsius: target,
            mode: FellowKettleMode(rawMode: mode)
        )
    }

    private static func value(for label: String, in body: String) -> Double? {
        let pattern = #"(?m)^\s*\#(label)\s*=\s*(-?\d+(?:\.\d+)?)\s*([CFcf])?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let numericRange = Range(match.range(at: 1), in: body),
              let numeric = Double(body[numericRange]) else {
            return nil
        }

        if let unitRange = Range(match.range(at: 2), in: body),
           body[unitRange].uppercased() == "F" {
            return (numeric - 32) / 1.8
        }

        return numeric
    }

    private static func stringValue(for label: String, in body: String) -> String? {
        let pattern = #"(?m)^\s*\#(label)\s*=\s*([A-Za-z0-9_]+)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let valueRange = Range(match.range(at: 1), in: body) else {
            return nil
        }

        return String(body[valueRange])
    }
}

import Foundation

public enum FellowKettleParser {
    public enum ParseError: Error, Equatable {
        case missingTemperature
        case invalidTemperature
        case missingTargetTemperature
        case invalidTargetTemperature
        case missingMode
        case invalidMode
    }

    public static func parseState(_ body: String) throws -> FellowKettleSnapshot {
        let current = try temperatureValue(for: "tempr", missingError: .missingTemperature, invalidError: .invalidTemperature, in: body)
        let target = try temperatureValue(for: "temprT", missingError: .missingTargetTemperature, invalidError: .invalidTargetTemperature, in: body)
        let mode = try modeValue(in: body)

        return FellowKettleSnapshot(
            currentTemperatureCelsius: current,
            targetTemperatureCelsius: target,
            mode: FellowKettleMode(rawMode: mode)
        )
    }

    private static func temperatureValue(
        for label: String,
        missingError: ParseError,
        invalidError: ParseError,
        in body: String
    ) throws -> Double {
        guard let rawValue = fieldValue(for: label, in: body) else {
            throw missingError
        }

        let tokens = rawValue.split(whereSeparator: \.isWhitespace)
        guard let numericText = tokens.first,
              let numeric = Double(numericText) else {
            throw invalidError
        }

        if tokens.count > 2 {
            throw invalidError
        }

        if tokens.count == 2 {
            let unit = tokens[1].uppercased()
            guard unit == "F" || unit == "C" else {
                throw invalidError
            }
            if unit == "F" {
                return (numeric - 32) / 1.8
            }
        }

        return numeric
    }

    private static func modeValue(in body: String) throws -> String {
        guard let rawValue = fieldValue(for: "mode", in: body) else {
            throw ParseError.missingMode
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ParseError.invalidMode
        }

        return trimmed
    }

    private static func fieldValue(for label: String, in body: String) -> String? {
        let pattern = #"(?m)^\s*\#(label)\s*=\s*(.*?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let valueRange = Range(match.range(at: 1), in: body) else {
            return nil
        }

        return String(body[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

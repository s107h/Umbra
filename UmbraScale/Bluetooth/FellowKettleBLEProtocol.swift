@preconcurrency import CoreBluetooth
import Foundation

enum FellowKettleBLEProtocol {
    nonisolated private static let knownNameTokens = ["FELLOW", "STAGG", "EKG"]

    nonisolated static func isLikelyKettleName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return knownNameTokens.contains { normalized.contains($0) }
    }

    nonisolated static func propertyNames(for properties: CBCharacteristicProperties) -> [String] {
        var names: [String] = []

        if properties.contains(.read) { names.append("read") }
        if properties.contains(.write) { names.append("write") }
        if properties.contains(.writeWithoutResponse) { names.append("writeWithoutResponse") }
        if properties.contains(.notify) { names.append("notify") }
        if properties.contains(.indicate) { names.append("indicate") }

        return names
    }

    nonisolated static func payloadLog(kind: String, characteristicUUID: String, data: Data) -> String {
        "Fellow BLE \(kind) characteristic=\(characteristicUUID.uppercased()) bytes=\(data.count) hex=\(data.hexString)"
    }

    nonisolated static func endpointCandidates(in data: Data) -> [String] {
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return [] }

        let patterns = [
            #"\b(?:\d{1,3}\.){3}\d{1,3}\b"#,
            #"\b[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+\b"#
        ]

        var matches: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for result in regex.matches(in: text, range: range) {
                guard let matchRange = Range(result.range, in: text) else { continue }
                let value = String(text[matchRange])
                if !matches.contains(value) {
                    matches.append(value)
                }
            }
        }

        return matches
    }
}

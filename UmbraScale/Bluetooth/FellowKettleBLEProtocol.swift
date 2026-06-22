@preconcurrency import CoreBluetooth
import Foundation

enum FellowKettleBLEProtocol {
    private static let knownNameTokens = ["FELLOW", "STAGG", "EKG"]

    static func isLikelyKettleName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return knownNameTokens.contains { normalized.contains($0) }
    }

    static func propertyNames(for properties: CBCharacteristicProperties) -> [String] {
        var names: [String] = []

        if properties.contains(.read) { names.append("read") }
        if properties.contains(.write) { names.append("write") }
        if properties.contains(.writeWithoutResponse) { names.append("writeWithoutResponse") }
        if properties.contains(.notify) { names.append("notify") }
        if properties.contains(.indicate) { names.append("indicate") }

        return names
    }

    static func payloadLog(kind: String, characteristicUUID: String, data: Data) -> String {
        "Fellow BLE \(kind) characteristic=\(characteristicUUID.uppercased()) bytes=\(data.count) hex=\(data.hexString)"
    }
}

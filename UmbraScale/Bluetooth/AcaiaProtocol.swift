import Foundation

enum AcaiaProtocol {
    struct CharacteristicRole: Equatable {
        let useForWrite: Bool
        let useForNotify: Bool
    }

    static let identify: [UInt8] = [
        0xEF, 0xDD, 0x0B,
        0x30, 0x31, 0x32, 0x33, 0x34,
        0x35, 0x36, 0x37, 0x38, 0x39,
        0x30, 0x31, 0x32, 0x33, 0x34,
        0x9A, 0x6D
    ]

    static let notificationRequest: [UInt8] = [
        0xEF, 0xDD, 0x0C, 0x09,
        0x00, 0x01, 0x01, 0x02,
        0x02, 0x05, 0x03, 0x04,
        0x15, 0x06
    ]

    static let heartbeat: [UInt8] = [
        0xEF, 0xDD, 0x00, 0x02, 0x00, 0x02, 0x00
    ]

    private static let knownNameTokens = [
        "ACAIA",
        "UMBRA",
        "LUNAR",
        "PEARL",
        "PYXIS",
        "CINCO",
        "PROCH"
    ]

    static func isLikelyScaleName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return knownNameTokens.contains { normalized.contains($0) }
    }

    static func characteristicRole(
        uuidString: String,
        canWrite: Bool,
        canWriteWithoutResponse: Bool,
        canNotify: Bool,
        canIndicate: Bool
    ) -> CharacteristicRole? {
        let normalized = uuidString.uppercased()

        if normalized == "49535343-8841-43F4-A8D4-ECBE34729BB3" {
            return CharacteristicRole(
                useForWrite: canWrite || canWriteWithoutResponse,
                useForNotify: false
            )
        }

        if normalized == "49535343-1E4D-4BD9-BA61-23C647249616" {
            return CharacteristicRole(
                useForWrite: false,
                useForNotify: canNotify || canIndicate
            )
        }

        if normalized == "0000FE41-8E22-4541-9D4C-21EDAE82ED19" {
            return CharacteristicRole(
                useForWrite: canWrite || canWriteWithoutResponse,
                useForNotify: false
            )
        }

        if normalized == "0000FE42-8E22-4541-9D4C-21EDAE82ED19" {
            return CharacteristicRole(
                useForWrite: false,
                useForNotify: canNotify || canIndicate
            )
        }

        if normalized == "2A80" {
            return CharacteristicRole(
                useForWrite: canWrite || canWriteWithoutResponse,
                useForNotify: canNotify || canIndicate
            )
        }

        return nil
    }

    static func incomingPayloadLog(uuidString: String, data: Data) -> String {
        "RX characteristic=\(uuidString.uppercased()) bytes=\(data.count) hex=\(data.hexString)"
    }
}

import Foundation

enum AcaiaWeightParser {
    struct ParsedPacket: Equatable {
        let reading: ScaleReading
        let packetKind: String
    }

    enum ParseResult: Equatable {
        case weight(ParsedPacket)
        case status(kind: String)
        case unknown(reason: String)
    }

    static func parse(_ data: Data) -> ParseResult {
        let bytes = Array(data)

        guard bytes.count >= 5 else {
            return .unknown(reason: "Packet too short")
        }

        guard bytes[0] == 0xEF, bytes[1] == 0xDD else {
            return .unknown(reason: "Unexpected packet header")
        }

        if bytes.count == 13, bytes[2] == 0x0C, bytes[3] == 0x08, bytes[4] == 0x05 {
            return parseWeightPacket(bytes)
        }

        if bytes.count == 12, bytes[2] == 0x07, bytes[3] == 0x07, bytes[4] == 0x02 {
            return .status(kind: "status")
        }

        return .unknown(reason: "Unsupported packet type 0x\(hex(bytes[2])) length=\(bytes.count)")
    }

    private static func parseWeightPacket(_ bytes: [UInt8]) -> ParseResult {
        let rawValue = Int32(bigEndianBytes: Array(bytes[5...8]))
        let exponent = Int(bytes[9])
        let divisor = pow(10.0, Double(exponent))
        let grams = Double(rawValue) / divisor
        let isStable = bytes[10] == 0x0D

        return .weight(
            ParsedPacket(
                reading: ScaleReading(grams: grams, isStable: isStable, timestamp: .now),
                packetKind: "weight"
            )
        )
    }

    private static func hex(_ byte: UInt8) -> String {
        String(format: "%02X", byte)
    }
}

private extension Int32 {
    init(bigEndianBytes bytes: [UInt8]) {
        precondition(bytes.count == 4)

        let bitPattern =
            (UInt32(bytes[0]) << 24) |
            (UInt32(bytes[1]) << 16) |
            (UInt32(bytes[2]) << 8) |
            UInt32(bytes[3])

        self = Int32(bitPattern: bitPattern)
    }
}

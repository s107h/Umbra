@preconcurrency import CoreBluetooth

@MainActor
enum AcaiaBLEUUIDs {
    static let oldReadWrite = CBUUID(string: "2A80")
    static let newWrite = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    static let newNotify = CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647249616")
    static let umbraWrite = CBUUID(string: "0000FE41-8E22-4541-9D4C-21EDAE82ED19")
    static let umbraNotify = CBUUID(string: "0000FE42-8E22-4541-9D4C-21EDAE82ED19")
}

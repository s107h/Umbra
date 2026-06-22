import Foundation

enum FellowKettleBLEResearchState: Equatable {
    case idle
    case scanning
    case connecting(name: String)
    case discoveringServices(name: String)
    case discoveringCharacteristics(name: String)
    case capturing(name: String)
    case disconnected
    case error(String)
}

extension FellowKettleBLEResearchState {
    var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .scanning:
            return "Scanning"
        case .connecting(let name):
            return "Connecting to \(name)"
        case .discoveringServices(let name):
            return "Discovering services for \(name)"
        case .discoveringCharacteristics(let name):
            return "Discovering characteristics for \(name)"
        case .capturing(let name):
            return "Capturing BLE evidence from \(name)"
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

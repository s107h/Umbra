import Foundation

enum AcaiaScaleState: Equatable {
    case idle
    case bluetoothUnavailable(String)
    case bluetoothReady
    case scanning
    case discovered(name: String)
    case connecting(name: String)
    case discoveringServices(name: String)
    case subscribing(name: String)
    case handshaking(name: String)
    case connected(name: String)
    case disconnected
    case error(String)
}

extension AcaiaScaleState {
    var displayText: String {
        switch self {
        case .idle:
            return "Idle"
        case .bluetoothUnavailable(let reason):
            return "Bluetooth unavailable: \(reason)"
        case .bluetoothReady:
            return "Bluetooth ready"
        case .scanning:
            return "Scanning for nearby scales..."
        case .discovered(let name):
            return "Found \(name)"
        case .connecting(let name):
            return "Connecting to \(name)..."
        case .discoveringServices(let name):
            return "Discovering services for \(name)..."
        case .subscribing(let name):
            return "Subscribing to \(name)..."
        case .handshaking(let name):
            return "Starting scale stream for \(name)..."
        case .connected(let name):
            return "Connected to \(name)"
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

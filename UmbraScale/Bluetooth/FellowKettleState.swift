import Foundation

enum FellowKettleState: Equatable {
    case unconfigured
    case configured(host: String)
    case polling(host: String)
    case ready(host: String)
    case commandInFlight(host: String, command: String)
    case error(host: String?, message: String)

    var displayText: String {
        switch self {
        case .unconfigured:
            return "Enter kettle host"
        case .configured(let host):
            return "Configured host \(host)"
        case .polling(let host):
            return "Polling \(host)..."
        case .ready(let host):
            return "Connected to \(host)"
        case .commandInFlight(_, let command):
            return "Sending \(command)..."
        case .error(_, let message):
            return "Error: \(message)"
        }
    }
}

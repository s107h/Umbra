import Foundation

public struct FellowKettleCLIRequest: Equatable {
    public enum Command: Equatable {
        case state
        case heatOn
        case heatOff
        case setTargetCelsius(Double)

        var rawValue: String {
            switch self {
            case .state:
                return "state"
            case .heatOn:
                return "setstate S_Heat"
            case .heatOff:
                return "setstate S_Off"
            case .setTargetCelsius(let celsius):
                let fahrenheit = Int((celsius * 1.8 + 32).rounded())
                return "setsetting settempr \(fahrenheit)"
            }
        }
    }

    public let baseURLString: String
    public let command: Command

    public init(baseURLString: String, command: Command) {
        self.baseURLString = baseURLString
        self.command = command
    }

    public func url() throws -> URL {
        guard var components = URLComponents(string: baseURLString),
              components.scheme != nil,
              components.host != nil else {
            throw URLError(.badURL)
        }

        components.path = "/cli"
        components.queryItems = [
            URLQueryItem(name: "cmd", value: command.rawValue)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
}

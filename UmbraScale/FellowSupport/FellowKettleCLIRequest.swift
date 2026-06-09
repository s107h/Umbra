import Foundation

public struct FellowKettleCLIRequest: Equatable {
    public enum Command: Equatable {
        case state
        case heatOn
        case heatOff
        case setTargetCelsius(Double)

        func rawValue() throws -> String {
            switch self {
            case .state:
                return "state"
            case .heatOn:
                return "setstate S_Heat"
            case .heatOff:
                return "setstate S_Off"
            case .setTargetCelsius(let celsius):
                guard celsius.isFinite else {
                    throw URLError(.badURL)
                }
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
        let commandValue = try command.rawValue()
        components.queryItems = [
            URLQueryItem(name: "cmd", value: commandValue)
        ]

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }
}

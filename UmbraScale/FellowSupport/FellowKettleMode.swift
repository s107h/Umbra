import Foundation

public enum FellowKettleMode: Equatable {
    case off
    case heating
    case hold
    case other(String)

    public init(rawMode: String) {
        switch rawMode.uppercased() {
        case "S_OFF":
            self = .off
        case "S_HEAT", "S_STARTUPTOTEMPR":
            self = .heating
        case "S_HOLD":
            self = .hold
        default:
            self = .other(rawMode)
        }
    }
}

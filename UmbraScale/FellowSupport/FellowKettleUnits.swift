import Foundation

public enum FellowKettleUnits: String, CaseIterable, Equatable {
    case celsius
    case fahrenheit

    init?(stateValue: String) {
        switch stateValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "1":
            self = .celsius
        case "0":
            self = .fahrenheit
        default:
            return nil
        }
    }
}

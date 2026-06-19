import Foundation

public struct FellowKettleSettingsSnapshot: Equatable {
    public let units: FellowKettleUnits?
    public let holdDuration: FellowKettleHoldDuration?

    public init(units: FellowKettleUnits?, holdDuration: FellowKettleHoldDuration?) {
        self.units = units
        self.holdDuration = holdDuration
    }
}

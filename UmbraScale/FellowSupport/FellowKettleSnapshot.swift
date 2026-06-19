import Foundation

public struct FellowKettleSnapshot: Equatable {
    public let currentTemperatureCelsius: Double
    public let targetTemperatureCelsius: Double
    public let mode: FellowKettleMode
    public let units: FellowKettleUnits?
    public let holdDuration: FellowKettleHoldDuration?

    public init(
        currentTemperatureCelsius: Double,
        targetTemperatureCelsius: Double,
        mode: FellowKettleMode,
        units: FellowKettleUnits? = nil,
        holdDuration: FellowKettleHoldDuration? = nil
    ) {
        self.currentTemperatureCelsius = currentTemperatureCelsius
        self.targetTemperatureCelsius = targetTemperatureCelsius
        self.mode = mode
        self.units = units
        self.holdDuration = holdDuration
    }
}

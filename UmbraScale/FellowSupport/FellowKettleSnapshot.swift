import Foundation

public struct FellowKettleSnapshot: Equatable {
    public let currentTemperatureCelsius: Double
    public let targetTemperatureCelsius: Double
    public let mode: FellowKettleMode

    public init(currentTemperatureCelsius: Double, targetTemperatureCelsius: Double, mode: FellowKettleMode) {
        self.currentTemperatureCelsius = currentTemperatureCelsius
        self.targetTemperatureCelsius = targetTemperatureCelsius
        self.mode = mode
    }
}

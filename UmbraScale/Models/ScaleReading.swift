import Foundation

struct ScaleReading: Equatable {
    var grams: Double
    var isStable: Bool?
    var timestamp: Date

    static let zero = ScaleReading(grams: 0, isStable: nil, timestamp: .now)
}

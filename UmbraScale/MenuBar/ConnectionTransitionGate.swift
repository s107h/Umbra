import Foundation

struct ConnectionTransitionGate {
    private var wasConnected = false

    mutating func consume(isConnected: Bool) -> Bool {
        defer { wasConnected = isConnected }
        return wasConnected == false && isConnected == true
    }
}

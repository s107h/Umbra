import Foundation

enum FellowKettleBLEResearchState: Equatable {
    case idle
    case scanning
    case connecting(name: String)
    case disconnected
    case error(String)
}

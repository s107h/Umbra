import Foundation

enum FellowKettleDiscoverySource: Equatable {
    case mdns
    case ble
    case bleResolved
}

struct FellowKettleDiscoveryCandidate: Equatable, Identifiable {
    let id: String
    let source: FellowKettleDiscoverySource
    let displayName: String
    let resolvedBaseURL: URL?
    let bleIdentifier: UUID?

    var hasUsableEndpoint: Bool {
        guard let resolvedBaseURL else { return false }
        return resolvedBaseURL.scheme != nil && resolvedBaseURL.host != nil
    }

    static func autoAdoptableCandidate(from candidates: [FellowKettleDiscoveryCandidate]) -> FellowKettleDiscoveryCandidate? {
        let resolvedCandidates = candidates.filter(\.hasUsableEndpoint)
        guard resolvedCandidates.count == 1 else { return nil }
        return resolvedCandidates[0]
    }
}

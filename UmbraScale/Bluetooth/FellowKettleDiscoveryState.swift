import Foundation

enum FellowKettleDiscoveryState: Equatable {
    case idle
    case discovering([FellowKettleDiscoveryCandidate])
    case conflict([FellowKettleDiscoveryCandidate])

    var isConflict: Bool {
        if case .conflict = self {
            return true
        }
        return false
    }

    static func from(_ candidates: [FellowKettleDiscoveryCandidate]) -> FellowKettleDiscoveryState {
        let resolvedCandidateCount = candidates.filter(\.hasUsableEndpoint).count
        if resolvedCandidateCount > 1 {
            return .conflict(candidates)
        }
        return .discovering(candidates)
    }
}

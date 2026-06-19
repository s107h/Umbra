import Foundation

protocol FellowKettleMDNSBrowsing: Sendable {
    var updates: AsyncStream<FellowKettleDiscoveryCandidate> { get }
    func start() async
    func stop() async
}

protocol FellowKettleBLEResolving: Sendable {
    var sightings: AsyncStream<(UUID, String)> { get }
    func start() async
    func stop() async
    func resolveBaseURL(for identifier: UUID) async -> URL?
}

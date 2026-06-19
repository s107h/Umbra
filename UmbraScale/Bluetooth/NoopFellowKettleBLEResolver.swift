import Foundation

final class NoopFellowKettleBLEResolver: FellowKettleBLEResolving, @unchecked Sendable {
    nonisolated let sightings = AsyncStream<(UUID, String)> { _ in }

    func start() async {}
    func stop() async {}

    func resolveBaseURL(for identifier: UUID) async -> URL? {
        _ = identifier
        return nil
    }
}

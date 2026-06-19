import Combine
import Foundation

@MainActor
final class FellowKettleDiscoveryManager: ObservableObject {
    @Published private(set) var candidates: [FellowKettleDiscoveryCandidate] = []
    @Published private(set) var discoveryState: FellowKettleDiscoveryState = .idle

    private let mdnsBrowser: FellowKettleMDNSBrowsing
    private let bleResolver: FellowKettleBLEResolving
    private var tasks: [Task<Void, Never>] = []

    init(mdnsBrowser: FellowKettleMDNSBrowsing, bleResolver: FellowKettleBLEResolving) {
        self.mdnsBrowser = mdnsBrowser
        self.bleResolver = bleResolver
    }

    var autoAdoptableCandidate: FellowKettleDiscoveryCandidate? {
        FellowKettleDiscoveryCandidate.autoAdoptableCandidate(from: candidates)
    }

    func start() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        candidates = []
        discoveryState = .discovering([])

        tasks = [
            Task { [mdnsBrowser] in
                await mdnsBrowser.start()
                for await candidate in mdnsBrowser.updates {
                    if Task.isCancelled { break }
                    self.handleDiscoveredCandidate(candidate)
                }
            },
            Task { [bleResolver] in
                await bleResolver.start()
                for await (identifier, name) in bleResolver.sightings {
                    if Task.isCancelled { break }
                    await self.handleBLESighting(identifier: identifier, name: name)
                }
            }
        ]
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()

        Task {
            await mdnsBrowser.stop()
            await bleResolver.stop()
        }

        discoveryState = .idle
    }

    private func handleDiscoveredCandidate(_ candidate: FellowKettleDiscoveryCandidate) {
        upsert(candidate)
    }

    private func handleBLESighting(identifier: UUID, name: String) async {
        upsert(
            FellowKettleDiscoveryCandidate(
                id: identifier.uuidString,
                source: .ble,
                displayName: name,
                resolvedBaseURL: nil,
                bleIdentifier: identifier
            )
        )

        let resolvedBaseURL = await bleResolver.resolveBaseURL(for: identifier)
        guard !Task.isCancelled, let resolvedBaseURL else { return }

        upsert(
            FellowKettleDiscoveryCandidate(
                id: identifier.uuidString,
                source: .bleResolved,
                displayName: name,
                resolvedBaseURL: resolvedBaseURL,
                bleIdentifier: identifier
            )
        )
    }

    private func upsert(_ candidate: FellowKettleDiscoveryCandidate) {
        if let index = candidates.firstIndex(where: { $0.id == candidate.id }) {
            candidates[index] = candidate
        } else {
            candidates.append(candidate)
        }
        discoveryState = FellowKettleDiscoveryState.from(candidates)
    }
}

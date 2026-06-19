import Foundation

final class FellowKettleMDNSBrowser: NSObject, FellowKettleMDNSBrowsing, @unchecked Sendable {
    nonisolated let updates: AsyncStream<FellowKettleDiscoveryCandidate>

    private let knownNameTokens = ["FELLOW", "STAGG", "EKG"]
    private let browser = NetServiceBrowser()
    private var continuation: AsyncStream<FellowKettleDiscoveryCandidate>.Continuation?
    private var servicesByName: [String: NetService] = [:]

    override init() {
        var capturedContinuation: AsyncStream<FellowKettleDiscoveryCandidate>.Continuation?
        self.updates = AsyncStream { continuation in
            capturedContinuation = continuation
        }
        self.continuation = capturedContinuation
        super.init()
        browser.delegate = self
    }

    func start() async {
        browser.searchForServices(ofType: "_http._tcp.", inDomain: "local.")
    }

    func stop() async {
        browser.stop()
        servicesByName.values.forEach { $0.stop() }
        servicesByName.removeAll()
    }

    private func shouldTrack(service: NetService) -> Bool {
        let normalized = service.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        return knownNameTokens.contains { normalized.contains($0) }
    }

    private func resolvedBaseURL(for service: NetService) -> URL? {
        guard let hostName = service.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !hostName.isEmpty
        else {
            return nil
        }
        return URL(string: "http://\(hostName)")
    }
}

extension FellowKettleMDNSBrowser: NetServiceBrowserDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        guard shouldTrack(service: service) else { return }
        servicesByName[service.name] = service
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove service: NetService,
        moreComing: Bool
    ) {
        servicesByName.removeValue(forKey: service.name)
    }
}

extension FellowKettleMDNSBrowser: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        continuation?.yield(
            FellowKettleDiscoveryCandidate(
                id: "mdns:\(sender.name)",
                source: .mdns,
                displayName: sender.name,
                resolvedBaseURL: resolvedBaseURL(for: sender),
                bleIdentifier: nil
            )
        )
    }
}

import Combine
import Foundation
#if canImport(FellowKettleSupport)
import FellowKettleSupport
#endif

@MainActor
final class FellowKettleManager: ObservableObject {
    private actor NetworkOperationGate {
        private var isHeld = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func run<T: Sendable>(_ operation: @MainActor @escaping () async throws -> T) async throws -> T {
            await acquire()

            do {
                let result = try await operation()
                release()
                return result
            } catch {
                release()
                throw error
            }
        }

        private func acquire() async {
            if !isHeld {
                isHeld = true
                return
            }

            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        private func release() {
            if waiters.isEmpty {
                isHeld = false
                return
            }

            let next = waiters.removeFirst()
            next.resume()
        }
    }

    private static let hostDefaultsKey = "fellowKettleHost"
    private static let pollInterval: Duration = .seconds(5)
    enum ManagerError: LocalizedError {
        case noConfiguredHost
        case invalidResponse
        case httpStatus(code: Int, body: String)

        var errorDescription: String? {
            switch self {
            case .noConfiguredHost:
                return "No kettle host configured."
            case .invalidResponse:
                return "Received an invalid response from the kettle."
            case .httpStatus(let code, let body):
                let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedBody.isEmpty {
                    return "Kettle request failed with HTTP \(code)."
                }
                return "Kettle request failed with HTTP \(code): \(trimmedBody)"
            }
        }
    }

    @Published private(set) var state: FellowKettleState
    @Published private(set) var snapshot: FellowKettleSnapshot?
    @Published private(set) var configuredHost: String?
    @Published private(set) var discoveryState: FellowKettleDiscoveryState = .idle
    @Published private(set) var discoveryCandidates: [FellowKettleDiscoveryCandidate] = []
    @Published var host: String
    @Published private(set) var logger = BLELogger()

    private let session: URLSession
    private let defaults: UserDefaults
    private let discoveryManager: FellowKettleDiscoveryManager
    private let networkOperationGate = NetworkOperationGate()
    private var cancellables: Set<AnyCancellable> = []
    private var pollingTask: Task<Void, Never>?

    init(
        session: URLSession = FellowKettleManager.makeDefaultSession(),
        defaults: UserDefaults = .standard,
        discoveryManager: FellowKettleDiscoveryManager
    ) {
        self.session = session
        self.defaults = defaults
        self.discoveryManager = discoveryManager

        let persistedHost = (defaults.string(forKey: Self.hostDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        configuredHost = persistedHost.isEmpty ? nil : persistedHost
        host = persistedHost
        state = persistedHost.isEmpty ? .unconfigured : .configured(host: persistedHost)
        bindDiscoveryManager()

        if !persistedHost.isEmpty {
            logger.log("Loaded Fellow kettle host \(persistedHost)")
            logger.log("Fellow polling is idle until explicit interaction")
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    func saveHost() {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousHost = configuredHost
        host = trimmedHost
        stopPolling()
        discoveryManager.stop()

        if trimmedHost.isEmpty {
            configuredHost = nil
            defaults.removeObject(forKey: Self.hostDefaultsKey)
            snapshot = nil
            state = .unconfigured
            logger.log("Cleared Fellow kettle host")
            beginAutomaticDiscoveryIfNeeded()
        } else {
            if let previousHost, previousHost != trimmedHost {
                snapshot = nil
            }
            configuredHost = trimmedHost
            defaults.set(trimmedHost, forKey: Self.hostDefaultsKey)
            state = .configured(host: trimmedHost)
            logger.log("Saved Fellow kettle host \(trimmedHost)")
        }

        startPolling()
    }

    func startPolling() {
        stopPolling()
        startPollingLoop(immediately: true)
    }

    private func startPollingLoop(immediately: Bool) {
        guard let currentHost = configuredHost, !currentHost.isEmpty else {
            snapshot = nil
            state = .unconfigured
            return
        }

        state = .polling(host: currentHost)
        logger.log("Starting Fellow poll loop for \(currentHost)")

        pollingTask = Task { [weak self] in
            guard let self else { return }

            if immediately {
                await self.refresh()
            }

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.pollInterval)
                } catch {
                    break
                }

                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard let currentHost = configuredHost, !currentHost.isEmpty else {
            snapshot = nil
            state = .unconfigured
            return
        }

        do {
            try await withSerializedNetworkOperation { [self] in
                try self.requireFreshHost(currentHost)
                self.state = .polling(host: currentHost)
                let parsedSnapshot = try await self.refreshSnapshot(for: currentHost)
                try self.requireFreshHost(currentHost)
                self.snapshot = parsedSnapshot
                self.resumePollingAfterExplicitInteraction(for: currentHost)
                self.state = .ready(host: currentHost)
            }
        } catch is CancellationError {
            return
        } catch {
            guard shouldPublishFailure(for: currentHost, error: error) else {
                return
            }
            resumePollingAfterExplicitInteraction(for: currentHost)
            state = .error(host: currentHost, message: error.localizedDescription)
            logger.log("Fellow poll failed for \(currentHost): \(error.localizedDescription)")
        }
    }

    func setHeatEnabled(_ enabled: Bool) async {
        do {
            try await runCommand(enabled ? .heatOn : .heatOff, label: enabled ? "heat on" : "heat off")
        } catch is CancellationError {
            return
        } catch {
            logger.log("Fellow heat toggle failed: \(error.localizedDescription)")
        }
    }

    func setTargetTemperature(_ celsius: Double) async {
        do {
            try await runCommand(.setTargetCelsius(celsius), label: String(format: "set target %.1fC", celsius))
            try await runCommand(.heatOn, label: "heat on")
        } catch is CancellationError {
            return
        } catch {
            logger.log("Fellow target update failed: \(error.localizedDescription)")
        }
    }

    func setUnits(_ units: FellowKettleUnits) async {
        do {
            try await runCommand(.setUnits(units), label: "set units \(units.rawValue)")
        } catch is CancellationError {
            return
        } catch {
            logger.log("Fellow unit update failed: \(error.localizedDescription)")
        }
    }

    func setHoldDuration(_ holdDuration: FellowKettleHoldDuration) async {
        do {
            try await runCommand(.setHoldDuration(holdDuration), label: "set hold \(holdDuration.rawValue)")
        } catch is CancellationError {
            return
        } catch {
            logger.log("Fellow hold update failed: \(error.localizedDescription)")
        }
    }

    func beginAutomaticDiscoveryIfNeeded() {
        guard configuredHost == nil else { return }
        guard pollingTask == nil else { return }
        guard case .idle = discoveryState else { return }
        state = .discovering
        logger.log("Starting Fellow auto-discovery")
        discoveryManager.start()
    }

    @discardableResult
    private func runCommand(_ command: FellowKettleCLIRequest.Command, label: String) async throws -> String {
        let currentHost = try requireConfiguredHost()

        do {
            return try await withSerializedNetworkOperation { [self] in
                try self.requireFreshHost(currentHost)
                self.state = .commandInFlight(host: currentHost, command: label)
                let body = try await self.send(command, host: currentHost)
                try self.requireFreshHost(currentHost)
                self.state = .polling(host: currentHost)
                let parsedSnapshot = try await self.refreshSnapshot(for: currentHost)
                try self.requireFreshHost(currentHost)
                self.snapshot = parsedSnapshot
                self.resumePollingAfterExplicitInteraction(for: currentHost)
                self.state = .ready(host: currentHost)
                return body
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard shouldPublishFailure(for: currentHost, error: error) else {
                throw CancellationError()
            }
            resumePollingAfterExplicitInteraction(for: currentHost)
            state = .error(host: currentHost, message: error.localizedDescription)
            logger.log("Fellow command failed (\(label)) for \(currentHost): \(error.localizedDescription)")
            throw error
        }
    }

    private func send(_ command: FellowKettleCLIRequest.Command, host: String) async throws -> String {
        let request = FellowKettleCLIRequest(baseURLString: normalizedBaseURL(for: host), command: command)
        let url = try request.url()

        logger.log("Fellow request \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse else {
            logger.log("Fellow response was not HTTP")
            throw ManagerError.invalidResponse
        }

        let body = String(decoding: data, as: UTF8.self)
        logger.log("Fellow HTTP \(response.statusCode) from \(url.host(percentEncoded: false) ?? host)")
        logger.log("Fellow response \(body.replacingOccurrences(of: "\n", with: " "))")

        guard (200...299).contains(response.statusCode) else {
            throw ManagerError.httpStatus(code: response.statusCode, body: body)
        }

        return body
    }

    private func requireConfiguredHost() throws -> String {
        guard let currentHost = configuredHost, !currentHost.isEmpty else {
            snapshot = nil
            if case .discovering = state {
                state = .discovering
            } else {
                state = .unconfigured
            }
            logger.log("Skipped Fellow action: no host configured")
            throw ManagerError.noConfiguredHost
        }
        return currentHost
    }

    private func requireFreshHost(_ host: String) throws {
        try Task.checkCancellation()

        guard configuredHost == host else {
            logger.log("Skipping Fellow network operation for superseded host \(host)")
            throw CancellationError()
        }
    }

    nonisolated private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 5
        return URLSession(configuration: configuration)
    }

    private func normalizedBaseURL(for host: String) -> String {
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            return host
        }
        return "http://\(host)"
    }

    private func shouldPublishFailure(for host: String, error: Error) -> Bool {
        if Task.isCancelled || configuredHost != host {
            logger.log("Ignoring Fellow failure for superseded host \(host)")
            return false
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            logger.log("Ignoring cancelled Fellow request for \(host)")
            return false
        }

        return true
    }

    private func resumePollingAfterExplicitInteraction(for host: String) {
        guard pollingTask == nil, configuredHost == host else { return }
        startPollingLoop(immediately: false)
    }

    private func stopPolling() {
        guard pollingTask != nil else { return }
        pollingTask?.cancel()
        pollingTask = nil
        logger.log("Stopped Fellow poll loop")
    }

    private func withSerializedNetworkOperation<T: Sendable>(
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        try await networkOperationGate.run(operation)
    }

    private func bindDiscoveryManager() {
        discoveryManager.$discoveryState
            .sink { [weak self] newState in
                self?.handleDiscoveryStateChange(newState)
            }
            .store(in: &cancellables)

        discoveryManager.$candidates
            .sink { [weak self] candidates in
                self?.handleDiscoveryCandidatesChange(candidates)
            }
            .store(in: &cancellables)
    }

    private func handleDiscoveryStateChange(_ newState: FellowKettleDiscoveryState) {
        discoveryState = newState

        guard configuredHost == nil else { return }

        switch newState {
        case .idle:
            if case .discovering = state {
                state = .unconfigured
            }
        case .discovering:
            state = .discovering
        case .conflict:
            state = .conflict(message: "Multiple kettles found; choose one manually.")
        }
    }

    private func handleDiscoveryCandidatesChange(_ candidates: [FellowKettleDiscoveryCandidate]) {
        discoveryCandidates = candidates

        guard configuredHost == nil else { return }
        guard let candidate = FellowKettleDiscoveryCandidate.autoAdoptableCandidate(from: candidates) else { return }
        adoptDiscoveredCandidate(candidate)
    }

    private func adoptDiscoveredCandidate(_ candidate: FellowKettleDiscoveryCandidate) {
        guard let resolvedBaseURL = candidate.resolvedBaseURL else { return }
        let adoptedHost = resolvedBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !adoptedHost.isEmpty else { return }

        logger.log("Auto-adopted Fellow kettle \(candidate.displayName) at \(adoptedHost)")
        host = adoptedHost
        saveHost()
    }

    private func refreshSnapshot(for host: String) async throws -> FellowKettleSnapshot {
        let stateBody = try await send(.state, host: host)
        let parsedState = try FellowKettleParser.parseState(stateBody)

        let parsedSettings: FellowKettleSettingsSnapshot?
        do {
            let settingsBody = try await send(.settings, host: host)
            parsedSettings = try FellowKettleParser.parseSettings(settingsBody)
        } catch {
            logger.log("Fellow settings refresh skipped: \(error.localizedDescription)")
            parsedSettings = nil
        }

        return FellowKettleSnapshot(
            currentTemperatureCelsius: parsedState.currentTemperatureCelsius,
            targetTemperatureCelsius: parsedState.targetTemperatureCelsius,
            mode: parsedState.mode,
            units: parsedSettings?.units ?? parsedState.units,
            holdDuration: parsedSettings?.holdDuration ?? parsedState.holdDuration
        )
    }
}

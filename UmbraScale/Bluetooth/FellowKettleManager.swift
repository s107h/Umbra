import Combine
import Foundation

@MainActor
final class FellowKettleManager: ObservableObject {
    private final class NetworkOperationTicket {
        private var continuation: CheckedContinuation<Void, Never>?
        private var isFinished = false

        lazy var completion: Task<Void, Never> = Task {
            if isFinished {
                return
            }

            await withCheckedContinuation { continuation in
                if self.isFinished {
                    continuation.resume()
                } else {
                    self.continuation = continuation
                }
            }
        }

        func finish() {
            isFinished = true
            continuation?.resume()
            continuation = nil
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
    @Published var host: String
    @Published private(set) var logger = BLELogger()

    private let session: URLSession
    private let defaults: UserDefaults
    private var pollingTask: Task<Void, Never>?
    private var queuedNetworkOperation: NetworkOperationTicket?

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults

        let persistedHost = (defaults.string(forKey: Self.hostDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        configuredHost = persistedHost.isEmpty ? nil : persistedHost
        host = persistedHost
        state = persistedHost.isEmpty ? .unconfigured : .configured(host: persistedHost)

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
        host = trimmedHost
        stopPolling()

        if trimmedHost.isEmpty {
            configuredHost = nil
            defaults.removeObject(forKey: Self.hostDefaultsKey)
            snapshot = nil
            state = .unconfigured
            logger.log("Cleared Fellow kettle host")
        } else {
            configuredHost = trimmedHost
            defaults.set(trimmedHost, forKey: Self.hostDefaultsKey)
            state = .configured(host: trimmedHost)
            logger.log("Saved Fellow kettle host \(trimmedHost)")
        }

        startPolling()
    }

    func startPolling() {
        stopPolling()

        guard let currentHost = configuredHost, !currentHost.isEmpty else {
            snapshot = nil
            state = .unconfigured
            return
        }

        state = .polling(host: currentHost)
        logger.log("Starting Fellow poll loop for \(currentHost)")

        pollingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.refresh()

                do {
                    try await Task.sleep(for: Self.pollInterval)
                } catch {
                    break
                }
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
                self.state = .polling(host: currentHost)
                let body = try await self.send(.state, host: currentHost)
                let parsedSnapshot = try FellowKettleParser.parseState(body)
                try Task.checkCancellation()

                guard self.configuredHost == currentHost else {
                    throw CancellationError()
                }

                self.snapshot = parsedSnapshot
                self.state = .ready(host: currentHost)
            }
        } catch is CancellationError {
            return
        } catch {
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

    @discardableResult
    private func runCommand(_ command: FellowKettleCLIRequest.Command, label: String) async throws -> String {
        let currentHost = try requireConfiguredHost()

        do {
            return try await withSerializedNetworkOperation { [self] in
                self.state = .commandInFlight(host: currentHost, command: label)
                let body = try await self.send(command, host: currentHost)
                try Task.checkCancellation()

                guard self.configuredHost == currentHost else {
                    throw CancellationError()
                }

                self.state = .polling(host: currentHost)
                let refreshBody = try await self.send(.state, host: currentHost)
                let parsedSnapshot = try FellowKettleParser.parseState(refreshBody)
                try Task.checkCancellation()

                guard self.configuredHost == currentHost else {
                    throw CancellationError()
                }

                self.snapshot = parsedSnapshot
                self.state = .ready(host: currentHost)
                return body
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
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
            state = .unconfigured
            logger.log("Skipped Fellow action: no host configured")
            throw ManagerError.noConfiguredHost
        }
        return currentHost
    }

    private func normalizedBaseURL(for host: String) -> String {
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            return host
        }
        return "http://\(host)"
    }

    private func stopPolling() {
        guard pollingTask != nil else { return }
        pollingTask?.cancel()
        pollingTask = nil
        logger.log("Stopped Fellow poll loop")
    }

    private func withSerializedNetworkOperation<T>(
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let previous = queuedNetworkOperation
        let ticket = NetworkOperationTicket()
        queuedNetworkOperation = ticket

        if let previous {
            await previous.completion.value
        }

        defer {
            ticket.finish()
            if queuedNetworkOperation === ticket {
                queuedNetworkOperation = nil
            }
        }

        try Task.checkCancellation()
        return try await operation()
    }
}

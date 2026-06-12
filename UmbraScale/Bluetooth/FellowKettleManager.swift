import Combine
import Foundation

@MainActor
final class FellowKettleManager: ObservableObject {
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
    @Published var host: String
    @Published private(set) var logger = BLELogger()

    private let session: URLSession
    private let defaults: UserDefaults
    private var pollingTask: Task<Void, Never>?

    init(session: URLSession = .shared, defaults: UserDefaults = .standard) {
        self.session = session
        self.defaults = defaults

        let persistedHost = (defaults.string(forKey: Self.hostDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

        if trimmedHost.isEmpty {
            defaults.removeObject(forKey: Self.hostDefaultsKey)
            snapshot = nil
            state = .unconfigured
            logger.log("Cleared Fellow kettle host")
        } else {
            defaults.set(trimmedHost, forKey: Self.hostDefaultsKey)
            state = .configured(host: trimmedHost)
            logger.log("Saved Fellow kettle host \(trimmedHost)")
        }

        startPolling()
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = nil

        let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentHost.isEmpty else {
            snapshot = nil
            state = .unconfigured
            return
        }

        host = currentHost
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
        let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentHost.isEmpty else {
            snapshot = nil
            state = .unconfigured
            return
        }

        do {
            state = .polling(host: currentHost)
            let body = try await send(.state, host: currentHost)
            snapshot = try FellowKettleParser.parseState(body)
            state = .ready(host: currentHost)
        } catch {
            state = .error(host: currentHost, message: error.localizedDescription)
            logger.log("Fellow poll failed for \(currentHost): \(error.localizedDescription)")
        }
    }

    func setHeatEnabled(_ enabled: Bool) async {
        do {
            try await runCommand(enabled ? .heatOn : .heatOff, label: enabled ? "heat on" : "heat off")
        } catch {
            logger.log("Fellow heat toggle failed: \(error.localizedDescription)")
        }
    }

    func setTargetTemperature(_ celsius: Double) async {
        do {
            try await runCommand(.setTargetCelsius(celsius), label: String(format: "set target %.1fC", celsius))
            try await runCommand(.heatOn, label: "heat on")
        } catch {
            logger.log("Fellow target update failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    private func runCommand(_ command: FellowKettleCLIRequest.Command, label: String) async throws -> String {
        let currentHost = try requireConfiguredHost()

        do {
            state = .commandInFlight(host: currentHost, command: label)
            let body = try await send(command, host: currentHost)
            await refresh()
            return body
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
        let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentHost.isEmpty else {
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
}

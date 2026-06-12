import Combine
import Foundation
#if canImport(FellowKettleSupport)
import FellowKettleSupport
#endif

@MainActor
final class FellowKettleManager: ObservableObject {
    private static let hostDefaultsKey = "fellowKettleHost"
    private static let pollInterval: Duration = .seconds(5)

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
        state = persistedHost.isEmpty ? .unconfigured : .polling(host: persistedHost)

        if !persistedHost.isEmpty {
            logger.log("Loaded Fellow kettle host \(persistedHost)")
            startPolling()
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
        await runCommand(enabled ? .heatOn : .heatOff, label: enabled ? "heat on" : "heat off")
    }

    func setTargetTemperature(_ celsius: Double) async {
        await runCommand(.setTargetCelsius(celsius), label: String(format: "set target %.1fC", celsius))
        await runCommand(.heatOn, label: "heat on")
    }

    private func runCommand(_ command: FellowKettleCLIRequest.Command, label: String) async {
        let currentHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentHost.isEmpty else {
            snapshot = nil
            state = .unconfigured
            logger.log("Skipped Fellow command \(label): no host configured")
            return
        }

        do {
            state = .commandInFlight(host: currentHost, command: label)
            _ = try await send(command, host: currentHost)
            await refresh()
        } catch {
            state = .error(host: currentHost, message: error.localizedDescription)
            logger.log("Fellow command failed (\(label)) for \(currentHost): \(error.localizedDescription)")
        }
    }

    private func send(_ command: FellowKettleCLIRequest.Command, host: String) async throws -> String {
        let request = FellowKettleCLIRequest(baseURLString: normalizedBaseURL(for: host), command: command)
        let url = try request.url()

        logger.log("Fellow request \(url.absoluteString)")

        let (data, response) = try await session.data(from: url)
        if let response = response as? HTTPURLResponse {
            logger.log("Fellow HTTP \(response.statusCode) from \(url.host(percentEncoded: false) ?? host)")
        }

        let body = String(decoding: data, as: UTF8.self)
        logger.log("Fellow response \(body.replacingOccurrences(of: "\n", with: " "))")
        return body
    }

    private func normalizedBaseURL(for host: String) -> String {
        if host.hasPrefix("http://") || host.hasPrefix("https://") {
            return host
        }
        return "http://\(host)"
    }
}

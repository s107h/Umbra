import Foundation
import Testing
@testable import FellowKettleManagerSupport

@MainActor
@Suite(.serialized)
struct FellowKettleManagerTests {
    @Test func saveHostClearsSnapshotWhenSwitchingToDifferentNonEmptyHost() async throws {
        let defaults = try TestDefaults.make()
        let transport = TestURLProtocol.Transport()
        let oldHostBody = """
        tempr=50.0 C
        temprT=95.0 C
        mode=S_Heat
        """

        await transport.setHandler(for: "old.local") { _ in
            TestURLProtocol.httpResponse(body: oldHostBody)
        }
        let newHostResponseGate = AsyncGate()
        await transport.setHandler(for: "new.local") { _ in
            await newHostResponseGate.wait()
            return TestURLProtocol.httpResponse(body: oldHostBody)
        }

        let manager = FellowKettleManager(
            session: TestURLProtocol.makeSession(transport: transport),
            defaults: defaults.defaults
        )

        manager.host = "old.local"
        manager.saveHost()

        try await waitUntil { manager.snapshot != nil }

        #expect(manager.snapshot?.currentTemperatureCelsius == 50.0)
        #expect(manager.state == .ready(host: "old.local"))

        manager.host = "new.local"
        manager.saveHost()

        #expect(manager.configuredHost == "new.local")
        #expect(manager.state == .polling(host: "new.local"))
        #expect(manager.snapshot == nil)

        await newHostResponseGate.open()
    }

    @Test func saveHostPreservesSnapshotWhenSavingSameConfiguredHost() async throws {
        let defaults = try TestDefaults.make()
        let transport = TestURLProtocol.Transport()
        let body = """
        tempr=60.0 C
        temprT=92.0 C
        mode=S_Hold
        """

        await transport.setHandler(for: "same.local") { _ in
            return TestURLProtocol.httpResponse(body: body)
        }

        let manager = FellowKettleManager(
            session: TestURLProtocol.makeSession(transport: transport),
            defaults: defaults.defaults
        )

        manager.host = "same.local"
        manager.saveHost()

        try await waitUntil { manager.snapshot != nil }
        let snapshot = try #require(manager.snapshot)

        let refreshGate = AsyncGate()
        await transport.setHandler(for: "same.local") { _ in
            await refreshGate.wait()
            return TestURLProtocol.httpResponse(body: body)
        }

        manager.host = "same.local"
        manager.saveHost()

        #expect(manager.configuredHost == "same.local")
        #expect(manager.state == .polling(host: "same.local"))
        #expect(manager.snapshot == snapshot)

        await refreshGate.open()
    }

    @Test func refreshRestartsPollingAfterRestoredIdleHost() async throws {
        let defaults = try TestDefaults.make()
        defaults.defaults.set("restored.local", forKey: "fellowKettleHost")

        let transport = TestURLProtocol.Transport()
        let requests = RequestLog()
        let body = """
        tempr=61.0 C
        temprT=95.0 C
        mode=S_Heat
        """

        await transport.setHandler(for: "restored.local") { request in
            await requests.record(request)
            return TestURLProtocol.httpResponse(body: body)
        }

        let manager = FellowKettleManager(
            session: TestURLProtocol.makeSession(transport: transport),
            defaults: defaults.defaults
        )

        #expect(manager.configuredHost == "restored.local")
        #expect(manager.state == .configured(host: "restored.local"))
        #expect(await requests.count(for: "state") == 0)

        await manager.refresh()

        try await waitUntil { manager.state == .ready(host: "restored.local") }
        #expect(await requests.count(for: "state") == 1)

        try await waitForRequestCount(requests, command: "state", atLeast: 2, timeoutNanoseconds: 7_000_000_000)
    }

    @Test func refreshFailureStillRearmsPollingAfterRestoredIdleHost() async throws {
        let defaults = try TestDefaults.make()
        defaults.defaults.set("restored.local", forKey: "fellowKettleHost")

        let transport = TestURLProtocol.Transport()
        let requests = RequestLog()
        let responsePlan = ResponsePlan(steps: [
            .httpError(statusCode: 504, body: "gateway timeout"),
            .success(
                """
                tempr=61.0 C
                temprT=95.0 C
                mode=S_Heat
                """
            ),
        ])

        await transport.setHandler(for: "restored.local") { request in
            await requests.record(request)
            return try await responsePlan.next()
        }

        let manager = FellowKettleManager(
            session: TestURLProtocol.makeSession(transport: transport),
            defaults: defaults.defaults
        )

        #expect(manager.configuredHost == "restored.local")
        #expect(manager.state == .configured(host: "restored.local"))
        #expect(await requests.count(for: "state") == 0)

        await manager.refresh()

        #expect(manager.state == .error(host: "restored.local", message: "Kettle request failed with HTTP 504: gateway timeout"))
        #expect(await requests.count(for: "state") == 1)

        try await waitForRequestCount(requests, command: "state", atLeast: 2, timeoutNanoseconds: 7_000_000_000)
        try await waitUntil { manager.state == .ready(host: "restored.local") }
        #expect(manager.snapshot?.currentTemperatureCelsius == 61.0)
    }

    @Test func heatCommandRestartsPollingAfterRestoredIdleHost() async throws {
        let defaults = try TestDefaults.make()
        defaults.defaults.set("restored.local", forKey: "fellowKettleHost")

        let transport = TestURLProtocol.Transport()
        let requests = RequestLog()
        let body = """
        tempr=62.0 C
        temprT=96.0 C
        mode=S_Hold
        """

        await transport.setHandler(for: "restored.local") { request in
            await requests.record(request)
            return TestURLProtocol.httpResponse(body: body)
        }

        let manager = FellowKettleManager(
            session: TestURLProtocol.makeSession(transport: transport),
            defaults: defaults.defaults
        )

        #expect(manager.configuredHost == "restored.local")
        #expect(manager.state == .configured(host: "restored.local"))
        #expect(await requests.count(for: "state") == 0)

        await manager.setHeatEnabled(true)

        try await waitUntil { manager.state == .ready(host: "restored.local") }
        #expect(await requests.count(for: "setstate S_Heat") == 1)
        #expect(await requests.count(for: "state") == 1)

        try await waitForRequestCount(requests, command: "state", atLeast: 2, timeoutNanoseconds: 7_000_000_000)
    }
}

private final class TestDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init(suiteName: String, defaults: UserDefaults) {
        self.suiteName = suiteName
        self.defaults = defaults
    }

    static func make() throws -> TestDefaults {
        let suiteName = "FellowKettleManagerTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestError.failedToCreateDefaults
        }
        defaults.removePersistentDomain(forName: suiteName)
        return TestDefaults(suiteName: suiteName, defaults: defaults)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private enum TestError: Error {
    case failedToCreateDefaults
    case timedOut
}

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let continuations = waiters
        waiters.removeAll()
        for continuation in continuations {
            continuation.resume()
        }
    }
}

private actor RequestLog {
    private var counts: [String: Int] = [:]

    func record(_ request: URLRequest) {
        guard
            let url = request.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let command = components.queryItems?.first(where: { $0.name == "cmd" })?.value
        else {
            return
        }

        counts[command, default: 0] += 1
    }

    func count(for command: String) -> Int {
        counts[command, default: 0]
    }
}

private actor ResponsePlan {
    enum Step {
        case success(String)
        case httpError(statusCode: Int, body: String)
    }

    private var steps: [Step]
    private var fallbackStep: Step

    init(steps: [Step]) {
        precondition(!steps.isEmpty)
        self.steps = steps
        fallbackStep = steps[steps.count - 1]
    }

    func next() throws -> (HTTPURLResponse, Data) {
        let step = if steps.isEmpty {
            fallbackStep
        } else {
            steps.removeFirst()
        }

        switch step {
        case .success(let body):
            return TestURLProtocol.httpResponse(body: body)
        case .httpError(let statusCode, let body):
            return TestURLProtocol.httpResponse(statusCode: statusCode, body: body)
        }
    }
}

private func waitForRequestCount(
    _ requests: RequestLog,
    command: String,
    atLeast expectedCount: Int,
    timeoutNanoseconds: UInt64 = 2_000_000_000
) async throws {
    let deadline = Date().addingTimeInterval(TimeInterval(timeoutNanoseconds) / 1_000_000_000)

    while Date() < deadline {
        if await requests.count(for: command) >= expectedCount {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    throw TestError.timedOut
}

private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    condition: @escaping @MainActor () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(TimeInterval(timeoutNanoseconds) / 1_000_000_000)

    while Date() < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    throw TestError.timedOut
}

private final class TestURLProtocol: URLProtocol, @unchecked Sendable {
    actor Transport {
        typealias Handler = @Sendable (URLRequest) async throws -> (HTTPURLResponse, Data)

        private var handlers: [String: Handler] = [:]

        func setHandler(for host: String, handler: @escaping Handler) {
            handlers[host] = handler
        }

        func handler(for host: String) -> Handler? {
            handlers[host]
        }
    }

    private static let transportLock = NSLock()
    nonisolated(unsafe) private static var transport: Transport?

    static func makeSession(transport: Transport) -> URLSession {
        transportLock.lock()
        self.transport = transport
        transportLock.unlock()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 5
        return URLSession(configuration: configuration)
    }

    static func httpResponse(statusCode: Int = 200, body: String) -> (HTTPURLResponse, Data) {
        let url = URL(string: "http://localhost")!
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.transportLock.lock()
        let transport = Self.transport
        Self.transportLock.unlock()

        guard let transport else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }

        Task {
            do {
                guard let handler = await transport.handler(for: host) else {
                    throw URLError(.unsupportedURL)
                }

                let (response, data) = try await handler(request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

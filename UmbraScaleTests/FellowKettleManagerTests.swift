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

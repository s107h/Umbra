import Combine
import Foundation

@MainActor
final class BLELogger: ObservableObject {
    @Published private(set) var lines: [String] = []

    var exportText: String {
        lines.joined(separator: "\n")
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    func log(_ message: String) {
        let timestamp = Self.formatter.string(from: Date())
        lines.append("[\(timestamp)] \(message)")

        if lines.count > 500 {
            lines.removeFirst(lines.count - 500)
        }
    }

    func clear() {
        lines.removeAll()
    }
}

extension Data {
    nonisolated var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

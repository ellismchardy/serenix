import Foundation

/// The cleaned History Sync capture in `Fixtures/`, read as messages in the order they were
/// exchanged with the Strap, grouped by connection.
struct SyncCapture {
    enum Direction: Equatable {
        /// Phone to Strap.
        case out
        /// Strap to phone.
        case `in`
    }

    struct Message: Equatable {
        let time: String
        let direction: Direction
        let characteristic: String
        let bytes: [UInt8]
    }

    struct Connection {
        /// The date and time from the fixture's `# connection` line.
        let start: String
        var messages: [Message]
    }

    let connections: [Connection]

    /// Every message in the capture, in order, across all connections.
    var messages: [Message] { connections.flatMap(\.messages) }

    /// The 27 Oct 2026 capture: five connections of History Sync with a real Strap.
    static let historySync20261027 = SyncCapture(fixture: "HistorySync-2026-10-27")

    init(fixture name: String) {
        guard
            let url = Bundle.module.url(
                forResource: name,
                withExtension: "txt",
                subdirectory: "Fixtures"
            ),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalError("missing test fixture Fixtures/\(name).txt")
        }
        self.init(text: text)
    }

    init(text: String) {
        var connections: [Connection] = []
        let lines = text.split(whereSeparator: \.isNewline)
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                let words = line.dropFirst().split(separator: " ")
                if words.first == "connection" {
                    let start = words.dropFirst().joined(separator: " ")
                    connections.append(Connection(start: start, messages: []))
                }
                continue
            }
            let fields = line.split(separator: " ")
            guard fields.count == 4, !connections.isEmpty else {
                fatalError("malformed fixture line: \(line)")
            }
            let direction: Direction
            switch fields[1] {
            case "out": direction = .out
            case "in": direction = .in
            default: fatalError("unknown direction in fixture line: \(line)")
            }
            let message = Message(
                time: String(fields[0]),
                direction: direction,
                characteristic: String(fields[2]),
                bytes: Self.bytes(fromHex: fields[3])
            )
            connections[connections.count - 1].messages.append(message)
        }
        self.connections = connections
    }

    private static func bytes(fromHex hex: Substring) -> [UInt8] {
        let digits = Array(hex.utf8)
        guard digits.count.isMultiple(of: 2) else { fatalError("odd-length hex: \(hex)") }
        return stride(from: 0, to: digits.count, by: 2).map { index in
            guard
                let byte = UInt8(
                    String(decoding: digits[index...index + 1], as: UTF8.self),
                    radix: 16
                )
            else { fatalError("bad hex: \(hex)") }
            return byte
        }
    }
}

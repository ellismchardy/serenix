/// Why bytes from or for the Strap aren't a valid Frame.
public enum FrameError: Error, Equatable, Sendable {
    /// Doesn't start with `aa 01`, or is too short to hold a header and a CRC.
    case notAFrame
    /// The length field disagrees with the number of bytes.
    case lengthMismatch
    /// The CRC32 of the body doesn't match the one the Frame carries.
    case badCRC
    /// A command of this length field has no known header check, so it can't be built.
    case unknownLength(Int)
}

/// A Frame received from the Strap, checked by CRC.
///
/// Layout (hr-tracker `docs/protocol.md`): `aa 01`, u16 LE length (body count + 4), two bytes,
/// a two-byte header check, the body, then CRC32 of the body, LE. Frames from the Strap carry
/// header-check values we don't know, so only the length and CRC are checked.
public struct Frame: Equatable, Sendable {
    /// The type byte through the last byte before the CRC.
    public let body: [UInt8]

    /// The Frame type, e.g. `0x24` command response or `0x2f` historical data.
    public var type: UInt8 { body[0] }

    public init(bytes: [UInt8]) throws(FrameError) {
        guard bytes.count >= frameHeaderCount + typeByteCount + crcCount,
            bytes[0] == frameStart[0], bytes[1] == frameStart[1]
        else { throw .notAFrame }
        let body = Array(bytes[frameHeaderCount..<(bytes.count - crcCount)])
        let length = Int(uint16(bytes, at: lengthOffset))
        guard length == body.count + lengthFieldExtra else { throw .lengthMismatch }
        guard Array(bytes[(bytes.count - crcCount)...]) == littleEndianBytes(crc32(body)) else {
            throw .badCRC
        }
        self.body = body
    }
}

/// A command for the Strap, before it's given a sequence number.
public struct Command: Equatable, Sendable {
    public let op: UInt8
    public let arguments: [UInt8]

    public init(op: UInt8, arguments: [UInt8]) {
        self.op = op
        self.arguments = arguments
    }

    /// The Frame bytes to write, numbered `sequence` (starts at 1 on each connection).
    public func frame(sequence: UInt8) throws(FrameError) -> [UInt8] {
        let body = [FrameType.command, sequence, op] + arguments
        let length = body.count + lengthFieldExtra
        guard let headerCheck = commandHeaderChecks[length] else {
            throw .unknownLength(length)
        }
        return frameStart + [UInt8(length & 0xff), UInt8(length >> 8)] + phoneDirection
            + headerCheck + body + littleEndianBytes(crc32(body))
    }
}

/// Start-of-frame and version bytes.
private let frameStart: [UInt8] = [0xaa, 0x01]
/// Bytes 4–5 of every Frame the phone sends (the Strap sends `01 00`).
private let phoneDirection: [UInt8] = [0x00, 0x01]
// Sizes in bytes, from the Frame layout in hr-tracker `docs/protocol.md`.
/// Before the body: start, length, direction, header check.
private let frameHeaderCount = 8
/// The smallest body: just the Frame type.
private let typeByteCount = 1
/// CRC32 after the body.
private let crcCount = 4
/// The length field counts the body plus 4 (hr-tracker `docs/protocol.md`, verified).
private let lengthFieldExtra = 4
/// Where the u16 LE length field sits.
private let lengthOffset = 2

/// Frame types (`body[0]`), from hr-tracker `docs/protocol.md`.
enum FrameType {
    /// A command from the phone.
    static let command: UInt8 = 0x23
    /// The Strap's reply to a command.
    static let reply: UInt8 = 0x24
    /// A Live HR reading, once a second while Live HR is on (spec 006).
    static let realtimeData: UInt8 = 0x28
    /// History Records (and optical bursts) during a History Sync.
    static let historicalData: UInt8 = 0x2f
    /// Batch start, Batch end and sync complete during a History Sync.
    static let metadata: UInt8 = 0x31
}

/// Header check of a command Frame, by length field. The algorithm is unknown; these are the
/// values observed in the 27 Oct 2026 capture, which cover every command a History Sync sends.
private let commandHeaderChecks: [Int: [UInt8]] = [
    0x08: [0xe6, 0x71],
    0x0c: [0xe7, 0x41],
    0x0f: [0xe7, 0x05],
    0x10: [0xe0, 0xd1],
]

/// CRC-32 (IEEE 802.3, as zlib's `crc32`), which the Strap uses over each Frame's body.
private func crc32(_ bytes: [UInt8]) -> UInt32 {
    var crc: UInt32 = 0xffff_ffff
    for byte in bytes {
        crc = crc32Table[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
    }
    return ~crc
}

private let crc32Table: [UInt32] = (0..<256).map { index in
    var value = UInt32(index)
    for _ in 0..<8 {
        // 0xedb88320 is the reflected IEEE polynomial.
        value = value & 1 == 1 ? 0xedb8_8320 ^ (value >> 1) : value >> 1
    }
    return value
}

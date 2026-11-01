import Foundation

/// The Sync Log as plain text, for the user to share (spec 001, debug screen): one line per
/// entry, in order, as `<UTC time to the millisecond> <out|in> <bytes in hex>`. `out` is phone
/// to Strap, as in the capture fixtures.
public func syncLogText(_ entries: [SyncLogEntry]) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    var text = ""
    for entry in entries {
        text += formatter.string(from: entry.time)
        text += entry.direction == .toStrap ? " out " : " in "
        text += entry.hexBytes
        text += "\n"
    }
    return text
}

extension SyncLogEntry {
    /// The bytes as lowercase hex, two digits per byte, as the Sync Log shows and shares them.
    public var hexBytes: String { hex(bytes) }
}

/// A shared log after a day away holds ~100,000 Frames, so this avoids building a string per
/// byte. Lowercase, two digits per byte.
func hex(_ bytes: [UInt8]) -> String {
    var digits: [UInt8] = []
    digits.reserveCapacity(bytes.count * 2)
    for byte in bytes {
        digits.append(hexDigits[Int(byte >> 4)])
        digits.append(hexDigits[Int(byte & 0x0f)])
    }
    return String(decoding: digits, as: UTF8.self)
}

private let hexDigits = Array("0123456789abcdef".utf8)

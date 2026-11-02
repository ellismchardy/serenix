import Foundation

/// One Live HR reading, from a `0x28` Frame the Strap sends each second while Live HR is on
/// (spec 006; hr-tracker `docs/protocol.md`, "Realtime HR packet").
public struct LiveHRReading: Equatable, Sendable {
    /// bpm; 0 for the first few seconds while the Strap acquires, or off the wrist.
    public let heartRate: Int
    /// The Strap's clock.
    public let strapTime: Date

    public init(heartRate: Int, strapTime: Date) {
        self.heartRate = heartRate
        self.strapTime = strapTime
    }
}

/// Why a `0x28` Frame can't be decoded.
public enum LiveHRReadingError: Error, Equatable, Sendable {
    /// Too short to hold a heart rate, e.g. after a firmware update. Carries the body length
    /// received.
    case unexpectedLength(Int)
}

/// The Live HR reading in `frame`, or nil when it isn't a `0x28` Frame. Throws if it is one but
/// can't be decoded, so a change in its layout is reported, not silently dropped. The bytes
/// hr-tracker hasn't identified (`d[9]`, `d[14:16]`) and the RR intervals are not read.
public func liveHRReading(from frame: Frame) throws(LiveHRReadingError) -> LiveHRReading? {
    let body = frame.body
    guard body[0] == FrameType.realtimeData else { return nil }
    // The heart rate is the last byte read, after the Strap's clock.
    guard body.count > liveHRHeartRateOffset else { throw .unexpectedLength(body.count) }
    return LiveHRReading(
        heartRate: Int(body[liveHRHeartRateOffset]),
        strapTime: Date(timeIntervalSince1970: TimeInterval(uint32(body, at: liveHRTimeOffset)))
    )
}

extension Command {
    /// Live HR on (`0x03 01`) or off (`0x03 00`).
    public static func liveHR(on: Bool) -> Command {
        Command(op: liveHROp, arguments: [on ? 0x01 : 0x00])
    }
}

/// Turns the Strap's Live HR stream on or off (hr-tracker `docs/protocol.md`, command `0x03`).
/// Internal: a History Sync tells its replies apart from the sync's own (spec 006).
let liveHROp: UInt8 = 0x03
/// Offsets into a `0x28` Frame's body, which starts at the notification's `d[8]`: the Strap's
/// clock (u32 LE) at `d[10]` and the heart rate (bpm) at `d[16]`.
private let liveHRTimeOffset = 2
private let liveHRHeartRateOffset = 8

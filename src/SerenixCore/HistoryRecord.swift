import Foundation

/// One second of raw readings stored on the Strap.
public struct HistoryRecord: Equatable, Sendable {
    public let recordCounter: UInt32
    /// When the Strap took the readings, from its clock (UTC).
    public let timestamp: Date
    /// Beats per minute. `0` while the Strap isn't worn or is still acquiring.
    public let heartRate: Int
    /// RR intervals in milliseconds, oldest first. Often empty during the day.
    public let rrIntervals: [Int]
    /// Four float32 values, usually near unit norm. What they measure isn't settled.
    public let motion: [Float]
    /// Degrees Celsius.
    public let skinTemperature: Double
    /// The Strap's running step count. Reset to `0` when the Strap reboots.
    public let steps: Int
    /// SpO2 in percent (85–100) during an SpO2 Window; `0` outside one. Other values inside a
    /// window look like status bits.
    public let spo2: Int
    public let isInSpO2Window: Bool
    /// The Frame's body, kept so an improved decoder can re-read it.
    public let rawBytes: [UInt8]

    /// Public, so the store can rebuild a History Record it saved and tests can build one.
    public init(
        recordCounter: UInt32,
        timestamp: Date,
        heartRate: Int,
        rrIntervals: [Int],
        motion: [Float],
        skinTemperature: Double,
        steps: Int,
        spo2: Int,
        isInSpO2Window: Bool,
        rawBytes: [UInt8]
    ) {
        self.recordCounter = recordCounter
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.rrIntervals = rrIntervals
        self.motion = motion
        self.skinTemperature = skinTemperature
        self.steps = steps
        self.spo2 = spo2
        self.isInSpO2Window = isInSpO2Window
        self.rawBytes = rawBytes
    }
}

extension HistoryRecord {
    /// What identifies this History Record: its Record Counter and timestamp together, as
    /// `<Record Counter>@<Unix seconds>`. After a reboot the Strap can reuse a Record Counter for
    /// a new record (spec 001), so the counter alone isn't enough.
    public var identity: String {
        "\(recordCounter)@\(Int64(timestamp.timeIntervalSince1970))"
    }
}

/// Why a Frame that should hold a History Record can't be decoded.
public enum HistoryRecordError: Error, Equatable, Sendable {
    /// A per-second record whose body isn't the length the decoder knows, e.g. after a
    /// firmware update. Carries the body length received.
    case unexpectedLength(Int)
}

/// Turns a Strap model's historical-data Frames into History Records.
public protocol HistoryRecordDecoder: Sendable {
    /// The History Record in `frame`, or nil if it isn't a per-second `0x2f` Frame. Throws if
    /// it is one but can't be decoded, so the record is never silently lost.
    func historyRecord(from frame: Frame) throws(HistoryRecordError) -> HistoryRecord?
}

/// How many places a set of Record Counters skips numbers, for the debug screen's store stats:
/// sorted and without repeats (a Record Counter the Strap reused is not a gap), each jump of
/// more than one counts once.
public func recordCounterGapCount(_ counters: [UInt32]) -> Int {
    let sorted = Set(counters).sorted()
    return zip(sorted, sorted.dropFirst()).filter { $1 - $0 > 1 }.count
}

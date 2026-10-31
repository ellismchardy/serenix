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
}

/// Turns a Strap model's historical-data Frames into History Records.
public protocol HistoryRecordDecoder: Sendable {
    /// The History Record in `frame`, or nil if it isn't a per-second `0x2f` Frame.
    func historyRecord(from frame: Frame) -> HistoryRecord?
}

/// The History Record decoder for the Whoop 5.0.
///
/// Layout from hr-tracker `docs/protocol.md`, "`0x12` records". Offsets there index the whole
/// notification; the body starts at its byte 8, so each offset here is that one minus 8.
public struct Whoop5HistoryRecordDecoder: HistoryRecordDecoder {
    public init() {}

    public func historyRecord(from frame: Frame) -> HistoryRecord? {
        let body = frame.body
        guard body.count == perSecondBodyCount, body[0] == historicalDataType,
            body[1] == perSecondVariant
        else { return nil }
        let rrCount = min(Int(body[rrCountOffset]), maxRRIntervals)
        return HistoryRecord(
            recordCounter: uint32(body, at: recordCounterOffset),
            timestamp: Date(timeIntervalSince1970: TimeInterval(uint32(body, at: timestampOffset))),
            heartRate: Int(body[heartRateOffset]),
            rrIntervals: (0..<rrCount).map { Int(uint16(body, at: rrIntervalsOffset + 2 * $0)) },
            motion: (0..<4).map { Float(bitPattern: uint32(body, at: motionOffset + 4 * $0)) },
            skinTemperature: Double(uint16(body, at: skinTemperatureOffset)) / 100,
            steps: Int(uint16(body, at: stepsOffset)),
            spo2: Int(body[spo2Offset]),
            isInSpO2Window: body[measurementModeOffset] != normalMeasurementMode,
            rawBytes: body
        )
    }
}

/// Frame type of historical data.
private let historicalDataType: UInt8 = 0x2f
/// `body[1]` of a per-second History Record; `0x1a` is the optical-burst variant.
private let perSecondVariant: UInt8 = 0x12
/// Body length of a per-second record: a 124-byte Frame less its 8-byte header and 4-byte CRC.
private let perSecondBodyCount = 112
// Body offsets, from the `0x12` record table in hr-tracker `docs/protocol.md` (d[n] − 8).
private let recordCounterOffset = 3
private let timestampOffset = 7
private let heartRateOffset = 14
private let rrCountOffset = 15
private let rrIntervalsOffset = 16
/// The record has room for 4 RR intervals (`d[24:32]`).
private let maxRRIntervals = 4
private let motionOffset = 33
private let stepsOffset = 49
/// u16 LE, hundredths of a degree Celsius.
private let skinTemperatureOffset = 65
private let measurementModeOffset = 70
/// The measurement mode outside an SpO2 Window (`0x07` or `0x0b` inside one).
private let normalMeasurementMode: UInt8 = 0x0c
private let spo2Offset = 74

private func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
}

private func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
    (0..<4).reduce(0) { $0 | UInt32(bytes[offset + $1]) << (8 * $1) }
}

import Foundation

/// The History Record decoder for the Whoop 5.0.
///
/// Layout from hr-tracker `docs/protocol.md`, "`0x12` records". Offsets there index the whole
/// notification; the body starts at its byte 8, so each offset here is that one minus 8.
public struct Whoop5HistoryRecordDecoder: HistoryRecordDecoder {
    public init() {}

    public func historyRecord(from frame: Frame) throws(HistoryRecordError) -> HistoryRecord? {
        let body = frame.body
        guard body.count > variantOffset, body[0] == FrameType.historicalData,
            body[variantOffset] == perSecondVariant
        else { return nil }
        guard body.count == perSecondBodyCount else {
            throw .unexpectedLength(body.count)
        }
        // The record has room for 4; a larger count is clipped, as hr-tracker does.
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
            // Any mode but the normal one, as hr-tracker decides it: `0x07` and `0x0b` are the
            // only others seen, and an unknown mode is more likely a measurement than not.
            isInSpO2Window: body[measurementModeOffset] != normalMeasurementMode,
            rawBytes: body
        )
    }
}

private let variantOffset = 1
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

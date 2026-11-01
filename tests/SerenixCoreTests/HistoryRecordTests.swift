import Foundation
import SerenixCore
import Testing

private let capture = SyncCapture.historySync20261027

/// Frames the Strap sent. The one message on fd4b0007 is not a Frame.
private let strapFrames: [Frame] = capture.messages
    .filter { $0.direction == .in && $0.characteristic != "fd4b0007" }
    .map { message in
        guard let frame = try? Frame(bytes: message.bytes) else {
            fatalError("fixture message at \(message.time) is not a valid Frame")
        }
        return frame
    }

private let decoder = Whoop5HistoryRecordDecoder()

/// Every History Record decoded from the capture, keyed by Record Counter.
private func recordsByCounter() throws -> [UInt32: HistoryRecord] {
    Dictionary(
        try strapFrames.compactMap { try decoder.historyRecord(from: $0) }
            .map { ($0.recordCounter, $0) },
        uniquingKeysWith: { first, _ in first }
    )
}

/// Skin temperature is hundredths of a degree on the Strap, so allow for Double rounding.
private let skinTemperatureTolerance = 0.001

// Expected values in this file are hr-tracker `tools/history.py` output over the fixture Frames
// (its decoder is `whoop5.py parse_history`), committed as literals, unless a test says otherwise.

@Test func decodingTheCaptureYieldsEveryHistoryRecordOnce() throws {
    let records = try strapFrames.compactMap { try decoder.historyRecord(from: $0) }
    #expect(records.count == 1036)
    #expect(Set(records.map(\.recordCounter)) == Set(UInt32(2_862_853)...UInt32(2_863_888)))
}

@Test func firstHistoryRecordOfTheCaptureDecodesToItsValues() throws {
    let record = try #require(try recordsByCounter()[2_862_853])
    #expect(record.timestamp == Date(timeIntervalSince1970: 1_793_129_989))  // 2026-10-27T19:39:49Z
    #expect(record.heartRate == 69)
    #expect(record.rrIntervals == [])
    let expectedMotion: [Float] = [
        0.10321944952011108, -0.05219482257962227, 0.1343701183795929, 0.984936535358429,
    ]
    #expect(record.motion == expectedMotion)
    #expect(abs(record.skinTemperature - 31.97) < skinTemperatureTolerance)
    #expect(record.isInSpO2Window == false)
    #expect(record.spo2 == 0)
}

@Test func lastHistoryRecordOfTheCaptureDecodesToItsValues() throws {
    let record = try #require(try recordsByCounter()[2_863_888])
    #expect(record.timestamp == Date(timeIntervalSince1970: 1_793_131_024))  // 2026-10-27T19:57:04Z
    #expect(record.heartRate == 66)
    #expect(record.rrIntervals == [])
    #expect(abs(record.skinTemperature - 32.75) < skinTemperatureTolerance)
}

@Test func historyRecordWithRRIntervalsDecodesThemInOrder() throws {
    let record = try #require(try recordsByCounter()[2_863_081])
    #expect(record.timestamp == Date(timeIntervalSince1970: 1_793_130_217))  // 19:43:37Z
    #expect(record.heartRate == 71)
    #expect(record.rrIntervals == [654, 914])
    #expect(abs(record.skinTemperature - 32.73) < skinTemperatureTolerance)

    let later = try #require(try recordsByCounter()[2_863_084])
    #expect(later.timestamp == Date(timeIntervalSince1970: 1_793_130_220))  // 19:43:40Z
    #expect(later.heartRate == 72)
    #expect(later.rrIntervals == [1364, 875])
    #expect(abs(later.skinTemperature - 32.74) < skinTemperatureTolerance)
}

@Test func historyRecordKeepsItsFrameBodyAsRawBytes() throws {
    let historyFrames = strapFrames.filter { $0.type == 0x2f }
    #expect(historyFrames.count == 1036)
    for frame in historyFrames {
        #expect(try decoder.historyRecord(from: frame)?.rawBytes == frame.body)
    }
}

@Test func strapFrameThatIsNotHistoricalDataDecodesToNoHistoryRecord() throws {
    // Replies (0x24), realtime HR (0x28), console log and the rest of the capture.
    let otherFrames = strapFrames.filter { $0.type != 0x2f }
    #expect(otherFrames.count == 1477)
    for frame in otherFrames {
        #expect(try decoder.historyRecord(from: frame) == nil)
    }

    // The Strap's reply to 0x61, as captured.
    let reply = try Frame(bytes: [
        0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x27, 0x11,
        0x24, 0x4c, 0x61, 0x01, 0x01, 0x00, 0x00, 0x00,
        0xe2, 0x3e, 0xc1, 0xdd,
    ])
    #expect(try decoder.historyRecord(from: reply) == nil)
}

@Test func opticalBurstFrameDecodesToNoHistoryRecord() throws {
    // An 88-byte 0x2f Frame of the optical-burst variant (body[1] == 0x1a), laid out as in
    // hr-tracker `docs/protocol.md` "0x1a records": header `aa 01 50 00 00 01 35 41`, body
    // `2f 1a 80`, Record Counter 2862900 (one also used by a per-second record), timestamp
    // 1793130036, a made-up DC level, 24 optical samples, float, gain and flags `00 01 00`.
    // The capture has none, so it was built once with Python; the CRC is
    // zlib.crc32(body).to_bytes(4, "little"). It is long enough that a decoder reading the
    // per-second layout without checking the variant would wrongly decode it.
    let burst = try Frame(bytes: [
        0xaa, 0x01, 0x50, 0x00, 0x00, 0x01, 0x35, 0x41,
        0x2f, 0x1a, 0x80, 0x34, 0xaf, 0x2b, 0x00, 0x34,
        0xfe, 0xe0, 0x6a, 0x05, 0x00, 0x07, 0x00, 0xf0,
        0xba, 0x04, 0x00, 0x00, 0x00, 0x78, 0x00, 0xe6,
        0x00, 0x36, 0x01, 0x5e, 0x01, 0x54, 0x01, 0x22,
        0x01, 0xc8, 0x00, 0x5a, 0x00, 0xe2, 0xff, 0x74,
        0xff, 0x1a, 0xff, 0xde, 0xfe, 0xca, 0xfe, 0xde,
        0xfe, 0x1a, 0xff, 0x74, 0xff, 0xe2, 0xff, 0x50,
        0x00, 0xb4, 0x00, 0x04, 0x01, 0x36, 0x01, 0x40,
        0x01, 0x22, 0x01, 0xcd, 0xcc, 0x4c, 0x3d, 0xdc,
        0x05, 0x00, 0x01, 0x00, 0xfd, 0x62, 0xdd, 0x38,
    ])
    #expect(burst.type == 0x2f)
    #expect(try decoder.historyRecord(from: burst) == nil)
}

@Test func stepCountDecodesFromItsRecord() throws {
    // hr-tracker doesn't output steps. These are the u16 LE at d[57:59] of each fixture Frame,
    // the offset hr-tracker `docs/protocol.md` gives for the step count.
    #expect(try #require(try recordsByCounter()[2_863_888]).steps == 91)
    #expect(try #require(try recordsByCounter()[2_863_081]).steps == 6)
}

@Test func historyRecordInsideAnSpO2WindowCarriesItsReading() throws {
    // The capture has no SpO2 Window, so this is the fixture's record 2862853 with only the
    // measurement mode (d[78]) set to 0x07 and SpO2 (d[82]) to 97, its CRC recomputed with
    // zlib.crc32. hr-tracker's parse_history decodes it as in a window, SpO2 97.
    let frame = try Frame(bytes: [
        0xaa, 0x01, 0x74, 0x00, 0x01, 0x00, 0x3f, 0xb1,
        0x2f, 0x12, 0x80, 0x05, 0xaf, 0x2b, 0x00, 0x05,
        0xfe, 0xe0, 0x6a, 0x3d, 0x4a, 0x00, 0x45, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x60, 0x65, 0x01, 0x06, 0x43, 0x6d, 0x00,
        0xe4, 0xb8, 0x64, 0xd3, 0x3d, 0x3d, 0xca, 0x55,
        0xbd, 0x52, 0x98, 0x09, 0x3e, 0xcd, 0x24, 0x7c,
        0x3f, 0x00, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x01, 0x26,
        0x01, 0x7d, 0x0c, 0x00, 0x07, 0x01, 0x07, 0x02,
        0x0c, 0x00, 0x61, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x58, 0x53, 0x80, 0x80, 0x00, 0x00,
        0x00, 0xc9, 0xd1, 0x72, 0xc0, 0x00, 0x00, 0x00,
        0xa6, 0x0c, 0xc9, 0xe5,
    ])
    let record = try #require(try decoder.historyRecord(from: frame))
    #expect(record.recordCounter == 2_862_853)
    #expect(record.isInSpO2Window == true)
    #expect(record.spo2 == 97)
    #expect(record.heartRate == 69)
}

@Test func perSecondFrameOfAnUnexpectedLengthIsRejected() throws {
    // The first 20 body bytes of the fixture's record 2862853, re-framed with a fresh length
    // and CRC (zlib.crc32): a per-second 0x2f Frame far shorter than the 112-byte body.
    let frame = try Frame(bytes: [
        0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x3f, 0xb1,
        0x2f, 0x12, 0x80, 0x05, 0xaf, 0x2b, 0x00, 0x05,
        0xfe, 0xe0, 0x6a, 0x3d, 0x4a, 0x00, 0x45, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xfa, 0x3e, 0x49, 0xae,
    ])
    #expect(throws: HistoryRecordError.unexpectedLength(20)) {
        try decoder.historyRecord(from: frame)
    }
}

@Test func historyRecordIsIdentifiedByItsRecordCounterAndTimestamp() throws {
    // The fixture's record 2863315 was taken at 1793130448 (2026-10-27T19:47:28Z).
    let record = try #require(try recordsByCounter()[2_863_315])
    #expect(record.identity == "2863315@1793130448")
}

// MARK: - Record Counter gaps

@Test func recordCountersWithNoJumpHaveNoGaps() {
    #expect(recordCounterGapCount([]) == 0)
    #expect(recordCounterGapCount([5]) == 0)
    #expect(recordCounterGapCount([1, 2, 3]) == 0)
}

@Test func recordCounterGapsDoNotDependOnOrder() {
    #expect(recordCounterGapCount([3, 1, 2]) == 0)
}

@Test func aRecordCounterSeenTwiceIsNotAGap() {
    // As after a Strap reboot reuses a Record Counter.
    #expect(recordCounterGapCount([1, 2, 2, 3]) == 0)
}

@Test func eachJumpInRecordCountersCountsAsOneGap() {
    #expect(recordCounterGapCount([1, 3]) == 1)
    // 2 → 5 skips 3 and 4, one gap; 6 → 9 skips 7 and 8, another.
    #expect(recordCounterGapCount([1, 2, 5, 6, 9]) == 2)
}

@Test func theCapturesHistoryRecordsHaveNoRecordCounterGaps() throws {
    // The capture holds Record Counters 2862853 through 2863888 with none missing.
    let records = try strapFrames.compactMap { try decoder.historyRecord(from: $0) }
    #expect(records.count == 1036)
    #expect(recordCounterGapCount(records.map(\.recordCounter)) == 0)
}

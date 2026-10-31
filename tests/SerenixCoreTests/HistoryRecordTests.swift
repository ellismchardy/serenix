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
private let recordsByCounter: [UInt32: HistoryRecord] = Dictionary(
    strapFrames.compactMap { decoder.historyRecord(from: $0) }.map { ($0.recordCounter, $0) },
    uniquingKeysWith: { first, _ in first }
)

/// Skin temperature is hundredths of a degree on the Strap, so allow for Double rounding.
private let skinTemperatureTolerance = 0.001

// Expected values in this file are hr-tracker `whoop5.py parse_history` output over the fixture
// Frames, committed as literals.

@Test func decodingTheCaptureYieldsEveryHistoryRecordOnce() {
    let records = strapFrames.compactMap { decoder.historyRecord(from: $0) }
    #expect(records.count == 1036)
    #expect(Set(records.map(\.recordCounter)) == Set(UInt32(2_862_853)...UInt32(2_863_888)))
}

@Test func firstHistoryRecordOfTheCaptureDecodesToItsValues() throws {
    let record = try #require(recordsByCounter[2_862_853])
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
    let record = try #require(recordsByCounter[2_863_888])
    #expect(record.timestamp == Date(timeIntervalSince1970: 1_793_131_024))  // 2026-10-27T19:57:04Z
    #expect(record.heartRate == 66)
    #expect(record.rrIntervals == [])
    #expect(abs(record.skinTemperature - 32.75) < skinTemperatureTolerance)
}

@Test func historyRecordWithRRIntervalsDecodesThemInOrder() throws {
    let record = try #require(recordsByCounter[2_863_081])
    #expect(record.timestamp == Date(timeIntervalSince1970: 1_793_130_217))  // 19:43:37Z
    #expect(record.heartRate == 71)
    #expect(record.rrIntervals == [654, 914])
    #expect(abs(record.skinTemperature - 32.73) < skinTemperatureTolerance)

    let later = try #require(recordsByCounter[2_863_084])
    #expect(later.timestamp == Date(timeIntervalSince1970: 1_793_130_220))  // 19:43:40Z
    #expect(later.heartRate == 72)
    #expect(later.rrIntervals == [1364, 875])
    #expect(abs(later.skinTemperature - 32.74) < skinTemperatureTolerance)
}

@Test func historyRecordKeepsItsFrameBodyAsRawBytes() {
    let historyFrames = strapFrames.filter { $0.type == 0x2f }
    #expect(historyFrames.count == 1036)
    for frame in historyFrames {
        #expect(decoder.historyRecord(from: frame)?.rawBytes == frame.body)
    }
}

@Test func strapFrameThatIsNotHistoricalDataDecodesToNoHistoryRecord() throws {
    // Replies (0x24), realtime HR (0x28), console log and the rest of the capture.
    let otherFrames = strapFrames.filter { $0.type != 0x2f }
    #expect(otherFrames.count == 1477)
    for frame in otherFrames {
        #expect(decoder.historyRecord(from: frame) == nil)
    }

    // The Strap's reply to 0x61, as captured.
    let reply = try Frame(bytes: [
        0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x27, 0x11,
        0x24, 0x4c, 0x61, 0x01, 0x01, 0x00, 0x00, 0x00,
        0xe2, 0x3e, 0xc1, 0xdd,
    ])
    #expect(decoder.historyRecord(from: reply) == nil)
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
    #expect(decoder.historyRecord(from: burst) == nil)
}

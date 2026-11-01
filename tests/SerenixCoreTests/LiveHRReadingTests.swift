import Foundation
import SerenixCore
import Testing

private let capture = SyncCapture.historySync20261027

/// Live HR Frames (type `0x28`) the Strap sent on fd4b0005 in the 27 Oct 2026 capture.
private let liveHRFrames = capture.messages.filter {
    $0.direction == .in && $0.characteristic == "fd4b0005" && $0.bytes[8] == 0x28
}

/// The first `0x28` Frame in the capture, as captured: HR 0x4d (77), Strap time
/// 0x6ae0ff05 (2026-10-27 19:44:05 UTC).
private let firstLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x05, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x4d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x32, 0x3c, 0xc8, 0xaa,
]

/// The second `0x28` Frame in the capture, as captured: HR 0x4c (76), one second later.
private let secondLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x06, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x4c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x3f, 0xad, 0xeb, 0xdb,
]

/// `firstLiveHRFrame` with the Strap acquiring: no real capture has HR 0, so byte 16 (HR) is
/// changed from 0x4d to 0x00 and the CRC recomputed (zlib CRC-32 over bytes 8..<28, LE) from
/// `32 3c c8 aa` to `2c 8a 04 04`.
private let acquiringLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x05, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x2c, 0x8a, 0x04, 0x04,
]

/// The Strap's `0x24` reply to `0x61`, as captured.
private let replyFrame: [UInt8] = [
    0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x27, 0x11,
    0x24, 0x4c, 0x61, 0x01, 0x01, 0x00, 0x00, 0x00,
    0xe2, 0x3e, 0xc1, 0xdd,
]

@Test func liveHRFrameDecodesToItsHeartRateAndStrapTime() throws {
    let reading = try liveHRReading(from: Frame(bytes: firstLiveHRFrame))
    #expect(
        reading
            == LiveHRReading(heartRate: 77, strapTime: Date(timeIntervalSince1970: 1_793_130_245))
    )
}

@Test func nextLiveHRFrameDecodesToTheNextSecondsReading() throws {
    let reading = try liveHRReading(from: Frame(bytes: secondLiveHRFrame))
    #expect(
        reading
            == LiveHRReading(heartRate: 76, strapTime: Date(timeIntervalSince1970: 1_793_130_246))
    )
}

@Test func everyCapturedLiveHRFrameDecodesToAPlausibleHeartRate() throws {
    #expect(liveHRFrames.count == 667)
    for message in liveHRFrames {
        let reading = try liveHRReading(from: Frame(bytes: message.bytes))
        let heartRate = try #require(reading, "Frame at \(message.time)").heartRate
        // The capture's 0x28 Frames run from 58 to 97 bpm.
        #expect((58...97).contains(heartRate), "Frame at \(message.time)")
    }
}

@Test func everyCapturedLiveHRFrameHasAStrapTimeOnTheEveningOfTheCapture() throws {
    // The capture was taken on 27 Oct 2026 between 19:43 and 21:00 UTC. The Strap's clock isn't
    // strictly in order: it steps back 2 s at 19:45:13, when the sync sets it to the phone's.
    let evening =
        Date(timeIntervalSince1970: 1_793_130_180)...Date(timeIntervalSince1970: 1_793_134_800)
    for message in liveHRFrames {
        let reading = try #require(try liveHRReading(from: Frame(bytes: message.bytes)))
        #expect(evening.contains(reading.strapTime), "Frame at \(message.time)")
    }
}

/// The first captured `0x28` Frame cut short after `d[15]`, before its heart rate, with the
/// length (0x0c) and the CRC (44 1a 42 76) recomputed for the shorter body.
private let shortLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x05, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x44, 0x1a, 0x42, 0x76,
]

@Test func liveHRFrameTooShortForAHeartRateIsReportedNotDropped() throws {
    let frame = try Frame(bytes: shortLiveHRFrame)
    #expect(throws: LiveHRReadingError.unexpectedLength(8)) { try liveHRReading(from: frame) }
}

@Test func liveHRFrameWhileTheStrapAcquiresDecodesToHeartRateZero() throws {
    let reading = try liveHRReading(from: Frame(bytes: acquiringLiveHRFrame))
    #expect(reading?.heartRate == 0)
}

@Test func liveHRFrameWithAChangedByteAndTheOldCRCIsABadCRC() {
    var bytes = firstLiveHRFrame
    bytes[16] = 0x00  // HR, from 0x4d; the CRC stays 32 3c c8 aa.
    #expect(throws: FrameError.badCRC) {
        try Frame(bytes: bytes)
    }
}

@Test func frameThatIsNotLiveHRHasNoLiveHRReading() throws {
    #expect(try liveHRReading(from: Frame(bytes: replyFrame)) == nil)
}

@Test func historyRecordFramesHaveNoLiveHRReading() throws {
    let historyFrames = capture.messages.filter {
        $0.direction == .in && $0.characteristic != "fd4b0007" && $0.bytes[8] == 0x2f
    }
    #expect(!historyFrames.isEmpty)
    for message in historyFrames {
        #expect(
            try liveHRReading(from: Frame(bytes: message.bytes)) == nil,
            "Frame at \(message.time)"
        )
    }
}

@Test func liveHROnBuildsTheBytesWhoop5Sends() throws {
    // hr-tracker whoop5.py: frame(2, 0x03, 01).
    let expected: [UInt8] = [
        0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
        0x23, 0x02, 0x03, 0x01, 0xf7, 0x68, 0x6d, 0xcc,
    ]
    #expect(try Command.liveHR(on: true).frame(sequence: 2) == expected)
}

@Test func liveHROffBuildsTheBytesWhoop5Sends() throws {
    // hr-tracker whoop5.py: frame(3, 0x03, 00).
    let expected: [UInt8] = [
        0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
        0x23, 0x03, 0x03, 0x00, 0x56, 0x32, 0xa8, 0xba,
    ]
    #expect(try Command.liveHR(on: false).frame(sequence: 3) == expected)
}

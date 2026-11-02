import Foundation
import SerenixCore
import Testing

private let capture = SyncCapture.historySync20261027

/// Live HR Frames (type `0x28`) the Strap sent on fd4b0005 in the 27 Oct 2026 capture.
private let liveHRFrames = capture.messages.filter {
    $0.direction == .in && $0.characteristic == "fd4b0005" && $0.bytes[8] == 0x28
}

private let start = Date(timeIntervalSince1970: 1_793_130_240)

/// Hello (`0x91 01`), sequence 1, as hr-tracker whoop5.py sends it.
private let helloFrame: [UInt8] = [
    0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
    0x23, 0x01, 0x91, 0x01, 0x36, 0x3e, 0x5c, 0x8d,
]

/// Live HR on (`0x03 01`), sequence 2, as hr-tracker whoop5.py sends it.
private let liveHROnFrame: [UInt8] = [
    0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
    0x23, 0x02, 0x03, 0x01, 0xf7, 0x68, 0x6d, 0xcc,
]

/// Live HR off (`0x03 00`), sequence 3, as hr-tracker whoop5.py sends it.
private let liveHROffFrame: [UInt8] = [
    0xaa, 0x01, 0x08, 0x00, 0x00, 0x01, 0xe6, 0x71,
    0x23, 0x03, 0x03, 0x00, 0x56, 0x32, 0xa8, 0xba,
]

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

/// The Strap's `0x24` reply to `0x61`, as captured.
private let replyFrame: [UInt8] = [
    0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x27, 0x11,
    0x24, 0x4c, 0x61, 0x01, 0x01, 0x00, 0x00, 0x00,
    0xe2, 0x3e, 0xc1, 0xdd,
]

/// The first captured `0x28` Frame cut short after `d[15]`, before its heart rate, with the
/// length (0x0c) and the CRC (44 1a 42 76) recomputed for the shorter body.
private let shortLiveHRFrame: [UInt8] = [
    0xaa, 0x01, 0x0c, 0x00, 0x01, 0x00, 0x22, 0xe1,
    0x28, 0x02, 0x05, 0xff, 0xe0, 0x6a, 0x85, 0x4b,
    0x44, 0x1a, 0x42, 0x76,
]

@Test func startingLiveHRSendsHelloThenLiveHROnWithoutWaitingForAReply() {
    var session = LiveHRSession()
    let output = session.start(at: start)
    #expect(output.framesToSend == [helloFrame, liveHROnFrame])
    #expect(output.readings.isEmpty)
    #expect(output.syncLog.map(\.bytes) == [helloFrame, liveHROnFrame])
    #expect(output.syncLog.map(\.direction) == [.toStrap, .toStrap])
    #expect(output.syncLog.map(\.time) == [start, start])
}

@Test func everyCapturedLiveHRFrameYieldsItsReadingInOrderAndIsLogged() {
    var session = LiveHRSession()
    _ = session.start(at: start)
    var readings: [LiveHRReading] = []
    var syncLog: [SyncLogEntry] = []
    var times: [Date] = []
    for (index, message) in liveHRFrames.enumerated() {
        let time = start.addingTimeInterval(Double(index + 1))
        times.append(time)
        let output = session.receive(message.bytes, at: time)
        #expect(output.framesToSend.isEmpty)
        readings += output.readings
        syncLog += output.syncLog
    }
    #expect(readings.count == 667)
    #expect(
        readings.first
            == LiveHRReading(heartRate: 77, strapTime: Date(timeIntervalSince1970: 1_793_130_245))
    )
    #expect(syncLog.map(\.bytes) == liveHRFrames.map(\.bytes))
    #expect(syncLog.allSatisfy { $0.direction == .fromStrap })
    #expect(syncLog.map(\.time) == times)
}

@Test func liveHRFramesYieldReadingsInTheOrderReceived() {
    var session = LiveHRSession()
    _ = session.start(at: start)
    let first = session.receive(firstLiveHRFrame, at: start.addingTimeInterval(1))
    let second = session.receive(secondLiveHRFrame, at: start.addingTimeInterval(2))
    #expect(
        first.readings + second.readings == [
            LiveHRReading(heartRate: 77, strapTime: Date(timeIntervalSince1970: 1_793_130_245)),
            LiveHRReading(heartRate: 76, strapTime: Date(timeIntervalSince1970: 1_793_130_246)),
        ]
    )
}

@Test func replyFrameDuringLiveHRYieldsNoReadingButIsLogged() {
    var session = LiveHRSession()
    _ = session.start(at: start)
    let time = start.addingTimeInterval(0.1)
    let output = session.receive(replyFrame, at: time)
    #expect(output.readings.isEmpty)
    // Not a 0x28 Frame, so not a skipped reading.
    #expect(output.skipped.isEmpty)
    #expect(output.syncLog.map(\.bytes) == [replyFrame])
    #expect(output.syncLog.map(\.direction) == [.fromStrap])
    #expect(output.syncLog.map(\.time) == [time])
}

@Test func messageThatIsNotAFrameYieldsNoReadingButIsLogged() throws {
    // The capture's one message on fd4b0007, which is not a Frame.
    let notAFrame = try #require(capture.messages.first { $0.characteristic == "fd4b0007" }).bytes
    var session = LiveHRSession()
    _ = session.start(at: start)
    let time = start.addingTimeInterval(0.1)
    var syncLog = session.receive(notAFrame, at: time).syncLog
    let garbage = session.receive([0x01, 0x02], at: time.addingTimeInterval(0.1))
    #expect(garbage.readings.isEmpty)
    #expect(garbage.skipped.isEmpty)
    syncLog += garbage.syncLog
    #expect(syncLog.map(\.bytes) == [notAFrame, [0x01, 0x02]])
    #expect(syncLog.map(\.direction) == [.fromStrap, .fromStrap])
    #expect(syncLog.map(\.time) == [time, time.addingTimeInterval(0.1)])
}

@Test func liveHRFrameWithABadCRCIsSkippedAndTheNextFrameStillYieldsItsReading() {
    var bytes = firstLiveHRFrame
    bytes[16] = 0x00  // HR, from 0x4d; the CRC stays 32 3c c8 aa.
    var session = LiveHRSession()
    _ = session.start(at: start)
    let bad = session.receive(bytes, at: start.addingTimeInterval(1))
    #expect(bad.readings.isEmpty)
    #expect(bad.skipped == [.frame(.badCRC)])
    #expect(bad.syncLog.map(\.bytes) == [bytes])
    #expect(bad.syncLog.map(\.direction) == [.fromStrap])
    let next = session.receive(secondLiveHRFrame, at: start.addingTimeInterval(2))
    #expect(
        next.readings == [
            LiveHRReading(heartRate: 76, strapTime: Date(timeIntervalSince1970: 1_793_130_246))
        ]
    )
}

@Test func liveHRFrameTooShortForAHeartRateYieldsNoReadingButIsLogged() {
    var session = LiveHRSession()
    _ = session.start(at: start)
    let output = session.receive(shortLiveHRFrame, at: start.addingTimeInterval(1))
    #expect(output.readings.isEmpty)
    #expect(output.skipped == [.reading(.unexpectedLength(8))])
    #expect(output.syncLog.map(\.bytes) == [shortLiveHRFrame])
    #expect(output.syncLog.map(\.direction) == [.fromStrap])
}

@Test func stoppingLiveHRSendsLiveHROffAndLogsIt() {
    var session = LiveHRSession()
    _ = session.start(at: start)
    _ = session.receive(firstLiveHRFrame, at: start.addingTimeInterval(1))
    let time = start.addingTimeInterval(2)
    let output = session.stop(at: time)
    #expect(output.framesToSend == [liveHROffFrame])
    #expect(output.readings.isEmpty)
    #expect(output.syncLog.map(\.bytes) == [liveHROffFrame])
    #expect(output.syncLog.map(\.direction) == [.toStrap])
    #expect(output.syncLog.map(\.time) == [time])
}

@Test func liveHRFrameAfterStoppingYieldsNoReadingButIsLogged() {
    var session = LiveHRSession()
    _ = session.start(at: start)
    _ = session.stop(at: start.addingTimeInterval(1))
    let time = start.addingTimeInterval(1.1)
    let output = session.receive(secondLiveHRFrame, at: time)
    #expect(output.readings.isEmpty)
    #expect(output.syncLog.map(\.bytes) == [secondLiveHRFrame])
    #expect(output.syncLog.map(\.direction) == [.fromStrap])
    #expect(output.syncLog.map(\.time) == [time])
}

@Test func startingAgainAfterStoppingNumbersFromHelloAgain() {
    // Each start is a new connection, which numbers its commands from 1 (Frame.swift).
    var session = LiveHRSession()
    let first = session.start(at: start)
    _ = session.stop(at: start.addingTimeInterval(10))
    let again = session.start(at: start.addingTimeInterval(20))
    #expect(again.framesToSend == first.framesToSend)
}

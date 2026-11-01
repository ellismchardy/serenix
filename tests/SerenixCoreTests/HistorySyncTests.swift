import Foundation
import SerenixCore
import Testing

/// The second connection of the 27 Oct capture (19:50:15): one whole History Sync, from hello
/// to the Strap's "complete" Frame.
private let connection = SyncCapture.historySync20261027.connections[1]

/// The time the captured app put in its `0x0a` (set clock) commands: 0x6ae10078.
private let capturedPhoneTime = Date(timeIntervalSince1970: 1_793_130_616)  // 2026-10-27T19:50:16Z

/// Frame layout: `aa 01`, 2-byte length, 2 bytes, 2-byte header check, body, 4-byte CRC.
/// A command body is `23 <sequence> <op> <arguments...>`.
private let headerSize = 8
private let crcSize = 4
private let sequenceOffset = headerSize + 1
private let opOffset = headerSize + 2

/// A `0x31` metadata Frame's body[2]: the start or end of a Batch, or the end of the whole sync.
private let batchStartKind: UInt8 = 0x01
private let batchEndKind: UInt8 = 0x02
private let completeKind: UInt8 = 0x03

private func isMetadataFrame(_ bytes: [UInt8], kind: UInt8) -> Bool {
    bytes.count > headerSize + 2 && bytes[0] == 0xaa && bytes[headerSize] == 0x31
        && bytes[headerSize + 2] == kind
}

/// The Sync Cursors of connection 2's five Batch ends, in order, as captured (bytes 21..<29 of
/// each Batch-end Frame, and the arguments after `01` of the captured app's `0x17`s).
private let capturedSyncCursors: [[UInt8]] = [
    [0xc3, 0xc5, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00],
    [0xc6, 0xc5, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00],
    [0xc9, 0xc5, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00],
    [0xcc, 0xc5, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00],
    [0xcd, 0xc5, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00],
]

private func op(of frame: [UInt8]) -> UInt8 { frame[opOffset] }

private func arguments(of frame: [UInt8]) -> [UInt8] {
    Array(frame[(opOffset + 1)..<(frame.count - crcSize)])
}

/// Index in `connection.messages` of the Strap's "complete" Frame.
private let completeIndex: Int = {
    guard
        let index = connection.messages.firstIndex(where: {
            $0.direction == .in && isMetadataFrame($0.bytes, kind: completeKind)
        })
    else { fatalError("fixture connection 2 has no complete Frame") }
    return index
}()

/// What the Strap sent in connection 2, up to and including the complete Frame, in order.
/// Includes the one message on fd4b0007, which is not a Frame.
private let strapMessages = connection.messages[...completeIndex].filter { $0.direction == .in }

/// The commands the captured app sent before the complete Frame, minus live HR on (`0x03`)
/// and `0x3f`, which the spec leaves out.
private let expectedCommands = connection.messages[..<completeIndex].filter {
    $0.direction == .out && op(of: $0.bytes) != 0x03 && op(of: $0.bytes) != 0x3f
}

/// One call into the session and what it returned.
private struct Step {
    /// The bytes fed to `receive`, or nil for `start`.
    let fed: [UInt8]?
    let time: Date
    let output: HistorySyncOutput
    let stateAfter: HistorySyncState
}

/// Starts a fresh session at `startTime`, then feeds it `messages` in order. Each receive call
/// gets its own time, one second apart.
private func replaySession(_ messages: [SyncCapture.Message], startingAt startTime: Date) -> [Step]
{
    var session = HistorySync()
    var steps: [Step] = []
    let started = session.start(at: startTime)
    steps.append(Step(fed: nil, time: startTime, output: started, stateAfter: session.state))
    for (index, message) in messages.enumerated() {
        let time = startTime.addingTimeInterval(Double(index + 1))
        let output = session.receive(message.bytes, at: time)
        steps.append(
            Step(fed: message.bytes, time: time, output: output, stateAfter: session.state)
        )
    }
    return steps
}

/// Replays every Strap message of connection 2 up to and including the complete Frame.
private func replayConnection2(startingAt startTime: Date) -> [Step] {
    replaySession(Array(strapMessages), startingAt: startTime)
}

private let replay = replayConnection2(startingAt: capturedPhoneTime)

private let framesSent: [[UInt8]] = replay.flatMap(\.output.framesToSend)

@Test func replayingOneSyncSendsTheCapturedCommandsExceptLiveHROnAnd3f() {
    #expect(
        expectedCommands.map { op(of: $0.bytes) } == [
            0x91, 0x0a, 0x0a, 0x0b, 0x61, 0x45, 0x1a, 0x22, 0x16, 0x17, 0x17, 0x17, 0x17, 0x17,
        ]
    )
    #expect(framesSent.map(op(of:)) == expectedCommands.map { op(of: $0.bytes) })
    #expect(framesSent.map(arguments(of:)) == expectedCommands.map { arguments(of: $0.bytes) })
}

@Test func clockCommandsCarryTheTimeTheSyncStartedAt() {
    // 1_793_200_000 is 0x6ae20f80, little-endian 80 0f e2 6a.
    let steps = replayConnection2(startingAt: Date(timeIntervalSince1970: 1_793_200_000))
    let clockCommands = steps.flatMap(\.output.framesToSend).filter { op(of: $0) == 0x0a }
    #expect(
        clockCommands.map(arguments(of:)) == [
            [0x80, 0x0f, 0xe2, 0x6a, 0x00, 0x00, 0x00, 0x00],
            [0x80, 0x0f, 0xe2, 0x6a, 0x00, 0x00, 0x00, 0x00, 0x00],
        ]
    )
}

@Test func commandsAreWholeFramesNumberedFromOneAfterHello() throws {
    #expect(
        framesSent.map { $0[sequenceOffset] } == [1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
    )
    for frame in framesSent {
        let command = Command(op: op(of: frame), arguments: arguments(of: frame))
        #expect(try command.frame(sequence: frame[sequenceOffset]) == frame)
    }
}

@Test func eachAcknowledgementEchoesTheSyncCursorOfTheBatchEndBeforeIt() {
    var cursorsAcknowledged: [[UInt8]] = []
    for step in replay {
        let acknowledgements = step.output.framesToSend.filter { op(of: $0) == 0x17 }
        // An acknowledgement goes out in answer to a Batch end, and only then.
        let fedBatchEnd = step.fed.map { isMetadataFrame($0, kind: batchEndKind) } ?? false
        #expect(acknowledgements.count == (fedBatchEnd ? 1 : 0))
        for frame in acknowledgements {
            let arguments = arguments(of: frame)
            #expect(arguments.first == 0x01)
            cursorsAcknowledged.append(Array(arguments.dropFirst()))
        }
    }
    #expect(cursorsAcknowledged == capturedSyncCursors)
}

@Test func syncIsRunningUntilTheStrapSaysItIsComplete() throws {
    let last = try #require(replay.last)
    #expect(last.fed.map { isMetadataFrame($0, kind: completeKind) } == true)
    #expect(last.stateAfter == .completed)
    for step in replay.dropLast() {
        #expect(step.stateAfter == .running)
    }
}

@Test func replayingOneSyncYieldsEachOfItsHistoryRecordsOnce() {
    let records = replay.flatMap(\.output.historyRecords)
    // The fixture's per-second 0x2f Frames in connection 2, up to the complete Frame.
    #expect(records.count == 178)
    #expect(Set(records.map(\.recordCounter)).count == 178)
}

@Test func syncLogHasEveryFrameInAndOutInOrderWithDirectionAndTime() {
    var expectedTimes: [Date] = []
    var expectedDirections: [SyncDirection] = []
    var expectedBytes: [[UInt8]] = []
    for step in replay {
        if let fed = step.fed {
            expectedTimes.append(step.time)
            expectedDirections.append(.fromStrap)
            expectedBytes.append(fed)
        }
        for frame in step.output.framesToSend {
            expectedTimes.append(step.time)
            expectedDirections.append(.toStrap)
            expectedBytes.append(frame)
        }
    }
    let syncLog = replay.flatMap(\.output.syncLog)
    #expect(syncLog.count == strapMessages.count + 14)
    #expect(syncLog.map(\.direction) == expectedDirections)
    #expect(syncLog.map(\.bytes) == expectedBytes)
    #expect(syncLog.map(\.time) == expectedTimes)
}

/// Replays `messages` into a fresh session started at `capturedPhoneTime`, one second apart,
/// and returns every History Record it yielded, in order.
private func historyRecords(replaying messages: [SyncCapture.Message]) -> [HistoryRecord] {
    replaySession(messages, startingAt: capturedPhoneTime).flatMap(\.output.historyRecords)
}

/// A connection's Strap messages cut after every complete Frame: one piece per sync (from the
/// end of the previous sync to its complete Frame), then whatever the Strap sent after the
/// last complete Frame.
private func syncs(in connection: SyncCapture.Connection) -> (
    syncs: [[SyncCapture.Message]], leftover: [SyncCapture.Message]
) {
    var syncs: [[SyncCapture.Message]] = []
    var sync: [SyncCapture.Message] = []
    for message in connection.messages where message.direction == .in {
        sync.append(message)
        if isMetadataFrame(message.bytes, kind: completeKind) {
            syncs.append(sync)
            sync = []
        }
    }
    return (syncs, sync)
}

@Test func replayingTheWholeCaptureYieldsEachHistoryRecordOnce() {
    // A session ends at the Strap's complete Frame, and the capture holds 11 syncs across its
    // 5 connections. So each sync is replayed into a fresh session, as the app would start a
    // new History Sync each time.
    var records: [HistoryRecord] = []
    var syncCount = 0
    for connection in SyncCapture.historySync20261027.connections {
        let (connectionSyncs, leftover) = syncs(in: connection)
        for sync in connectionSyncs {
            records += historyRecords(replaying: sync)
        }
        syncCount += connectionSyncs.count
        // What the Strap sent after a connection's last complete Frame (replies, live HR,
        // logs) holds no History Record.
        #expect(historyRecords(replaying: leftover).isEmpty)
    }
    #expect(syncCount == 11)
    // The fixture's per-second 0x2f Frames across all 5 connections.
    #expect(records.count == 1_036)
    #expect(Set(records.map(\.recordCounter)).count == 1_036)
}

@Test func aBatchTheStrapSendsTwiceYieldsNoDuplicateHistoryRecords() throws {
    // Connection 2's first Batch (19:50:20.752 Batch start to 19:50:21.564 Batch end, 30
    // per-second 0x2f Frames) is fed a second time straight after itself: a re-send within one
    // sync. Everything else is replayed as captured. A re-send after an interrupted sync
    // reaches a new session; the store's unique Record Counter and timestamp key covers that.
    let batchStart = try #require(
        strapMessages.firstIndex { isMetadataFrame($0.bytes, kind: batchStartKind) }
    )
    let batchEnd = try #require(
        strapMessages.firstIndex { isMetadataFrame($0.bytes, kind: batchEndKind) }
    )
    let batch = Array(strapMessages[batchStart...batchEnd])
    let messages =
        Array(strapMessages[...batchEnd]) + batch + Array(strapMessages[(batchEnd + 1)...])
    let records = historyRecords(replaying: messages)
    // Connection 2's sync holds 178 distinct per-second 0x2f Frames; the re-sent 30 add none.
    #expect(records.count == 178)
    #expect(Set(records.map(\.recordCounter)).count == 178)
}

/// The fixture's record 2863315 (`tenthRecordOfFirstBatchIndex`) with only its timestamp changed,
/// as after a Strap reboot reuses a Record Counter: Frame bytes 15..<19 (body bytes 7..<11, u32
/// little-endian) changed from `d0 ff e0 6a` (1793130448, 19:47:28Z) to `e3 ff e0 6a`
/// (1793130467, 19:47:47Z, 19 s later, as with Record Counter 3,155,039 on the first phone
/// sync), and the CRC recomputed with zlib.crc32 over the body (the bytes after the 8-byte
/// header, before the CRC): captured `5b 45 00 0b`, now `3a 66 f1 e2`.
private let rebootedRecord: [UInt8] = [
    0xaa, 0x01, 0x74, 0x00, 0x01, 0x00, 0x3f, 0xb1,
    0x2f, 0x12, 0x80, 0xd3, 0xb0, 0x2b, 0x00, 0xe3,
    0xff, 0xe0, 0x6a, 0x99, 0x19, 0x00, 0x41, 0x02,
    0x81, 0x03, 0xf1, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x01, 0x49, 0x09, 0x8c, 0x42, 0x41, 0x00,
    0xff, 0x60, 0xcf, 0x9e, 0x3d, 0xae, 0x07, 0x54,
    0xbd, 0x00, 0x20, 0x90, 0x3e, 0x00, 0xfc, 0x78,
    0x3f, 0x06, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x2b, 0x01, 0x3e,
    0x01, 0x2b, 0x0d, 0x50, 0x09, 0x01, 0x0c, 0x02,
    0x0c, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x99, 0xae, 0x2f, 0x32, 0x00, 0x00,
    0x00, 0x0d, 0x4d, 0xa1, 0xc0, 0x00, 0x00, 0x00,
    0x3a, 0x66, 0xf1, 0xe2,
]

/// Connection 2's Strap messages with `rebootedRecord` fed `copies` times straight after the
/// original record 2863315, inside the first Batch. Checks the fixture still holds the original.
private func strapMessagesWithRebootedRecord(copies: Int) throws -> [SyncCapture.Message] {
    let original = strapMessages[tenthRecordOfFirstBatchIndex]
    try #require(original.bytes[11..<15] == [0xd3, 0xb0, 0x2b, 0x00])
    try #require(original.bytes[15..<19] == [0xd0, 0xff, 0xe0, 0x6a])
    try #require(original.bytes.suffix(crcSize) == [0x5b, 0x45, 0x00, 0x0b])
    // Apart from the timestamp and the CRC, the edited Frame is the original byte for byte.
    let end = original.bytes.count - crcSize
    try #require(rebootedRecord.count == original.bytes.count)
    try #require(rebootedRecord[..<15] == original.bytes[..<15])
    try #require(rebootedRecord[19..<end] == original.bytes[19..<end])
    let copy = SyncCapture.Message(
        time: original.time,
        direction: original.direction,
        characteristic: original.characteristic,
        bytes: rebootedRecord
    )
    var messages = Array(strapMessages)
    messages.insert(
        contentsOf: Array(repeating: copy, count: copies),
        at: tenthRecordOfFirstBatchIndex + 1
    )
    return messages
}

@Test func aRecordSharingOnlyARecordCounterIsYieldedAsAnotherHistoryRecord() throws {
    let records = historyRecords(replaying: try strapMessagesWithRebootedRecord(copies: 1))
    // Connection 2's 178 distinct per-second 0x2f Frames, plus the rebooted record.
    #expect(records.count == 179)
    let sharingCounter = records.filter { $0.recordCounter == 2_863_315 }
    #expect(
        sharingCounter.map(\.timestamp) == [
            Date(timeIntervalSince1970: 1_793_130_448),  // 2026-10-27T19:47:28Z
            Date(timeIntervalSince1970: 1_793_130_467),  // 2026-10-27T19:47:47Z
        ]
    )
}

@Test func aRecordWithTheSameRecordCounterAndTimestampTwiceIsYieldedOnce() throws {
    let records = historyRecords(replaying: try strapMessagesWithRebootedRecord(copies: 2))
    // The rebooted record's second copy adds nothing.
    #expect(records.count == 179)
    let sharingCounter = records.filter { $0.recordCounter == 2_863_315 }
    #expect(
        sharingCounter.map(\.timestamp) == [
            Date(timeIntervalSince1970: 1_793_130_448),  // 2026-10-27T19:47:28Z
            Date(timeIntervalSince1970: 1_793_130_467),  // 2026-10-27T19:47:47Z
        ]
    )
}

@Test func anEmptyBatchIsAcknowledgedAndTheSyncCompletesWithNoHistoryRecords() throws {
    // Connection 1's second sync: the app's 0x16 at 19:44:11.400, Batch start at 19:44:11.458,
    // Batch end at 19:44:11.460 with Sync Cursor ffffffffffffffff and no per-second 0x2f
    // Frames, the app's 0x17 01ffffffffffffffff at 19:44:11.611, then complete at
    // 19:44:11.640. It is replayed into a fresh session.
    let connection1Syncs = syncs(in: SyncCapture.historySync20261027.connections[0]).syncs
    try #require(connection1Syncs.count == 3)
    let steps = replaySession(connection1Syncs[1], startingAt: capturedPhoneTime)

    let acknowledgements = steps.flatMap(\.output.framesToSend).filter { op(of: $0) == 0x17 }
    #expect(
        acknowledgements.map(arguments(of:)) == [
            [0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
        ]
    )
    #expect(steps.flatMap(\.output.historyRecords).isEmpty)
    let last = try #require(steps.last)
    #expect(last.fed.map { isMetadataFrame($0, kind: completeKind) } == true)
    #expect(last.stateAfter == .completed)
}

// MARK: - Failure rules

/// Index in `strapMessages` of the Strap's reply to the session's `0x0b` get clock
/// (19:50:17.091).
private let getClockReplyIndex = 3

/// Index in `strapMessages` of the captured reply to the captured app's `0x3f`
/// (19:50:18.020).
private let reply3fIndex = 7

/// Index in `strapMessages` of connection 2's first Batch start (19:50:20.752).
private let firstBatchStartIndex = 17

/// Index in `strapMessages` of the 10th per-second 0x2f Frame of connection 2's first Batch
/// (19:50:21.323, Record Counter 2863315: Frame bytes 11..<15 `d3 b0 2b 00`). Nine per-second
/// 0x2f Frames of that Batch come before it.
private let tenthRecordOfFirstBatchIndex = 52

/// `strapMessages` with the message at `index` replaced by `bytes`, same time and channel.
private func strapMessages(replacingAt index: Int, with bytes: [UInt8]) -> [SyncCapture.Message] {
    var messages = Array(strapMessages)
    let original = messages[index]
    messages[index] = SyncCapture.Message(
        time: original.time,
        direction: original.direction,
        characteristic: original.characteristic,
        bytes: bytes
    )
    return messages
}

/// Checks that in every one of `steps`, the session is `.failed(failure)`, sends nothing,
/// yields no History Records, and still logs the message fed as from the Strap.
private func expectFailedThroughout(_ steps: ArraySlice<Step>, with failure: HistorySyncFailure) {
    #expect(steps.allSatisfy { $0.stateAfter == .failed(failure) })
    #expect(steps.flatMap(\.output.framesToSend).isEmpty)
    #expect(steps.flatMap(\.output.historyRecords).isEmpty)
    let syncLog = steps.flatMap(\.output.syncLog)
    #expect(syncLog.map(\.time) == steps.map(\.time))
    #expect(syncLog.allSatisfy { $0.direction == .fromStrap })
    #expect(syncLog.map(\.bytes) == steps.compactMap(\.fed))
}

/// Commands a session sends up to and including `0x16` (send history), before any Batch.
private let handshakeOps: [UInt8] = [0x91, 0x0a, 0x0a, 0x0b, 0x61, 0x45, 0x1a, 0x22, 0x16]

@Test func aBadCRCInsideABatchFailsTheSyncAndTheBatchIsNotAcknowledged() throws {
    // The fixture's record 2863315 with Frame byte 22 (body byte 14) changed from 0x41 to
    // 0x42, and the CRC deliberately left as captured, so the Frame fails its CRC check.
    var corrupted = strapMessages[tenthRecordOfFirstBatchIndex].bytes
    try #require(corrupted[11..<15] == [0xd3, 0xb0, 0x2b, 0x00])
    try #require(corrupted[22] == 0x41)
    corrupted[22] = 0x42
    let steps = replaySession(
        strapMessages(replacingAt: tenthRecordOfFirstBatchIndex, with: corrupted),
        startingAt: capturedPhoneTime
    )
    // steps[0] is start; steps[i + 1] fed strapMessages[i].
    let failedAt = tenthRecordOfFirstBatchIndex + 1

    #expect(steps[failedAt - 1].stateAfter == .running)
    expectFailedThroughout(steps[failedAt...], with: .badCRC)
    // No Batch is acknowledged: nothing goes out after the handshake and 0x16.
    #expect(steps.flatMap(\.output.framesToSend).map(op(of:)) == handshakeOps)
    // The nine per-second 0x2f Frames of the first Batch before the bad one.
    #expect(steps.flatMap(\.output.historyRecords).count == 9)
}

@Test func aFrameCutShortInsideABatchFailsTheSyncAndTheBatchIsNotAcknowledged() throws {
    // The fixture's record 2863315 with its last 10 bytes (the end of the body and the CRC)
    // dropped, so its length field (74 00) no longer matches its size: a Frame cut short.
    let captured = strapMessages[tenthRecordOfFirstBatchIndex].bytes
    try #require(captured[11..<15] == [0xd3, 0xb0, 0x2b, 0x00])
    let cutShort = Array(captured.dropLast(10))
    let steps = replaySession(
        strapMessages(replacingAt: tenthRecordOfFirstBatchIndex, with: cutShort),
        startingAt: capturedPhoneTime
    )
    let failedAt = tenthRecordOfFirstBatchIndex + 1

    #expect(steps[failedAt - 1].stateAfter == .running)
    expectFailedThroughout(steps[failedAt...], with: .lengthMismatch)
    #expect(steps.flatMap(\.output.framesToSend).map(op(of:)) == handshakeOps)
    #expect(steps.flatMap(\.output.historyRecords).count == 9)
}

@Test func anUndecodableHistoryRecordInsideABatchFailsTheSyncAndTheBatchIsNotAcknowledged() {
    // The first 20 body bytes of the fixture's record 2862853, re-framed with a fresh length
    // and CRC (zlib.crc32): length field 18 00, CRC fa 3e 49 ae. A per-second 0x2f Frame far
    // shorter than the 112-byte body. The
    // same Frame as HistoryRecordTests' perSecondFrameOfAnUnexpectedLengthIsRejected. It
    // replaces the 10th per-second 0x2f Frame of connection 2's first Batch.
    let shortRecord: [UInt8] = [
        0xaa, 0x01, 0x18, 0x00, 0x01, 0x00, 0x3f, 0xb1,
        0x2f, 0x12, 0x80, 0x05, 0xaf, 0x2b, 0x00, 0x05,
        0xfe, 0xe0, 0x6a, 0x3d, 0x4a, 0x00, 0x45, 0x00,
        0x00, 0x00, 0x00, 0x00, 0xfa, 0x3e, 0x49, 0xae,
    ]
    let steps = replaySession(
        strapMessages(replacingAt: tenthRecordOfFirstBatchIndex, with: shortRecord),
        startingAt: capturedPhoneTime
    )
    let failedAt = tenthRecordOfFirstBatchIndex + 1

    #expect(steps[failedAt - 1].stateAfter == .running)
    expectFailedThroughout(
        steps[failedAt...],
        with: .undecodableHistoryRecord(.unexpectedLength(20))
    )
    #expect(steps.flatMap(\.output.framesToSend).map(op(of:)) == handshakeOps)
    #expect(steps.flatMap(\.output.historyRecords).count == 9)
}

@Test func anErrorStatusInAReplyToTheSessionsCommandFailsTheSync() throws {
    // The Strap's captured reply to the 0x0b get clock, body `24 89 0b 03 01 …`, with Frame
    // byte 12 (the status) changed from 0x01 (done) to 0x03, and the CRC recomputed with
    // zlib.crc32 (captured 7c 24 aa 62, now e3 ba 91 8e).
    let captured = strapMessages[getClockReplyIndex].bytes
    try #require(captured[10] == 0x0b && captured[12] == 0x01)
    let errorReply: [UInt8] = [
        0xaa, 0x01, 0x14, 0x00, 0x01, 0x00, 0x21, 0xb1,
        0x24, 0x89, 0x0b, 0x03, 0x03, 0x78, 0x00, 0xe1,
        0x6a, 0x8f, 0x22, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xe3, 0xba, 0x91, 0x8e,
    ]
    let steps = replaySession(
        strapMessages(replacingAt: getClockReplyIndex, with: errorReply),
        startingAt: capturedPhoneTime
    )
    let failedAt = getClockReplyIndex + 1

    #expect(steps[failedAt - 1].stateAfter == .running)
    expectFailedThroughout(steps[failedAt...], with: .errorStatus(op: 0x0b, status: 0x03))
    // Hello, both set clocks and get clock went out; no command after.
    #expect(steps.flatMap(\.output.framesToSend).map(op(of:)) == [0x91, 0x0a, 0x0a, 0x0b])
    #expect(steps.flatMap(\.output.historyRecords).isEmpty)
}

@Test func anErrorStatusInAReplyToACommandTheSessionNeverSentDoesNotFailTheSync() throws {
    // The Strap answers the captured app's 0x3f with status 0x03 (hr-tracker: the Strap logs
    // 0x3f as unknown). This session never sends 0x3f, so the reply is not its concern.
    let reply = strapMessages[reply3fIndex].bytes
    try #require(reply[10] == 0x3f && reply[12] == 0x03)
    #expect(replay[reply3fIndex + 1].stateAfter == .running)
    #expect(replay.last?.stateAfter == .completed)
}

@Test func silenceFromTheStartForJustUnder10SecondsLeavesTheSyncRunning() {
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)

    session.timeOutIfSilent(at: capturedPhoneTime.addingTimeInterval(9.999))
    #expect(session.state == .running)
}

@Test func silenceFor10SecondsFromTheStartFailsTheSyncAsTimedOut() {
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)

    session.timeOutIfSilent(at: capturedPhoneTime.addingTimeInterval(10))
    #expect(session.state == .failed(.timedOut))
}

@Test func silenceIsMeasuredFromTheLastMessageTheStrapSent() {
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)
    let heard = capturedPhoneTime.addingTimeInterval(5)
    _ = session.receive(strapMessages[0].bytes, at: heard)

    session.timeOutIfSilent(at: heard.addingTimeInterval(9.999))
    #expect(session.state == .running)
    session.timeOutIfSilent(at: heard.addingTimeInterval(10))
    #expect(session.state == .failed(.timedOut))
}

@Test func aFrameAfter10SecondsOfSilenceFailsTheSyncAndIsOnlyLogged() {
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)
    let late = capturedPhoneTime.addingTimeInterval(10)

    let output = session.receive(strapMessages[0].bytes, at: late)
    #expect(session.state == .failed(.timedOut))
    #expect(output.framesToSend.isEmpty)
    #expect(output.syncLog.map(\.bytes) == [strapMessages[0].bytes])
    #expect(output.syncLog.map(\.direction) == [.fromStrap])
}

@Test func aTimeoutFailsTheSyncAndLaterFramesAreOnlyLogged() throws {
    try #require(isMetadataFrame(strapMessages[firstBatchStartIndex].bytes, kind: batchStartKind))
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)
    var lastHeard = capturedPhoneTime
    for (index, message) in strapMessages[...firstBatchStartIndex].enumerated() {
        lastHeard = capturedPhoneTime.addingTimeInterval(Double(index + 1))
        _ = session.receive(message.bytes, at: lastHeard)
    }
    #expect(session.state == .running)

    session.timeOutIfSilent(at: lastHeard.addingTimeInterval(10))
    #expect(session.state == .failed(.timedOut))

    var steps: [Step] = []
    for (index, message) in strapMessages[(firstBatchStartIndex + 1)...].enumerated() {
        let time = capturedPhoneTime.addingTimeInterval(Double(firstBatchStartIndex + 2 + index))
        let output = session.receive(message.bytes, at: time)
        steps.append(
            Step(fed: message.bytes, time: time, output: output, stateAfter: session.state)
        )
    }
    // Every Strap message after the first Batch start, through the complete Frame.
    #expect(steps.count == 282)
    expectFailedThroughout(steps[...], with: .timedOut)
}

@Test func silenceAfterTheSyncCompletesLeavesItCompleted() {
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)
    var lastHeard = capturedPhoneTime
    for (index, message) in strapMessages.enumerated() {
        lastHeard = capturedPhoneTime.addingTimeInterval(Double(index + 1))
        _ = session.receive(message.bytes, at: lastHeard)
    }
    #expect(session.state == .completed)

    session.timeOutIfSilent(at: lastHeard.addingTimeInterval(10))
    #expect(session.state == .completed)
}

// MARK: - Progress and time left

/// Index in `strapMessages` of connection 2's first per-second 0x2f Frame (19:50:20.9, Record
/// Counter 2863306, timestamp 1793130439 = 2026-10-27T19:47:19Z): the session's first History
/// Record. The nine History Records up to `tenthRecordOfFirstBatchIndex` follow it, 1 s apart.
private let firstRecordIndex = 42

/// Starts a fresh session at `startTime` and feeds it `messages` one second apart, as
/// `replaySession` does, returning the session's progress after `start` and after each message.
private func progressReplaying(
    _ messages: [SyncCapture.Message],
    startingAt startTime: Date = capturedPhoneTime
) -> (progress: [Double?], session: HistorySync) {
    var session = HistorySync()
    _ = session.start(at: startTime)
    var progress: [Double?] = [session.progress]
    for (index, message) in messages.enumerated() {
        _ = session.receive(
            message.bytes,
            at: startTime.addingTimeInterval(Double(index + 1))
        )
        progress.append(session.progress)
    }
    return (progress, session)
}

@Test func progressRunsFromTheFirstHistoryRecordToTheStartTimeAndNeverGoesBackwards() throws {
    try #require(
        strapMessages[tenthRecordOfFirstBatchIndex].bytes[11..<15] == [0xd3, 0xb0, 0x2b, 0x00]
    )
    let (progress, session) = progressReplaying(Array(strapMessages))
    try #require(session.state == .completed)
    // progress[0] is after start; progress[i + 1] is after strapMessages[i].
    #expect(progress[...firstRecordIndex].allSatisfy { $0 == nil })

    let afterFirstRecord = progress[(firstRecordIndex + 1)...]
    let values = afterFirstRecord.compactMap { $0 }
    #expect(values.count == afterFirstRecord.count)
    #expect(values.allSatisfy { (0...1).contains($0) })
    #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })

    // First History Record 1793130439 (19:47:19Z), start time 1793130616 (19:50:16Z): 177 s
    // to cover. The first History Record alone has come 0 s: progress 0.
    #expect(progress[firstRecordIndex + 1] == 0)
    // After the 10th, Record Counter 2863315 at 1793130448 (19:47:28Z): 9 / 177.
    let afterTenth = try #require(progress[tenthRecordOfFirstBatchIndex + 1])
    #expect(abs(afterTenth - 0.050_847_457_627_118_64) < 1e-9)
    // The last History Record, Record Counter 2863483, is at 1793130619 (19:50:19Z), 3 s past
    // the start time: 180 / 177 clamps to 1.
    let last = try #require(progress.last ?? nil)
    #expect(abs(last - 1) < 1e-9)
}

@Test func progressAfterTheLastHistoryRecordIsHowFarItCameTowardsTheStartTime() throws {
    // The same replay started 10 s later, at 1793130626 (19:50:26Z), so nothing is clamped: the
    // first History Record (1793130439) is 187 s before the start and the last (1793130619) is
    // 180 s after the first: 180 / 187.
    let start = Date(timeIntervalSince1970: 1_793_130_626)
    let (progress, session) = progressReplaying(Array(strapMessages), startingAt: start)
    try #require(session.state == .completed)
    let last = try #require(progress.last ?? nil)
    #expect(abs(last - 0.962_566_844_919_786_1) < 1e-9)
}

@Test func timeLeftIsKnownTwoSecondsAfterTheFirstHistoryRecordArrives() throws {
    try #require(
        strapMessages[tenthRecordOfFirstBatchIndex].bytes[11..<15] == [0xd3, 0xb0, 0x2b, 0x00]
    )
    // Start at T = 1793130616 (19:50:16Z). Everything up to and including the 10th History
    // Record arrives at T + 1 s, so the first History Record arrived at T + 1 s and progress is
    // (1793130448 − 1793130439) / (1793130616 − 1793130439) = 9 / 177.
    let start = capturedPhoneTime
    let firstArrival = start.addingTimeInterval(1)
    var session = HistorySync()
    _ = session.start(at: start)
    for message in strapMessages[...tenthRecordOfFirstBatchIndex] {
        _ = session.receive(message.bytes, at: firstArrival)
    }
    let progress = try #require(session.progress)
    try #require(abs(progress - 0.050_847_457_627_118_64) < 1e-9)

    // 1.9 s after the first History Record arrived: too soon.
    #expect(session.timeLeft(at: firstArrival.addingTimeInterval(1.9)) == nil)
    // 2 s after: 2 × (1 − 9/177) ÷ (9/177) = 2 × 168 / 9 = 37.333… s.
    let atTwoSeconds = try #require(session.timeLeft(at: firstArrival.addingTimeInterval(2)))
    #expect(abs(atTwoSeconds - 37.333_333_333_333_33) < 1e-9)
    // 10 s after: 10 × 168 / 9 = 186.666… s.
    let atTenSeconds = try #require(session.timeLeft(at: firstArrival.addingTimeInterval(10)))
    #expect(abs(atTenSeconds - 186.666_666_666_666_67) < 1e-9)

    // The rest arrives at T + 10 s (under the 10 s silence timeout); the last History Record
    // (1793130619) brings progress to 1, so nothing is left.
    for message in strapMessages[(tenthRecordOfFirstBatchIndex + 1)...] {
        _ = session.receive(message.bytes, at: start.addingTimeInterval(10))
    }
    try #require(session.state == .completed)
    #expect(session.timeLeft(at: start.addingTimeInterval(11)) == 0)
}

@Test func anEmptySyncReportsNoProgressAndCompletes() throws {
    // Connection 1's second sync: an empty Batch with Sync Cursor ffffffffffffffff, no
    // per-second 0x2f Frames, then complete.
    let connection1Syncs = syncs(in: SyncCapture.historySync20261027.connections[0]).syncs
    try #require(connection1Syncs.count == 3)
    let (progress, session) = progressReplaying(connection1Syncs[1])
    #expect(progress.count == connection1Syncs[1].count + 1)
    #expect(progress.allSatisfy { $0 == nil })
    #expect(session.timeLeft(at: capturedPhoneTime.addingTimeInterval(60)) == nil)
    #expect(session.state == .completed)
}

@Test func timeLeftReadsInWholeMinutesRoundedUpOrLessThanAMinute() {
    // Spec 001, Sync progress: "about N min left" rounded up, or "less than a minute left".
    #expect(HistorySync.timeLeftText(0) == "less than a minute left")
    #expect(HistorySync.timeLeftText(59.9) == "less than a minute left")
    #expect(HistorySync.timeLeftText(60) == "about 1 min left")
    #expect(HistorySync.timeLeftText(60.1) == "about 2 min left")
    #expect(HistorySync.timeLeftText(186.67) == "about 4 min left")
}

// MARK: - Data range and battery level

/// Index in `strapMessages` of the Strap's final reply to the session's `0x1a` (19:50:18.650),
/// body `24 8e 1a 08 01 1d …`: body byte 5 is the battery percentage, 0x1d = 29.
private let batteryReplyIndex = 10

/// Index in `strapMessages` of the Strap's first reply to the session's `0x22` (19:50:18.950),
/// body `24 8f 22 09 02 …`: status 0x02, not the final reply, so it carries no data range.
private let dataRangePendingReplyIndex = 11

/// Index in `strapMessages` of the Strap's final reply to the session's `0x22` (19:50:18.952),
/// body `24 90 22 09 01 …`, 72 bytes. Body bytes 46..<50 (repeated at 54..<58) are `c7 ff e0 6a`
/// and body bytes 62..<66 are `6b 00 e1 6a`, each a u32 little-endian Unix time.
private let dataRangeReplyIndex = 12

/// The data range connection 2's first sync reports, worked out by hand from that reply.
/// 0x6ae10000 = 0x6ae10078 − 0x78 = 1793130616 − 120 = 1793130496 (19:48:16Z).
/// Oldest 0x6ae0ffc7 = 1793130496 − 0x39 (57) = 1793130439: 2026-10-27T19:47:19Z, connection 2's
/// first History Record. Newest 0x6ae1006b = 1793130496 + 0x6b (107) = 1793130603:
/// 2026-10-27T19:50:03Z.
private let connection2DataRange = HistoryDataRange(
    oldest: Date(timeIntervalSince1970: 1_793_130_439),
    newest: Date(timeIntervalSince1970: 1_793_130_603)
)

/// Starts a fresh session at `capturedPhoneTime` and feeds it `strapMessages` one second apart,
/// as `replaySession` does, returning the session after `start` and after each message.
private func sessionsReplayingConnection2() -> [HistorySync] {
    var session = HistorySync()
    _ = session.start(at: capturedPhoneTime)
    var sessions = [session]
    for (index, message) in strapMessages.enumerated() {
        _ = session.receive(
            message.bytes,
            at: capturedPhoneTime.addingTimeInterval(Double(index + 1))
        )
        sessions.append(session)
    }
    return sessions
}

@Test func batteryLevelIsUnknownUntilTheStrapRepliesToTheBatteryCommand() throws {
    let reply = strapMessages[batteryReplyIndex].bytes
    try #require(reply[headerSize..<(headerSize + 6)] == [0x24, 0x8e, 0x1a, 0x08, 0x01, 0x1d])
    let sessions = sessionsReplayingConnection2()
    try #require(sessions.last?.state == .completed)
    // sessions[0] is after start; sessions[i + 1] is after strapMessages[i].
    #expect(sessions[...batteryReplyIndex].allSatisfy { $0.batteryLevel == nil })
    #expect(sessions[(batteryReplyIndex + 1)...].allSatisfy { $0.batteryLevel == 29 })
}

@Test func dataRangeIsUnknownUntilTheStrapsFinalReplyToTheDataRangeCommand() throws {
    let pending = strapMessages[dataRangePendingReplyIndex].bytes
    try #require(pending[headerSize..<(headerSize + 5)] == [0x24, 0x8f, 0x22, 0x09, 0x02])
    let reply = strapMessages[dataRangeReplyIndex].bytes
    try #require(reply.count == headerSize + 72 + crcSize)
    try #require(reply[headerSize..<(headerSize + 5)] == [0x24, 0x90, 0x22, 0x09, 0x01])
    try #require(reply[(headerSize + 46)..<(headerSize + 50)] == [0xc7, 0xff, 0xe0, 0x6a])
    try #require(reply[(headerSize + 54)..<(headerSize + 58)] == [0xc7, 0xff, 0xe0, 0x6a])
    try #require(reply[(headerSize + 62)..<(headerSize + 66)] == [0x6b, 0x00, 0xe1, 0x6a])
    let sessions = sessionsReplayingConnection2()
    try #require(sessions.last?.state == .completed)
    // sessions[0] is after start; sessions[i + 1] is after strapMessages[i]. The status-0x02
    // reply before the final one brings no data range.
    #expect(sessions[...dataRangeReplyIndex].allSatisfy { $0.dataRange == nil })
    #expect(
        sessions[(dataRangeReplyIndex + 1)...].allSatisfy { $0.dataRange == connection2DataRange }
    )
}

// MARK: - Failure reasons

@Test(arguments: [
    (HistorySyncFailure.badCRC, "A Frame from the Strap failed its CRC check."),
    (.lengthMismatch, "A Frame from the Strap had the wrong length."),
    (
        .undecodableHistoryRecord(.unexpectedLength(12)),
        "A History Record couldn't be decoded (unexpectedLength(12))."
    ),
    (.errorStatus(op: 0x3f, status: 0x03), "The Strap answered command 0x3f with error 0x03."),
    (.timedOut, "The Strap stopped responding."),
])
func aFailureReadsAsItsReason(failure: HistorySyncFailure, reason: String) {
    #expect(failure.reason == reason)
}

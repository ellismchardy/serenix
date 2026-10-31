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

/// A `0x31` metadata Frame's body[2]: the end of a Batch, or the end of the whole sync.
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

/// Starts a session at `startTime`, then feeds it every Strap message of connection 2 up to
/// and including the complete Frame. Each receive call gets its own time, one second apart.
private func replayConnection2(startingAt startTime: Date) -> [Step] {
    var session = HistorySync()
    var steps: [Step] = []
    let started = session.start(at: startTime)
    steps.append(Step(fed: nil, time: startTime, output: started, stateAfter: session.state))
    for (index, message) in strapMessages.enumerated() {
        let time = startTime.addingTimeInterval(Double(index + 1))
        let output = session.receive(message.bytes, at: time)
        steps.append(
            Step(fed: message.bytes, time: time, output: output, stateAfter: session.state)
        )
    }
    return steps
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

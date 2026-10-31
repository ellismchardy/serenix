import Foundation

/// Which way a Frame went.
public enum SyncDirection: Equatable, Sendable {
    case toStrap
    case fromStrap
}

/// One message in the Sync Log.
public struct SyncLogEntry: Equatable, Sendable {
    public let time: Date
    public let direction: SyncDirection
    /// Exactly as sent or received. Usually a whole Frame, but anything the Strap sent is kept.
    public let bytes: [UInt8]
}

/// Where a History Sync has got to.
public enum HistorySyncState: Equatable, Sendable {
    case running
    case completed
}

/// What one step of a History Sync produced.
public struct HistorySyncOutput: Equatable, Sendable {
    /// Whole Frames to write to the Strap, in order.
    public var framesToSend: [[UInt8]] = []
    public var historyRecords: [HistoryRecord] = []
    /// Every Frame in or out during this step, in order.
    public var syncLog: [SyncLogEntry] = []
}

/// One History Sync with the Strap, as a pure state machine.
///
/// The caller moves bytes: it writes `framesToSend` and feeds back everything the Strap sends.
/// The session sends the handshake in the captured third-party app's order (spec 001), asks
/// for history, acknowledges each Batch by echoing its Sync Cursor, and completes when the
/// Strap says so. It never stores the Sync Cursor; the Strap owns it.
public struct HistorySync: Sendable {
    public private(set) var state: HistorySyncState = .running

    private let decoder: any HistoryRecordDecoder
    /// Groups of commands still to send. A group goes out together, and the next one waits
    /// for the Strap's final reply to the group's last command.
    private var pendingSteps: [[Command]] = []
    /// The op of the command whose final reply the session is waiting for.
    private var awaitedOp: UInt8?
    private var nextSequence: UInt8 = 1

    public init(decoder: any HistoryRecordDecoder = Whoop5HistoryRecordDecoder()) {
        self.decoder = decoder
    }

    /// Begins the sync; `time` is the phone's current time, used to set the Strap's clock.
    public mutating func start(at time: Date) -> HistorySyncOutput {
        let seconds = UInt32(time.timeIntervalSince1970)
        let clock = (0..<4).map { UInt8(truncatingIfNeeded: seconds >> (8 * $0)) }
        pendingSteps = [
            [Command(op: helloOp, arguments: [0x01])],
            // The captured app sends both forms back to back; the Strap replies to the second.
            [
                Command(op: setClockOp, arguments: clock + [0x00, 0x00, 0x00, 0x00]),
                Command(op: setClockOp, arguments: clock + [0x00, 0x00, 0x00, 0x00, 0x00]),
            ],
            [Command(op: getClockOp, arguments: [0x00])],
            [Command(op: unknown61Op, arguments: [0x00])],
            [Command(op: unknown45Op, arguments: [0x02, 0xff, 0x00, 0x00, 0x00])],
            [Command(op: batteryOp, arguments: [0x00])],
            [Command(op: dataRangeOp, arguments: [0x00])],
            [Command(op: sendHistoryOp, arguments: [0x00])],
        ]
        var output = HistorySyncOutput()
        sendNextStep(at: time, into: &output)
        return output
    }

    /// Feeds one message the Strap sent, as received on any notify channel.
    public mutating func receive(_ bytes: [UInt8], at time: Date) -> HistorySyncOutput {
        var output = HistorySyncOutput()
        output.syncLog.append(SyncLogEntry(time: time, direction: .fromStrap, bytes: bytes))
        // Messages that aren't Frames are logged and otherwise ignored. A bad CRC fails the
        // sync once the failure rules exist (plan 001, task 7).
        guard state == .running, let frame = try? Frame(bytes: bytes) else { return output }
        let body = frame.body
        switch frame.type {
        case replyType where body.count > replyStatusOffset:
            if body[replyOpOffset] == awaitedOp, body[replyStatusOffset] == replyDone {
                sendNextStep(at: time, into: &output)
            }
        case historicalDataType:
            if let record = decoder.historyRecord(from: frame) {
                output.historyRecords.append(record)
            }
        case metadataType where body.count > metadataKindOffset:
            switch body[metadataKindOffset] {
            case batchEndKind where body.count >= syncCursorRange.upperBound:
                let acknowledge = Command(
                    op: acknowledgeOp,
                    arguments: [0x01] + body[syncCursorRange]
                )
                send(acknowledge, at: time, into: &output)
            case syncCompleteKind:
                state = .completed
            default:
                break
            }
        default:
            break
        }
        return output
    }

    private mutating func sendNextStep(at time: Date, into output: inout HistorySyncOutput) {
        guard !pendingSteps.isEmpty else {
            awaitedOp = nil
            return
        }
        let step = pendingSteps.removeFirst()
        for command in step {
            send(command, at: time, into: &output)
        }
        awaitedOp = step.last?.op
    }

    private mutating func send(
        _ command: Command,
        at time: Date,
        into output: inout HistorySyncOutput
    ) {
        // As in the capture, hello is numbered 1 and the command after it is numbered 1 again.
        let sequence = command.op == helloOp ? helloSequence : nextSequence
        // How the app numbers past 255 is unverified (the capture never gets that far).
        if command.op != helloOp { nextSequence &+= 1 }
        let bytes: [UInt8]
        do {
            bytes = try command.frame(sequence: sequence)
        } catch {
            preconditionFailure("every History Sync command has a known header check: \(error)")
        }
        output.framesToSend.append(bytes)
        output.syncLog.append(SyncLogEntry(time: time, direction: .toStrap, bytes: bytes))
    }
}

// Command ops, from hr-tracker `docs/protocol.md` and the 27 Oct 2026 capture.
private let helloOp: UInt8 = 0x91
private let setClockOp: UInt8 = 0x0a
private let getClockOp: UInt8 = 0x0b
private let batteryOp: UInt8 = 0x1a
/// `0x61` and `0x45` are sent as captured; what they do is an open question in spec 001.
private let unknown61Op: UInt8 = 0x61
private let unknown45Op: UInt8 = 0x45
private let dataRangeOp: UInt8 = 0x22
private let sendHistoryOp: UInt8 = 0x16
/// Acknowledges a Batch: `01`, then the Batch's 8-byte Sync Cursor.
private let acknowledgeOp: UInt8 = 0x17
private let helloSequence: UInt8 = 1

// Frame types (body[0]).
private let replyType: UInt8 = 0x24
private let historicalDataType: UInt8 = 0x2f
private let metadataType: UInt8 = 0x31

/// A reply body is `24 <strap seq> <op> <phone seq> <status> …`.
private let replyOpOffset = 2
private let replyStatusOffset = 4
/// The final reply to a command. `02` comes first when a longer reply follows.
private let replyDone: UInt8 = 0x01

/// A metadata body's byte 2: `01` Batch start, `02` Batch end, `03` sync complete (worked out
/// from the 27 Oct 2026 capture).
private let metadataKindOffset = 2
private let batchEndKind: UInt8 = 0x02
private let syncCompleteKind: UInt8 = 0x03
/// Where a Batch-end body carries the Sync Cursor.
private let syncCursorRange = 13..<21

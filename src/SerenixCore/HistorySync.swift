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
    case failed(HistorySyncFailure)
}

/// Why a History Sync failed. The Batch being received when it failed is never acknowledged,
/// so the Strap sends it again next time.
public enum HistorySyncFailure: Error, Equatable, Sendable {
    /// A Frame from the Strap failed its CRC check.
    case badCRC
    /// A Frame from the Strap whose length field disagrees with its size, e.g. one cut short.
    case lengthMismatch
    /// The decoder rejected a per-second `0x2f` Frame.
    case undecodableHistoryRecord(HistoryRecordError)
    /// The Strap's reply to one of this session's commands carried an error status.
    case errorStatus(op: UInt8, status: UInt8)
    /// The caller reported that the Strap stopped responding.
    case timedOut
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
    /// Ops of the commands this session has sent; a reply to any other op is not ours to judge.
    private var sentOps: Set<UInt8> = []
    /// History Records already yielded in this sync, so a Batch the Strap re-sends is skipped.
    private var yieldedRecords: Set<HistoryRecordKey> = []

    public init(decoder: any HistoryRecordDecoder = Whoop5HistoryRecordDecoder()) {
        self.decoder = decoder
    }

    /// Begins the sync; `time` is the phone's current time, used to set the Strap's clock.
    public mutating func start(at time: Date) -> HistorySyncOutput {
        let clock = littleEndianBytes(UInt32(time.timeIntervalSince1970))
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
        guard state == .running else { return output }
        let frame: Frame
        do {
            frame = try Frame(bytes: bytes)
        } catch .badCRC {
            state = .failed(.badCRC)
            return output
        } catch .lengthMismatch {
            // Likely a Frame cut short; ignoring it could acknowledge a lost History Record.
            state = .failed(.lengthMismatch)
            return output
        } catch {
            // Messages that aren't Frames are logged and otherwise ignored.
            return output
        }
        let body = frame.body
        switch frame.type {
        case FrameType.reply where body.count > replyStatusOffset:
            let op = body[replyOpOffset]
            let status = body[replyStatusOffset]
            if sentOps.contains(op), status != replyDone, status != replyMore {
                state = .failed(.errorStatus(op: op, status: status))
            } else if op == awaitedOp, status == replyDone {
                sendNextStep(at: time, into: &output)
            }
        case FrameType.historicalData:
            let record: HistoryRecord?
            do {
                record = try decoder.historyRecord(from: frame)
            } catch {
                state = .failed(.undecodableHistoryRecord(error))
                return output
            }
            if let record, yieldedRecords.insert(HistoryRecordKey(record)).inserted {
                output.historyRecords.append(record)
            }
        case FrameType.metadata where body.count > metadataKindOffset:
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

    /// Reports that the Strap stopped responding; a running sync fails.
    public mutating func reportTimeout() {
        guard state == .running else { return }
        state = .failed(.timedOut)
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
        sentOps.insert(command.op)
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

/// A reply body is `24 <strap seq> <op> <phone seq> <status> …`.
private let replyOpOffset = 2
private let replyStatusOffset = 4
/// The final reply to a command. `02` comes first when a longer reply follows. Any other
/// status is an error: the Strap answers `0x3f`, which it logs as unhandled, with `03`.
private let replyDone: UInt8 = 0x01
private let replyMore: UInt8 = 0x02

/// A metadata body's byte 2: `01` Batch start, `02` Batch end, `03` sync complete (worked out
/// from the 27 Oct 2026 capture).
private let metadataKindOffset = 2
private let batchEndKind: UInt8 = 0x02
private let syncCompleteKind: UInt8 = 0x03
/// Where a Batch-end body carries the Sync Cursor.
private let syncCursorRange = 13..<21

/// What identifies a History Record: its Record Counter and timestamp together, because after a
/// reboot the Strap can reuse a Record Counter for a new record (spec 001).
private struct HistoryRecordKey: Hashable {
    let recordCounter: UInt32
    let timestamp: Date

    init(_ record: HistoryRecord) {
        recordCounter = record.recordCounter
        timestamp = record.timestamp
    }
}

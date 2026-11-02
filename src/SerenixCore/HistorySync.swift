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

/// The span of History Records the Strap reported holding, in its reply to `0x22`.
public struct HistoryDataRange: Equatable, Sendable {
    /// The oldest History Record the Strap still has to send.
    public let oldest: Date
    /// A recent History Record, typically about 10 s before the newest one it sends.
    public let newest: Date

    public init(oldest: Date, newest: Date) {
        self.oldest = oldest
        self.newest = newest
    }
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
    /// The Strap sent nothing for 10 s (`timeOutIfSilent(at:)`).
    case timedOut

    /// Why the sync failed, as the user reads it.
    public var reason: String {
        switch self {
        case .badCRC:
            "A Frame from the Strap failed its CRC check."
        case .lengthMismatch:
            "A Frame from the Strap had the wrong length."
        case .undecodableHistoryRecord(let error):
            "A History Record couldn't be decoded (\(error))."
        case .errorStatus(let op, let status):
            "The Strap answered command 0x\(hex([op])) with error 0x\(hex([status]))."
        case .timedOut:
            "The Strap stopped responding."
        }
    }
}

/// What one step of a History Sync produced.
public struct HistorySyncOutput: Equatable, Sendable {
    /// Whole Frames to write to the Strap, in order.
    public var framesToSend: [[UInt8]] = []
    public var historyRecords: [HistoryRecord] = []
    /// Every Frame in or out during this step, in order.
    public var syncLog: [SyncLogEntry] = []
    /// Live HR readings from `0x28` Frames, which the Strap sends only while Live HR is on
    /// (spec 006).
    public var liveHRReadings: [LiveHRReading] = []
    /// `0x28` Frames in a layout the decoder doesn't know; each is still in `syncLog`. A Frame
    /// failing its own check fails the sync instead (spec 001).
    public var liveHRSkipped: [LiveHRSkip] = []
}

/// One History Sync with the Strap, as a pure state machine.
///
/// The caller moves bytes: it writes `framesToSend` and feeds back everything the Strap sends.
/// The session sends the handshake in the captured third-party app's order (spec 001), asks
/// for history, acknowledges each Batch by echoing its Sync Cursor, and completes when the
/// Strap says so. It never stores the Sync Cursor; the Strap owns it.
public struct HistorySync: Sendable {
    public private(set) var state: HistorySyncState = .running
    /// What the Strap reported in this sync: its data range (`0x22`) and battery level in
    /// percent (`0x1a`). Nil until it replies.
    public private(set) var dataRange: HistoryDataRange?
    public private(set) var batteryLevel: Int?

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
    private var yieldedRecords: Set<String> = []
    /// For progress and time left: when the sync started, this sync's first and newest History
    /// Record timestamps (the Strap's clock), and when the first one arrived.
    private var startTime: Date?
    private var firstRecordTimestamp: Date?
    private var newestRecordTimestamp: Date?
    private var firstRecordArrival: Date?
    /// When the sync started or the Strap last sent anything, for the silence timeout.
    private var lastHeardFromStrap: Date?

    public init(decoder: any HistoryRecordDecoder = Whoop5HistoryRecordDecoder()) {
        self.decoder = decoder
    }

    /// Begins the sync; `time` is the phone's current time, used to set the Strap's clock.
    public mutating func start(at time: Date) -> HistorySyncOutput {
        startTime = time
        lastHeardFromStrap = time
        let clock = littleEndianBytes(UInt32(time.timeIntervalSince1970))
        pendingSteps = [
            [.hello],
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
        // A message after a long silence comes too late: the sync has already timed out.
        timeOutIfSilent(at: time)
        guard state == .running else { return output }
        lastHeardFromStrap = time
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
            if status == replyDone { noteReport(op: op, body: body) }
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
            if let record, yieldedRecords.insert(record.identity).inserted {
                noteProgress(of: record, arrivedAt: time)
                output.historyRecords.append(record)
            }
        case FrameType.realtimeData:
            do {
                if let reading = try liveHRReading(from: frame) {
                    output.liveHRReadings.append(reading)
                }
            } catch {
                output.liveHRSkipped.append(.reading(error))
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

    /// Turns Live HR on or off on this sync's connection (spec 006; ADR 0007): sends `0x03 01` /
    /// `0x03 00` with the next sequence number. Nothing while the sync isn't running. Live HR is
    /// extra to the sync, so the Strap's reply to it never fails the sync. Once the sync has
    /// ended this sends nothing and later readings are dropped, so a caller still showing Live
    /// HR carries on with a `LiveHRSession`.
    public mutating func setLiveHR(_ on: Bool, at time: Date) -> HistorySyncOutput {
        var output = HistorySyncOutput()
        guard state == .running else { return output }
        send(.liveHR(on: on), at: time, into: &output)
        return output
    }

    /// Fails a running sync as timed out if the Strap has sent nothing for
    /// `strapSilenceTimeout` since the sync started or its last message. `receive` checks this
    /// too; the caller also checks regularly, so a long gap (e.g. while iOS held the app up)
    /// counts as the Strap not responding (spec 001).
    public mutating func timeOutIfSilent(at now: Date) {
        guard state == .running, let lastHeardFromStrap,
            now.timeIntervalSince(lastHeardFromStrap) >= strapSilenceTimeout
        else { return }
        state = .failed(.timedOut)
    }

    /// How far this sync has got, 0 to 1: from its first History Record's timestamp to the time
    /// it started, measured by the newest History Record so far (spec 001, Sync progress). Nil
    /// before the first History Record, so for an empty sync it stays nil.
    public var progress: Double? {
        guard let startTime, let first = firstRecordTimestamp, let newest = newestRecordTimestamp
        else { return nil }
        let span = startTime.timeIntervalSince(first)
        // A Strap clock ahead of the phone's can put records at or past the start time.
        guard span > 0 else { return 1 }
        return min(max(newest.timeIntervalSince(first) / span, 0), 1)
    }

    /// Seconds left, from the rate so far: the time since the first History Record arrived,
    /// scaled by the progress still to go. Nil until `timeLeftDelay` after that first arrival,
    /// and while there's no progress to go on.
    public func timeLeft(at now: Date) -> TimeInterval? {
        guard let progress, let arrival = firstRecordArrival else { return nil }
        let elapsed = now.timeIntervalSince(arrival)
        guard elapsed >= timeLeftDelay, progress > 0 else { return nil }
        guard progress < 1 else { return 0 }
        return elapsed * (1 - progress) / progress
    }

    /// How the time left reads (spec 001, Sync progress): "about N min left", rounded up to whole
    /// minutes, or "less than a minute left".
    public static func timeLeftText(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "less than a minute left" }
        return "about \(Int((seconds / 60).rounded(.up))) min left"
    }

    /// Keeps the battery level and data range from the Strap's final replies to `0x1a` and
    /// `0x22`.
    private mutating func noteReport(op: UInt8, body: [UInt8]) {
        switch op {
        case batteryOp where body.count > batteryLevelOffset:
            batteryLevel = Int(body[batteryLevelOffset])
        case dataRangeOp where body.count >= dataRangeNewestOffset + 4:
            dataRange = HistoryDataRange(
                oldest: Date(
                    timeIntervalSince1970: TimeInterval(uint32(body, at: dataRangeOldestOffset))
                ),
                newest: Date(
                    timeIntervalSince1970: TimeInterval(uint32(body, at: dataRangeNewestOffset))
                )
            )
        default:
            break
        }
    }

    private mutating func noteProgress(of record: HistoryRecord, arrivedAt time: Date) {
        if firstRecordTimestamp == nil {
            firstRecordTimestamp = record.timestamp
            firstRecordArrival = time
        }
        // The newest so far, so progress never goes backwards even if records arrive out of
        // order.
        if let newest = newestRecordTimestamp, newest >= record.timestamp { return }
        newestRecordTimestamp = record.timestamp
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
        // A reply to Live HR that isn't "done" must not fail the sync (spec 006).
        if command.op != liveHROp { sentOps.insert(command.op) }
        output.framesToSend.append(bytes)
        output.syncLog.append(SyncLogEntry(time: time, direction: .toStrap, bytes: bytes))
    }
}

// Command ops, from hr-tracker `docs/protocol.md` and the 27 Oct 2026 capture.
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
/// Body offsets in the Strap's final replies, worked out from the 27 Oct 2026 capture and the
/// first phone syncs, where they matched every sync (not yet in hr-tracker `docs/protocol.md`):
/// `0x1a`'s battery percentage (the Strap's console log reports the same value), and `0x22`'s
/// u32 LE Unix-seconds oldest History Record still to send (repeated at 54) and a newest one.
private let batteryLevelOffset = 5
private let dataRangeOldestOffset = 46
private let dataRangeNewestOffset = 62
/// Seconds without a message from the Strap before a sync fails as "stopped responding" (spec
/// 001, an assumption: the capture shows replies within milliseconds).
private let strapSilenceTimeout: TimeInterval = 10
/// Seconds after the first History Record before the time left is shown: too few records
/// before then to tell the rate (spec 001, an assumption).
private let timeLeftDelay: TimeInterval = 2

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

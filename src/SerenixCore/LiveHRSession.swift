import Foundation

/// What one step of a Live HR session produced.
public struct LiveHRSessionOutput: Equatable, Sendable {
    /// Whole Frames to write to the Strap, in order.
    public var framesToSend: [[UInt8]] = []
    public var readings: [LiveHRReading] = []
    /// Frames that looked like Live HR but couldn't be read, and why; each is still in
    /// `syncLog`. Messages that aren't Frames and Frames of other types aren't listed.
    public var skipped: [LiveHRSkip] = []
    /// Every message in or out during this step, in order.
    public var syncLog: [SyncLogEntry] = []
}

/// Why a message during a Live HR session gave no reading.
public enum LiveHRSkip: Equatable, Sendable {
    /// A Frame that failed its check, e.g. a bad CRC.
    case frame(FrameError)
    /// A `0x28` Frame in a layout the decoder doesn't know.
    case reading(LiveHRReadingError)
}

/// Live HR from the Strap when no History Sync is running (spec 006; ADR 0007), as a pure state
/// machine.
///
/// The caller moves bytes: it writes `framesToSend` and feeds back everything the Strap sends.
/// `start` sends hello and Live HR on back to back, without waiting for hello's reply: in the
/// 27 Oct 2026 capture the Strap left the first hello unanswered, and Live HR came 100 ms after
/// `0x03 01` all the same. Every message is logged; a Frame that can't be read is skipped and
/// the stream carries on.
public struct LiveHRSession: Sendable {
    private var isOn = false
    private var nextSequence: UInt8 = 1

    public init() {}

    /// Starts Live HR on a new connection, which numbers its commands from 1 again.
    public mutating func start(at time: Date) -> LiveHRSessionOutput {
        var output = LiveHRSessionOutput()
        nextSequence = 1
        send(.hello, at: time, into: &output)
        send(.liveHR(on: true), at: time, into: &output)
        isOn = true
        return output
    }

    /// Feeds one message the Strap sent, as received on any notify channel.
    public mutating func receive(_ bytes: [UInt8], at time: Date) -> LiveHRSessionOutput {
        var output = LiveHRSessionOutput()
        output.syncLog.append(SyncLogEntry(time: time, direction: .fromStrap, bytes: bytes))
        // Readings after `stop` are stale by definition.
        guard isOn else { return output }
        do {
            let frame = try Frame(bytes: bytes)
            do {
                if let reading = try liveHRReading(from: frame) { output.readings.append(reading) }
            } catch {
                output.skipped.append(.reading(error))
            }
        } catch .notAFrame {
            // Not a Frame at all (e.g. the Strap's console messages): logged only.
        } catch {
            output.skipped.append(.frame(error))
        }
        return output
    }

    public mutating func stop(at time: Date) -> LiveHRSessionOutput {
        var output = LiveHRSessionOutput()
        send(.liveHR(on: false), at: time, into: &output)
        isOn = false
        return output
    }

    /// Numbers `command` as hr-tracker's whoop5.py does (hello 1, on 2, off 3) and logs it.
    private mutating func send(
        _ command: Command,
        at time: Date,
        into output: inout LiveHRSessionOutput
    ) {
        let bytes: [UInt8]
        do {
            bytes = try command.frame(sequence: nextSequence)
        } catch {
            preconditionFailure("every Live HR command has a known header check: \(error)")
        }
        nextSequence &+= 1
        output.framesToSend.append(bytes)
        output.syncLog.append(SyncLogEntry(time: time, direction: .toStrap, bytes: bytes))
    }
}

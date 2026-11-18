import Foundation
import SerenixCore

/// One night's sleep as one motion series labels it (spec 019's Strap transfer run).
public struct StrapSleep: Equatable, Codable, Sendable {
    /// Minutes; 0 with no Sleep Period.
    public let timeAsleep: Double
    /// UTC; nil with no Sleep Period.
    public let sleepOnset: Date?
    /// UTC; nil with no Sleep Period.
    public let finalWake: Date?

    init(_ period: SleepPeriod?) {
        timeAsleep = (period?.timeAsleep ?? 0) / secondsPerMinute
        sleepOnset = period?.sleepOnset
        finalWake = period?.finalWake
    }
}

/// How far one of the owner's Strap nights moves when labelled with Tilt instead of the turn
/// the app uses (spec 019): the transfer gap that says what a Walch score means for the app.
public struct StrapTransferNight: Equatable, Codable, Sendable {
    public let id: String
    /// Seconds whose turn is above the app's threshold.
    public let turnActiveSeconds: Int
    /// Of those, the share whose Tilt is above the Tilt threshold; nil when there are none.
    public let alsoTiltActiveShare: Double?
    /// Of the minutes with data, the share where turn and Tilt agree on whether the minute is
    /// active (≥ 10 active seconds); nil when no minute has data.
    public let agreeingMinuteShare: Double?
    /// Labelled with the turn at the app's threshold.
    public let turn: StrapSleep
    /// Labelled with Tilt at the run's threshold.
    public let tilt: StrapSleep
    /// Minutes, Tilt minus turn.
    public let timeAsleepDifference: Double
    /// Minutes, Tilt minus turn; nil when either series has no Sleep Period.
    public let sleepOnsetDifference: Double?
    /// Minutes, Tilt minus turn; nil when either series has no Sleep Period.
    public let finalWakeDifference: Double?
}

/// The Strap transfer run's report (spec 019): written as Markdown to read and JSON to compare.
public struct StrapTransferReport: Equatable, Codable, Sendable {
    /// Its thresholds are `[threshold]`.
    public let stamp: RunStamp
    /// Degrees: the Tilt threshold. The turn is always labelled at the app's.
    public let threshold: Double
    /// In input order.
    public let nights: [StrapTransferNight]

    /// Compares each night's turn and Tilt series. Each night's records must be oldest first,
    /// without repeats.
    public static func compare(
        _ nights: [(id: String, records: [HistoryRecord])],
        tiltThreshold: Double,
        stamp: RunStamp
    ) -> StrapTransferReport {
        var stamp = stamp
        stamp.thresholds = [tiltThreshold]
        return StrapTransferReport(
            stamp: stamp,
            threshold: tiltThreshold,
            nights: nights.map {
                night(id: $0.id, records: $0.records, tiltThreshold: tiltThreshold)
            }
        )
    }

    private static func night(id: String, records: [HistoryRecord], tiltThreshold: Double)
        -> StrapTransferNight
    {
        let appThreshold = SleepWakeLabeller.appThreshold
        let turnInput = SleepWakeLabeller.input(from: records, angle: .turn)
        let tiltInput = SleepWakeLabeller.input(from: records, angle: .tilt)
        var turnActive = 0
        var alsoTiltActive = 0
        var minutes: [Int: (seconds: Int, turnActive: Int, tiltActive: Int)] = [:]
        for (turnSecond, tiltSecond) in zip(turnInput, tiltInput) {
            let isTurnActive = (turnSecond.angle ?? 0) > appThreshold
            let isTiltActive = (tiltSecond.angle ?? 0) > tiltThreshold
            if isTurnActive {
                turnActive += 1
                if isTiltActive { alsoTiltActive += 1 }
            }
            let since1970 = turnSecond.time.timeIntervalSince1970
            let minute = Int((since1970 / secondsPerMinute).rounded(.down))
            minutes[minute, default: (0, 0, 0)].seconds += 1
            if isTurnActive { minutes[minute, default: (0, 0, 0)].turnActive += 1 }
            if isTiltActive { minutes[minute, default: (0, 0, 0)].tiltActive += 1 }
        }
        let withData = minutes.values.filter { $0.seconds >= fewestSecondsPerMinute }
        let agreeing = withData.filter {
            ($0.turnActive >= activeMinuteSeconds) == ($0.tiltActive >= activeMinuteSeconds)
        }
        let turn = StrapSleep(
            SleepWakeLabeller.label(turnInput, activeAboveDegrees: appThreshold).sleepPeriod
        )
        let tilt = StrapSleep(
            SleepWakeLabeller.label(tiltInput, activeAboveDegrees: tiltThreshold).sleepPeriod
        )
        return StrapTransferNight(
            id: id,
            turnActiveSeconds: turnActive,
            alsoTiltActiveShare: turnActive == 0
                ? nil : Double(alsoTiltActive) / Double(turnActive),
            agreeingMinuteShare: withData.isEmpty
                ? nil : Double(agreeing.count) / Double(withData.count),
            turn: turn,
            tilt: tilt,
            timeAsleepDifference: tilt.timeAsleep - turn.timeAsleep,
            sleepOnsetDifference: minutesBetween(turn.sleepOnset, tilt.sleepOnset),
            finalWakeDifference: minutesBetween(turn.finalWake, tilt.finalWake)
        )
    }

    /// The report as JSON, keys sorted so two runs diff cleanly.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// The report as Markdown: the stamp, then one row per night. Times are UTC; minutes to 1
    /// decimal, shares as whole percents.
    public func markdown() -> String {
        let time = ISO8601DateFormatter()
        func clock(_ date: Date?) -> String { date.map { time.string(from: $0) } ?? "—" }
        var lines = [
            "# Strap transfer: turn vs Tilt",
            "",
            "- Labeller: \(stamp.labeller)",
            "- Tilt threshold: \(degrees(threshold)) (turn at "
                + "\(degrees(SleepWakeLabeller.appThreshold)))",
            "- Dataset: \(stamp.dataset)",
            "- Command line: `\(stamp.commandLine)`",
            "- Git SHA: \(stamp.gitSHA)",
            "",
            "## Nights",
            "",
            "| Night | Turn-active seconds | Also Tilt-active | Minutes agreeing "
                + "| Time Asleep (min), turn / Tilt / diff "
                + "| Sleep Onset, turn / Tilt / diff (min) "
                + "| Final Wake, turn / Tilt / diff (min) |",
            "|---|---|---|---|---|---|---|",
        ]
        for night in nights {
            let cells = [
                cell(night.id),
                "\(night.turnActiveSeconds)",
                percent(night.alsoTiltActiveShare),
                percent(night.agreeingMinuteShare),
                "\(minutes(night.turn.timeAsleep)) / \(minutes(night.tilt.timeAsleep)) / "
                    + minutes(night.timeAsleepDifference),
                "\(clock(night.turn.sleepOnset)) / \(clock(night.tilt.sleepOnset)) / "
                    + minutes(night.sleepOnsetDifference),
                "\(clock(night.turn.finalWake)) / \(clock(night.tilt.finalWake)) / "
                    + minutes(night.finalWakeDifference),
            ]
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Seconds a minute needs to have data (spec 003's rule, `MotionMinutes.fewestRecordsPerMinute`).
private let fewestSecondsPerMinute = 30
/// Active seconds that make a minute active: spec 003's wake-minute test (sleep.py `WAKE_ACTIVE`),
/// as the Walch-motion research note compared minutes.
private let activeMinuteSeconds = 10

/// Minutes from `turn` to `tilt`; nil when either is missing.
private func minutesBetween(_ turn: Date?, _ tilt: Date?) -> Double? {
    guard let turn, let tilt else { return nil }
    return tilt.timeIntervalSince(turn) / secondsPerMinute
}

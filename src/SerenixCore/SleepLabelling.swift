import Foundation

/// One second of input to sleep/wake labelling (spec 019): what the labeller needs from any
/// source, whether the Strap's History Records or a sleep-lab dataset.
public struct LabellingSecond: Equatable, Sendable {
    /// UTC.
    public var time: Date
    /// bpm; nil when the second has none.
    public var heartRate: Double?
    /// Degrees the wrist moved since the second before; nil when there is no second before to
    /// compare with. The app uses the Strap's turn, a sleep-lab dataset uses Tilt.
    public var angle: Double?

    public init(time: Date, heartRate: Double?, angle: Double?) {
        self.time = time
        self.heartRate = heartRate
        self.angle = angle
    }
}

/// A minute's sleep/wake label.
public enum MinuteLabel: Equatable, Sendable {
    case sleep
    case wake
}

/// One UTC minute and its label.
public struct LabelledMinute: Equatable, Sendable {
    /// UTC: a whole minute.
    public let start: Date
    /// Nil when the minute has no data (too few seconds).
    public let label: MinuteLabel?
}

/// What sleep/wake labelling found in some labelling input.
public struct SleepLabelling: Equatable, Sendable {
    /// Every UTC minute from the first second's to the last's, oldest first.
    public let minutes: [LabelledMinute]
    /// The main Sleep Period, nil when no run of sleep minutes is long enough to start one.
    public let sleepPeriod: SleepPeriod?
}

/// Serenix's sleep/wake labelling (spec 003's rule), on per-second input (spec 019).
public enum SleepWakeLabeller {
    /// Degrees: the threshold the app labels at (spec 003).
    public static let appThreshold = MotionMinutes.activeDegrees

    /// The app's labelling input: each History Record's heart rate (0 bpm included), and the
    /// Strap's turn since the record before (nil unless that record is more than 0 and at most
    /// `MotionMinutes.longestActiveGap` seconds earlier). `records` must be oldest first, without
    /// repeats.
    public static func input(from records: [HistoryRecord]) -> [LabellingSecond] {
        zip(records, MotionMinutes.turns(in: records)).map { record, turn in
            LabellingSecond(
                time: record.timestamp,
                heartRate: Double(record.heartRate),
                angle: turn
            )
        }
    }
}

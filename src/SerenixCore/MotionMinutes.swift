import Foundation

/// History Records taken a UTC minute at a time: the minute a record falls in and the fewest
/// records a minute needs, shared by the Sleep Period and Resting HR, and how far the Strap
/// turned each second (spec 003's motion, used by the Sleep Period). Constants from hr-tracker
/// `tools/sleep.py`, which set them by eye on two nights.
enum MotionMinutes {
    /// Degrees the Strap must turn in one second for that second to count as active (resting
    /// noise is ~0.2°). sleep.py `ACTIVE_DEG`. The app's labelling threshold.
    static let activeDegrees = 2.0
    /// Seconds: the longest gap between two records whose turn still counts. sleep.py
    /// `minutes()`.
    static let longestActiveGap = 2.0
    /// Records a minute needs to count; fewer means off-wrist or not recorded. Not used here:
    /// kept beside the active-second rule for every caller that bins minutes. sleep.py
    /// `MIN_SAMPLES`.
    static let fewestRecordsPerMinute = 30
    /// Seconds in a minute, for minute starts.
    static let secondsPerMinute = 60.0

    /// The UTC minute `time` (Unix seconds) falls in, counted from the Unix epoch.
    static func minuteIndex(_ time: TimeInterval) -> Int {
        Int((time / secondsPerMinute).rounded(.down))
    }

    /// Degrees the Strap turned at each record since the record before it, in order; nil unless
    /// the record before is more than 0 and at most `longestActiveGap` seconds earlier (so always
    /// nil for the first record). `records` must be oldest first, without repeats.
    /// sleep.py `minutes()`.
    static func turns(in records: [HistoryRecord]) -> [Double?] {
        var turns: [Double?] = []
        var previous: (time: TimeInterval, motion: [Double])?
        for record in records {
            let time = record.timestamp.timeIntervalSince1970
            let motion = normalised(record.motion)
            if let previous, time - previous.time > 0, time - previous.time <= longestActiveGap {
                turns.append(turn(from: previous.motion, to: motion))
            } else {
                turns.append(nil)
            }
            previous = (time, motion)
        }
        return turns
    }

    /// The four motion values scaled to unit length (left as they are when all are 0).
    private static func normalised(_ motion: [Float]) -> [Double] {
        let values = motion.map(Double.init)
        let length = values.map { $0 * $0 }.reduce(0, +).squareRoot()
        return values.map { $0 / (length == 0 ? 1 : length) }
    }

    /// Degrees turned between two unit quaternions: 2·acos(|q₁·q₂|).
    private static func turn(from previous: [Double], to current: [Double]) -> Double {
        let dot = min(1, abs(zip(current, previous).map { $0 * $1 }.reduce(0, +)))
        return 2 * acos(dot) * 180 / .pi
    }
}

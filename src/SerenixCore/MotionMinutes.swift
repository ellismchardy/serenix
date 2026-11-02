import Foundation

/// History Records taken a UTC minute at a time, with how many seconds of each minute the Strap
/// turned in: spec 003's rule, shared by the Sleep Period and anything else that needs to know
/// when the user was moving. Constants from hr-tracker `tools/sleep.py`, which set them by eye on
/// two nights.
enum MotionMinutes {
    /// Degrees the Strap must turn in one second for that second to count as active (resting
    /// noise is ~0.2°). sleep.py `ACTIVE_DEG`.
    static let activeDegrees = 2.0
    /// Seconds: the longest gap between two records whose turn still counts. sleep.py
    /// `minutes()`.
    static let longestActiveGap = 2.0
    /// Active seconds in one minute that alone make it a wake minute, and so never a still one.
    /// sleep.py `WAKE_ACTIVE`.
    static let wakeActiveSeconds = 10
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

    /// Active seconds in each minute (by `minuteIndex`) that has any; minutes without are left
    /// out. A record is active when the Strap turned more than `activeDegrees` since the record
    /// before it, at most `longestActiveGap` seconds earlier. `records` must be oldest first,
    /// without repeats. sleep.py `minutes()`.
    static func activeSeconds(in records: [HistoryRecord]) -> [Int: Int] {
        var activeSeconds: [Int: Int] = [:]
        var previous: (time: TimeInterval, motion: [Double])?
        for record in records {
            let time = record.timestamp.timeIntervalSince1970
            let motion = normalised(record.motion)
            if let previous, time - previous.time > 0, time - previous.time <= longestActiveGap,
                turn(from: previous.motion, to: motion) > activeDegrees
            {
                activeSeconds[minuteIndex(time), default: 0] += 1
            }
            previous = (time, motion)
        }
        return activeSeconds
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

import Foundation

/// History Records taken a UTC minute at a time: the minute a record falls in and the fewest
/// records a minute needs, shared by the Sleep Period and Resting HR, and the motion angle at
/// each record (spec 003's turn, or spec 019's Tilt), used by the Sleep Period. Constants from
/// hr-tracker `tools/sleep.py`, which set them by eye on two nights.
enum MotionMinutes {
    /// Degrees the Strap must turn in one second for that second to count as active (resting
    /// noise is ~0.2°). sleep.py `ACTIVE_DEG`. The app's labelling threshold.
    static let activeDegrees = 2.0
    /// Seconds: the longest gap between two records whose motion angle (turn or Tilt) still
    /// counts. sleep.py `minutes()`.
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

    /// The motion angle in degrees at each record since the record before it, in order: the
    /// Strap's turn or its Tilt, as `angle` says. Nil unless the record before is more than 0 and
    /// at most `longestActiveGap` seconds earlier (so always nil for the first record). `records`
    /// must be oldest first, without repeats. sleep.py `minutes()`.
    static func angles(in records: [HistoryRecord], as angle: MotionAngle) -> [Double?] {
        var angles: [Double?] = []
        var previous: (time: TimeInterval, motion: [Float])?
        for record in records {
            let time = record.timestamp.timeIntervalSince1970
            if let previous, time - previous.time > 0, time - previous.time <= longestActiveGap {
                let (before, now) = (previous.motion, record.motion)
                switch angle {
                case .turn: angles.append(StrapMotion.turn(from: before, to: now))
                case .tilt: angles.append(StrapMotion.tilt(from: before, to: now))
                }
            } else {
                angles.append(nil)
            }
            previous = (time, record.motion)
        }
        return angles
    }
}

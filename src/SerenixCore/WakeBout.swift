import Foundation

/// One unbroken stretch of wake inside a Sleep Period, between Sleep Onset and Final Wake
/// (GLOSSARY, spec 011).
public struct WakeBout: Equatable, Codable, Sendable {
    /// UTC: its first wake minute.
    public let start: Date
    /// How many whole minutes it lasted.
    public let minutes: Int

    public init(start: Date, minutes: Int) {
        self.start = start
        self.minutes = minutes
    }

    /// Each run of minutes not asleep, oldest first, where `minuteIsAsleep[i]` is the minute
    /// starting `i` minutes after `sleepOnset`. Their minutes add up to the minutes not asleep.
    static func bouts(in minuteIsAsleep: [Bool], from sleepOnset: Date) -> [WakeBout] {
        var bouts: [WakeBout] = []
        var runStart: Int?
        func closeRun(at end: Int) {
            guard let start = runStart else { return }
            let offset = Double(start) * MotionMinutes.secondsPerMinute
            bouts.append(WakeBout(start: sleepOnset + offset, minutes: end - start))
            runStart = nil
        }
        for (index, isAsleep) in minuteIsAsleep.enumerated() {
            if isAsleep {
                closeRun(at: index)
            } else if runStart == nil {
                runStart = index
            }
        }
        // A Sleep Period ends asleep, so no run is left open; closed anyway for any other input.
        closeRun(at: minuteIsAsleep.count)
        return bouts
    }
}

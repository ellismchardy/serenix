import Foundation

/// The main Sleep Period in some History Records and the Time in Bed around it, found exactly as
/// hr-tracker's `tools/sleep.py` finds them (method table: hr-tracker
/// `docs/protocol.md#sleep-and-wake`). Its quirks are kept so the two give the same numbers
/// (spec 003). Two differences no real night has shown: motion arrives as `Float` where
/// hr-tracker reads 4-decimal doubles, and records are dropped as repeats and ordered by identity
/// (timestamp, then Record Counter) where hr-tracker uses the counter alone. The rule itself works
/// on per-second labelling input (spec 019), so a sleep-lab dataset can be labelled the same way.
public struct SleepPeriod: Equatable, Sendable {
    /// UTC.
    public let sleepOnset: Date
    /// UTC.
    public let finalWake: Date
    /// UTC.
    public let timeInBedStart: Date
    /// UTC.
    public let timeInBedEnd: Date
    /// Whether each minute from Sleep Onset to Final Wake, in order, was labelled sleep (false for
    /// wake). Every minute inside a Sleep Period has data: it is runs of sleep, merged only
    /// across recorded wake.
    public let minuteIsAsleep: [Bool]
    /// Seconds: the sleep minutes inside the Sleep Period, counted from `minuteIsAsleep`.
    public var timeAsleep: TimeInterval {
        Double(minuteIsAsleep.filter { $0 }.count) * secondsPerMinute
    }
    /// Its Wake Bouts, oldest first.
    public var wakeBouts: [WakeBout] { WakeBout.bouts(in: minuteIsAsleep, from: sleepOnset) }

    /// Nil when no run of sleep minutes is long enough to start a Sleep Period. `records` must be
    /// oldest first, without repeats. Labelled with the quaternion turn at the app's threshold.
    init?(records: [HistoryRecord]) {
        let labelling = SleepWakeLabeller.label(
            SleepWakeLabeller.input(from: records),
            activeAboveDegrees: SleepWakeLabeller.appThreshold
        )
        guard let period = labelling.sleepPeriod else { return nil }
        self = period
    }

    /// The main Sleep Period of labelled minutes, nil when no run of sleep minutes is long enough.
    fileprivate init?(minutes: [Minute?], labels: [MinuteLabel?]) {
        guard let (onset, end) = mainPeriod(labels) else { return nil }
        let (bedStart, bedEnd) = timeInBed(minutes, onset: onset, end: end)
        // A Sleep Period starts and ends on a sleep minute and Time in Bed only widens over
        // minutes with data, so each end has data; anything else is a bug, never "no Night".
        guard let first = minutes[onset], let last = minutes[end - 1],
            let firstInBed = minutes[bedStart], let lastInBed = minutes[bedEnd - 1]
        else { preconditionFailure("a Sleep Period or Time in Bed ends on a minute without data") }
        sleepOnset = Date(timeIntervalSince1970: first.start)
        finalWake = Date(timeIntervalSince1970: last.start + secondsPerMinute)
        timeInBedStart = Date(timeIntervalSince1970: firstInBed.start)
        timeInBedEnd = Date(timeIntervalSince1970: lastInBed.start + secondsPerMinute)
        minuteIsAsleep = labels[onset..<end].map { $0 == .sleep }
    }
}

// Constants from hr-tracker `tools/sleep.py`, which set them by eye on two nights. The
// active-second rule and the fewest records a minute needs are in `MotionMinutes`.

/// Active seconds in one minute that alone make it a wake minute. sleep.py `WAKE_ACTIVE`.
private let wakeActiveSeconds = 10
/// Median active seconds over the 5 minutes centred on a minute that make it a wake minute.
/// sleep.py `WAKE_MEDIAN5`.
private let wakeMedianActiveSeconds = 6.0
/// Minutes either side of a minute in that median (5 minutes in all). sleep.py `classify()`.
private let wakeMedianReach = 2
/// bpm above the rolling median that keeps a wake bout going. sleep.py `HR_RAISED`.
private let raisedHeartRate = 6.0
/// Minutes either side in that rolling median (61 minutes in all). sleep.py `classify()`.
private let heartRateMedianReach = 30
/// The most minutes heart rate alone can add to a wake bout. sleep.py `HR_EXTEND_MAX`.
private let longestHeartRateExtension = 10
/// Minutes of unbroken sleep needed to start or end a Sleep Period. sleep.py `MIN_RUN`.
private let shortestSleepRun = 7
/// Minutes: wake shorter than this stays inside one Sleep Period. sleep.py `MERGE_GAP`.
private let longestMergedWake = 60
/// Active seconds in a minute of being up and about. sleep.py `UP_ACTIVE`.
private let upActiveSeconds = 30
/// Minutes in a row of being up that mean out of bed. sleep.py `UP_RUN`.
private let upMinutes = 3

/// Seconds in a minute, for minute starts and Time Asleep.
private let secondsPerMinute = MotionMinutes.secondsPerMinute

// Here rather than beside the other labeller API in SleepLabelling.swift, so the rule's minute
// table and helpers can stay private to this file.
extension SleepWakeLabeller {
    /// Each minute of `seconds` labelled sleep or wake by spec 003's rule, and the main Sleep
    /// Period. A second is active when its angle is strictly above `threshold` (degrees).
    /// `seconds` must be oldest first, without repeats.
    public static func label(
        _ seconds: [LabellingSecond],
        activeAboveDegrees threshold: Double
    ) -> SleepLabelling {
        guard let first = seconds.first else {
            return SleepLabelling(minutes: [], sleepPeriod: nil)
        }
        let minutes = minuteTable(seconds, activeAbove: threshold)
        let labels = labelled(minutes)
        let firstMinute = MotionMinutes.minuteIndex(first.time.timeIntervalSince1970)
        let labelledMinutes = labels.enumerated().map { offset, label in
            LabelledMinute(
                start: Date(
                    timeIntervalSince1970: Double(firstMinute + offset) * secondsPerMinute
                ),
                label: label
            )
        }
        return SleepLabelling(
            minutes: labelledMinutes,
            sleepPeriod: SleepPeriod(minutes: minutes, labels: labels)
        )
    }
}

/// One UTC minute that has enough seconds.
private struct Minute {
    /// Unix seconds.
    let start: TimeInterval
    /// bpm, over the minute's seconds that have a heart rate (in the app, every record, including
    /// those whose heart rate is 0, as sleep.py does); nil when none has.
    let meanHeartRate: Double?
    let activeSeconds: Int
}

/// Every UTC minute from the first second's to the last's, nil where a minute has too few
/// seconds. A second is active when its angle is above `threshold`. sleep.py `minutes()`.
private func minuteTable(_ seconds: [LabellingSecond], activeAbove threshold: Double) -> [Minute?] {
    guard let first = seconds.first, let last = seconds.last else { return [] }
    var counts: [Int: Int] = [:]
    var heartRates: [Int: (sum: Double, count: Int)] = [:]
    var activeSeconds: [Int: Int] = [:]
    for second in seconds {
        let minute = MotionMinutes.minuteIndex(second.time.timeIntervalSince1970)
        counts[minute, default: 0] += 1
        if let rate = second.heartRate {
            heartRates[minute, default: (0, 0)].sum += rate
            heartRates[minute, default: (0, 0)].count += 1
        }
        if let angle = second.angle, angle > threshold {
            activeSeconds[minute, default: 0] += 1
        }
    }
    let firstMinute = MotionMinutes.minuteIndex(first.time.timeIntervalSince1970)
    let lastMinute = MotionMinutes.minuteIndex(last.time.timeIntervalSince1970)
    return (firstMinute...lastMinute).map { minute in
        guard let count = counts[minute], count >= MotionMinutes.fewestRecordsPerMinute else {
            return nil
        }
        let rates = heartRates[minute]
        return Minute(
            start: Double(minute) * secondsPerMinute,
            meanHeartRate: rates.map { $0.sum / Double($0.count) },
            activeSeconds: activeSeconds[minute, default: 0]
        )
    }
}

/// Each minute labelled sleep or wake (nil without data). sleep.py `classify()`.
private func labelled(_ minutes: [Minute?]) -> [MinuteLabel?] {
    let active = minutes.map { $0?.activeSeconds }
    var labels: [MinuteLabel?] = active.indices.map { index in
        guard let seconds = active[index] else { return nil }
        let near = window(active, around: index, reach: wakeMedianReach).map(Double.init)
        let isWake = seconds >= wakeActiveSeconds || median(of: near) >= wakeMedianActiveSeconds
        return isWake ? .wake : .sleep
    }
    let heartRates = minutes.map { $0?.meanHeartRate }
    let rollingMedians = heartRates.indices.map { index in
        let near = window(heartRates, around: index, reach: heartRateMedianReach)
        return near.isEmpty ? nil : median(of: near)
    }
    // A wake bout led by movement runs on while heart rate stays raised.
    var index = 0
    while index < labels.count {
        guard labels[index] == .wake, index + 1 < labels.count, labels[index + 1] == .sleep else {
            index += 1
            continue
        }
        var next = index + 1
        while next < labels.count, next - index <= longestHeartRateExtension,
            labels[next] == .sleep, let rate = heartRates[next],
            let rollingMedian = rollingMedians[next], rate >= rollingMedian + raisedHeartRate
        {
            labels[next] = .wake
            next += 1
        }
        index = next
    }
    return labels
}

/// The non-nil values within `reach` places either side of `index`, in order.
private func window<Value>(_ values: [Value?], around index: Int, reach: Int) -> [Value] {
    let lower = max(0, index - reach)
    let upper = min(values.count, index + reach + 1)
    return values[lower..<upper].compactMap { $0 }
}

/// The minute range (end exclusive) of the Sleep Period with the most sleep minutes, the first
/// one on a tie, or nil. sleep.py `sleep_period()`.
private func mainPeriod(_ labels: [MinuteLabel?]) -> (onset: Int, end: Int)? {
    var runs: [(onset: Int, end: Int)] = []
    var index = 0
    while index < labels.count {
        guard labels[index] == .sleep else {
            index += 1
            continue
        }
        var end = index
        while end < labels.count, labels[end] == .sleep { end += 1 }
        if end - index >= shortestSleepRun { runs.append((index, end)) }
        index = end
    }
    var periods: [(onset: Int, end: Int)] = []
    for run in runs {
        // Merge only across recorded wake: a minute without data ends the period.
        if let last = periods.last, run.onset - last.end < longestMergedWake,
            !labels[last.end..<run.onset].contains(where: { $0 == nil })
        {
            periods[periods.count - 1].end = run.end
        } else {
            periods.append(run)
        }
    }
    var best: (onset: Int, end: Int)?
    var mostSleep = -1
    for period in periods {
        let sleep = labels[period.onset..<period.end].filter { $0 == .sleep }.count
        if sleep > mostSleep {
            best = period
            mostSleep = sleep
        }
    }
    return best
}

/// Time in Bed (minute range, end exclusive): the Sleep Period widened outward until the user
/// is up and about or the data stops. sleep.py `in_bed()`.
private func timeInBed(_ minutes: [Minute?], onset: Int, end: Int) -> (start: Int, end: Int) {
    func isUp(_ range: Range<Int>) -> Bool {
        range.allSatisfy { index in
            guard minutes.indices.contains(index), let minute = minutes[index] else {
                return false
            }
            return minute.activeSeconds >= upActiveSeconds
        }
    }
    var start = onset
    while start > 0, minutes[start - 1] != nil, !isUp((start - upMinutes)..<start) {
        start -= 1
    }
    var finish = end
    while finish < minutes.count, minutes[finish] != nil, !isUp(finish..<(finish + upMinutes)) {
        finish += 1
    }
    return (start, finish)
}

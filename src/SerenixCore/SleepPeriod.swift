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
    fileprivate init?(minutes: [Minute?], labels: [MinuteLabel?], settings: LabellerSettings) {
        guard let (onset, end) = mainPeriod(labels, settings) else { return nil }
        let (bedStart, bedEnd) = timeInBed(minutes, onset: onset, end: end, settings)
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

/// PROTOTYPE (prototype/sleep-wake-candidates, #83): every constant of spec 003's rule, plus
/// switches for the candidate changes. The defaults are spec 003's rule exactly.
public struct LabellerSettings: Sendable, CustomStringConvertible {
    /// Active seconds in one minute that alone make it a wake minute. sleep.py `WAKE_ACTIVE`.
    public var wakeActiveSeconds = 10
    /// Median active seconds over the 5 minutes centred on a minute. sleep.py `WAKE_MEDIAN5`.
    public var wakeMedianActiveSeconds = 6.0
    /// Minutes either side of a minute in that median. sleep.py `classify()`.
    public var wakeMedianReach = 2
    /// bpm above the rolling median that keeps a wake bout going. sleep.py `HR_RAISED`.
    public var raisedHeartRate = 6.0
    /// Minutes either side in that rolling median. sleep.py `classify()`.
    public var heartRateMedianReach = 30
    /// The most minutes heart rate alone can add to a wake bout. sleep.py `HR_EXTEND_MAX`.
    public var longestHeartRateExtension = 10
    /// Minutes of unbroken sleep needed to start or end a Sleep Period. sleep.py `MIN_RUN`.
    public var shortestSleepRun = 7
    /// Minutes: wake shorter than this stays inside one Sleep Period. sleep.py `MERGE_GAP`.
    public var longestMergedWake = 60
    /// Active seconds in a minute of being up and about. sleep.py `UP_ACTIVE`.
    public var upActiveSeconds = 30
    /// Minutes in a row of being up that mean out of bed. sleep.py `UP_RUN`.
    public var upMinutes = 3

    // Candidate switches (all off by default).

    /// Webster 1982 rescoring (pyActigraphy's rules) after the heart-rate extension.
    public var websterRescoring = false
    /// Quiet wake from heart rate alone: a minute whose mean HR is at least this many bpm above
    /// its rolling median is wake, whatever the motion. Nil: off.
    public var heartRateWakeAbove: Double? = nil
    /// A minute without a heart rate counts as no data (off-wrist), not as sleep.
    public var needsHeartRate = false
    /// Minutes without data, up to this many in a row, no longer end a Sleep Period when merging.
    public var mergeAcrossMissingMinutes = 0
    /// Pick the Sleep Period with the longest span rather than the most sleep minutes.
    public var pickLongestSpan = false
    /// Per-night threshold (HDCZA-style): the active threshold becomes this multiple of the
    /// night's 10th-percentile per-second angle (over seconds with an angle above 0). Nil: off.
    public var perNightThresholdMultiple: Double? = nil
    /// van Hees-style rule: a minute is wake when any second within `vanHeesReach` minutes either
    /// side has an angle above this many degrees; replaces the active-seconds wake rule. Nil: off.
    public var vanHeesDegrees: Double? = nil
    /// Minutes either side for the van Hees-style rule (2 = 5 minutes).
    public var vanHeesReach = 2

    public init() {}

    public var description: String {
        var parts: [String] = []
        let base = LabellerSettings.defaultValues
        if wakeActiveSeconds != base.wakeActiveSeconds {
            parts.append("wakeActive=\(wakeActiveSeconds)")
        }
        if wakeMedianActiveSeconds != base.wakeMedianActiveSeconds {
            parts.append("median5=\(wakeMedianActiveSeconds)")
        }
        if raisedHeartRate != base.raisedHeartRate { parts.append("raisedHR=\(raisedHeartRate)") }
        if longestHeartRateExtension != base.longestHeartRateExtension {
            parts.append("hrExtend=\(longestHeartRateExtension)")
        }
        if shortestSleepRun != base.shortestSleepRun { parts.append("minRun=\(shortestSleepRun)") }
        if longestMergedWake != base.longestMergedWake {
            parts.append("merge=\(longestMergedWake)")
        }
        if websterRescoring { parts.append("webster") }
        if let value = heartRateWakeAbove { parts.append("hrWake=\(value)") }
        if needsHeartRate { parts.append("needsHR") }
        if mergeAcrossMissingMinutes > 0 {
            parts.append("mergeMissing=\(mergeAcrossMissingMinutes)")
        }
        if pickLongestSpan { parts.append("longestSpan") }
        if let value = perNightThresholdMultiple { parts.append("perNight×\(value)") }
        if let value = vanHeesDegrees { parts.append("vanHees>\(value)°±\(vanHeesReach)") }
        return parts.isEmpty ? "spec 003" : parts.joined(separator: " ")
    }

    static let defaultValues = LabellerSettings()
}

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
        label(seconds, activeAboveDegrees: threshold, settings: LabellerSettings())
    }

    /// PROTOTYPE: as `label(_:activeAboveDegrees:)`, with `settings`.
    public static func label(
        _ seconds: [LabellingSecond],
        activeAboveDegrees threshold: Double,
        settings: LabellerSettings
    ) -> SleepLabelling {
        guard let first = seconds.first else {
            return SleepLabelling(minutes: [], sleepPeriod: nil)
        }
        var threshold = threshold
        if let multiple = settings.perNightThresholdMultiple {
            let angles = seconds.compactMap(\.angle).filter { $0 > 0 }.sorted()
            if !angles.isEmpty { threshold = angles[angles.count / 10] * multiple }
        }
        let minutes = minuteTable(seconds, activeAbove: threshold, settings)
        let labels = labelled(minutes, settings)
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
            sleepPeriod: SleepPeriod(minutes: minutes, labels: labels, settings: settings)
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
    /// PROTOTYPE: the largest angle of any second in the minute.
    let largestAngle: Double
}

/// Every UTC minute from the first second's to the last's, nil where a minute has too few
/// seconds. A second is active when its angle is above `threshold`. sleep.py `minutes()`.
private func minuteTable(
    _ seconds: [LabellingSecond],
    activeAbove threshold: Double,
    _ settings: LabellerSettings
) -> [Minute?] {
    guard let first = seconds.first, let last = seconds.last else { return [] }
    var counts: [Int: Int] = [:]
    var heartRates: [Int: (sum: Double, count: Int)] = [:]
    var activeSeconds: [Int: Int] = [:]
    var largest: [Int: Double] = [:]
    for second in seconds {
        let minute = MotionMinutes.minuteIndex(second.time.timeIntervalSince1970)
        counts[minute, default: 0] += 1
        if let rate = second.heartRate, !settings.needsHeartRate || rate > 0 {
            heartRates[minute, default: (0, 0)].sum += rate
            heartRates[minute, default: (0, 0)].count += 1
        }
        if let angle = second.angle {
            largest[minute] = max(largest[minute] ?? 0, angle)
            if angle > threshold { activeSeconds[minute, default: 0] += 1 }
        }
    }
    let firstMinute = MotionMinutes.minuteIndex(first.time.timeIntervalSince1970)
    let lastMinute = MotionMinutes.minuteIndex(last.time.timeIntervalSince1970)
    return (firstMinute...lastMinute).map { minute in
        guard let count = counts[minute], count >= MotionMinutes.fewestRecordsPerMinute else {
            return nil
        }
        let rates = heartRates[minute]
        if settings.needsHeartRate, (rates?.count ?? 0) < MotionMinutes.fewestRecordsPerMinute {
            return nil
        }
        return Minute(
            start: Double(minute) * secondsPerMinute,
            meanHeartRate: rates.map { $0.sum / Double($0.count) },
            activeSeconds: activeSeconds[minute, default: 0],
            largestAngle: largest[minute] ?? 0
        )
    }
}

/// Each minute labelled sleep or wake (nil without data). sleep.py `classify()`.
private func labelled(_ minutes: [Minute?], _ settings: LabellerSettings) -> [MinuteLabel?] {
    let active = minutes.map { $0?.activeSeconds }
    let largest = minutes.map { $0?.largestAngle }
    var labels: [MinuteLabel?] = active.indices.map { index in
        guard let seconds = active[index] else { return nil }
        if let degrees = settings.vanHeesDegrees {
            let near = window(largest, around: index, reach: settings.vanHeesReach)
            return near.contains { $0 > degrees } ? .wake : .sleep
        }
        let near = window(active, around: index, reach: settings.wakeMedianReach).map(Double.init)
        let isWake =
            seconds >= settings.wakeActiveSeconds
            || median(of: near) >= settings.wakeMedianActiveSeconds
        return isWake ? .wake : .sleep
    }
    let heartRates = minutes.map { $0?.meanHeartRate }
    let rollingMedians = heartRates.indices.map { index in
        let near = window(heartRates, around: index, reach: settings.heartRateMedianReach)
        return near.isEmpty ? nil : median(of: near)
    }
    if let above = settings.heartRateWakeAbove {
        for index in labels.indices where labels[index] == .sleep {
            if let rate = heartRates[index], let rollingMedian = rollingMedians[index],
                rate >= rollingMedian + above
            {
                labels[index] = .wake
            }
        }
    }
    // A wake bout led by movement runs on while heart rate stays raised.
    var index = 0
    while index < labels.count {
        guard labels[index] == .wake, index + 1 < labels.count, labels[index + 1] == .sleep else {
            index += 1
            continue
        }
        var next = index + 1
        while next < labels.count, next - index <= settings.longestHeartRateExtension,
            labels[next] == .sleep, let rate = heartRates[next],
            let rollingMedian = rollingMedians[next],
            rate >= rollingMedian + settings.raisedHeartRate
        {
            labels[next] = .wake
            next += 1
        }
        index = next
    }
    if settings.websterRescoring { labels = webster(labels) }
    return labels
}

/// PROTOTYPE: Webster 1982 rescoring as pyActigraphy gives it. Minutes without data are left as
/// they are and break runs.
private func webster(_ labels: [MinuteLabel?]) -> [MinuteLabel?] {
    var out = labels
    // After ≥ 4 / 10 / 15 min of wake, the next 1 / 3 / 4 min of sleep become wake.
    var wakeRun = 0
    var index = 0
    while index < out.count {
        if out[index] == .wake {
            wakeRun += 1
            index += 1
            continue
        }
        if out[index] == nil {
            wakeRun = 0
            index += 1
            continue
        }
        let rescore = wakeRun >= 15 ? 4 : wakeRun >= 10 ? 3 : wakeRun >= 4 ? 1 : 0
        var changed = 0
        while changed < rescore, index < out.count, out[index] == .sleep {
            out[index] = .wake
            changed += 1
            index += 1
        }
        wakeRun = 0
        if changed == 0 { index += 1 }
    }
    // A run of sleep ≤ 6 (≤ 10) min with ≥ 15 (≥ 20) min of wake on both sides becomes wake.
    func runs(_ values: [MinuteLabel?]) -> [(label: MinuteLabel?, start: Int, end: Int)] {
        var result: [(MinuteLabel?, Int, Int)] = []
        var start = 0
        for position in 1...values.count {
            if position == values.count || values[position] != values[start] {
                result.append((values[start], start, position))
                start = position
            }
        }
        return result
    }
    guard !out.isEmpty else { return out }
    let pieces = runs(out)
    for (offset, piece) in pieces.enumerated() where piece.label == .sleep {
        guard offset > 0, offset + 1 < pieces.count else { continue }
        let before = pieces[offset - 1]
        let after = pieces[offset + 1]
        guard before.label == .wake, after.label == .wake else { continue }
        let length = piece.end - piece.start
        let wakeBefore = before.end - before.start
        let wakeAfter = after.end - after.start
        if (length <= 6 && wakeBefore >= 15 && wakeAfter >= 15)
            || (length <= 10 && wakeBefore >= 20 && wakeAfter >= 20)
        {
            for position in piece.start..<piece.end { out[position] = .wake }
        }
    }
    return out
}

/// The non-nil values within `reach` places either side of `index`, in order.
private func window<Value>(_ values: [Value?], around index: Int, reach: Int) -> [Value] {
    let lower = max(0, index - reach)
    let upper = min(values.count, index + reach + 1)
    return values[lower..<upper].compactMap { $0 }
}

/// The minute range (end exclusive) of the Sleep Period with the most sleep minutes, the first
/// one on a tie, or nil. sleep.py `sleep_period()`.
private func mainPeriod(_ labels: [MinuteLabel?], _ settings: LabellerSettings)
    -> (onset: Int, end: Int)?
{
    var runs: [(onset: Int, end: Int)] = []
    var index = 0
    while index < labels.count {
        guard labels[index] == .sleep else {
            index += 1
            continue
        }
        var end = index
        while end < labels.count, labels[end] == .sleep { end += 1 }
        if end - index >= settings.shortestSleepRun { runs.append((index, end)) }
        index = end
    }
    var periods: [(onset: Int, end: Int)] = []
    for run in runs {
        // Merge only across recorded wake: a minute without data ends the period.
        if let last = periods.last, run.onset - last.end < settings.longestMergedWake,
            longestMissingRun(labels[last.end..<run.onset]) <= settings.mergeAcrossMissingMinutes
        {
            periods[periods.count - 1].end = run.end
        } else {
            periods.append(run)
        }
    }
    var best: (onset: Int, end: Int)?
    var mostSleep = -1
    for period in periods {
        let sleep =
            settings.pickLongestSpan
            ? period.end - period.onset
            : labels[period.onset..<period.end].filter { $0 == .sleep }.count
        if sleep > mostSleep {
            best = period
            mostSleep = sleep
        }
    }
    return best
}

/// PROTOTYPE: the longest run of minutes without data in `labels`.
private func longestMissingRun(_ labels: ArraySlice<MinuteLabel?>) -> Int {
    var longest = 0
    var run = 0
    for label in labels {
        if label == nil {
            run += 1
            longest = max(longest, run)
        } else {
            run = 0
        }
    }
    return longest
}

/// Time in Bed (minute range, end exclusive): the Sleep Period widened outward until the user
/// is up and about or the data stops. sleep.py `in_bed()`.
private func timeInBed(
    _ minutes: [Minute?],
    onset: Int,
    end: Int,
    _ settings: LabellerSettings
) -> (start: Int, end: Int) {
    func isUp(_ range: Range<Int>) -> Bool {
        range.allSatisfy { index in
            guard minutes.indices.contains(index), let minute = minutes[index] else {
                return false
            }
            return minute.activeSeconds >= settings.upActiveSeconds
        }
    }
    var start = onset
    while start > 0, minutes[start - 1] != nil, !isUp((start - settings.upMinutes)..<start) {
        start -= 1
    }
    var finish = end
    while finish < minutes.count, minutes[finish] != nil,
        !isUp(finish..<(finish + settings.upMinutes))
    {
        finish += 1
    }
    return (start, finish)
}

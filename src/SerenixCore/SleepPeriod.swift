import Foundation

/// The main Sleep Period in some History Records and the Time in Bed around it, found exactly as
/// hr-tracker's `tools/sleep.py` finds them (method table: hr-tracker
/// `docs/protocol.md#sleep-and-wake`). Its quirks are kept so the two give the same numbers
/// (spec 003). Two differences no real night has shown: motion arrives as `Float` where
/// hr-tracker reads 4-decimal doubles, and records are dropped as repeats and ordered by identity
/// (timestamp, then Record Counter) where hr-tracker uses the counter alone.
struct SleepPeriod: Equatable, Sendable {
    /// UTC.
    var sleepOnset: Date
    /// UTC.
    var finalWake: Date
    /// UTC.
    var timeInBedStart: Date
    /// UTC.
    var timeInBedEnd: Date
    /// Whether each minute from Sleep Onset to Final Wake, in order, was labelled sleep (false for
    /// wake). Every minute inside a Sleep Period has data: it is runs of sleep, merged only
    /// across recorded wake.
    var minuteIsAsleep: [Bool]
    /// Seconds: the sleep minutes inside the Sleep Period, counted from `minuteIsAsleep`.
    var timeAsleep: TimeInterval { Double(minuteIsAsleep.filter { $0 }.count) * secondsPerMinute }

    /// Nil when no run of sleep minutes is long enough to start a Sleep Period. `records` must be
    /// oldest first, without repeats.
    init?(records: [HistoryRecord]) {
        let minutes = minuteTable(records)
        let labels = labelled(minutes)
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

/// One UTC minute that has enough records.
private struct Minute {
    /// Unix seconds.
    let start: TimeInterval
    /// bpm, including records whose heart rate is 0, as sleep.py does.
    let meanHeartRate: Double
    let activeSeconds: Int
}

private enum Label: Equatable {
    case sleep
    case wake
}

/// Every UTC minute from the first record's to the last's, nil where a minute has too few
/// records. sleep.py `minutes()`.
private func minuteTable(_ records: [HistoryRecord]) -> [Minute?] {
    guard let first = records.first, let last = records.last else { return [] }
    var heartRates: [Int: [Int]] = [:]
    for record in records {
        let minute = MotionMinutes.minuteIndex(record.timestamp.timeIntervalSince1970)
        heartRates[minute, default: []].append(record.heartRate)
    }
    let activeSeconds = MotionMinutes.activeSeconds(in: records)
    let firstMinute = MotionMinutes.minuteIndex(first.timestamp.timeIntervalSince1970)
    let lastMinute = MotionMinutes.minuteIndex(last.timestamp.timeIntervalSince1970)
    return (firstMinute...lastMinute).map { minute in
        guard let rates = heartRates[minute], rates.count >= MotionMinutes.fewestRecordsPerMinute
        else {
            return nil
        }
        return Minute(
            start: Double(minute) * secondsPerMinute,
            meanHeartRate: Double(rates.reduce(0, +)) / Double(rates.count),
            activeSeconds: activeSeconds[minute, default: 0]
        )
    }
}

/// Each minute labelled sleep or wake (nil without data). sleep.py `classify()`.
private func labelled(_ minutes: [Minute?]) -> [Label?] {
    let active = minutes.map { $0?.activeSeconds }
    var labels: [Label?] = active.indices.map { index in
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
private func mainPeriod(_ labels: [Label?]) -> (onset: Int, end: Int)? {
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

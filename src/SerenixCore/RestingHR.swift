import Foundation

/// The Resting HR of `day` (spec 007), bpm: the lowest mean heart rate over 5 settled still
/// minutes, or nil when there's no settled window. Only records from the Day's local midnight to
/// the next local midnight count; their order and any repeats don't matter.
public func restingHR(
    of day: Day,
    records: [HistoryRecord],
    nights: [Night],
    in timeZone: TimeZone
) -> Double? {
    let span = day.span(in: timeZone)
    var seen = Set<String>()
    let unique =
        records
        .filter {
            span.start <= $0.timestamp && $0.timestamp < span.end
                && seen.insert($0.identity).inserted
        }
        .sorted { ($0.timestamp, $0.recordCounter) < ($1.timestamp, $1.recordCounter) }
    let still = RestingHRMethod.stillMinutes(in: unique)
    return RestingHRMethod.stillRuns(among: still.keys)
        .flatMap { RestingHRMethod.settledWindows(of: $0) }
        .map { window in
            let heartRates = window.flatMap { still[$0, default: []] }
            return Double(heartRates.reduce(0, +)) / Double(heartRates.count)
        }
        .min()
}

/// The pieces of Resting HR's method (spec 007; docs/research/awake-resting-hr.md).
enum RestingHRMethod {
    /// Still minutes at the start of a still run that let heart rate settle (Speed et al. 2023;
    /// docs/research/awake-resting-hr.md, Answer).
    static let settlingMinutes = 4
    /// Minutes in a settled window (Polar's span; docs/research/awake-resting-hr.md, Answer).
    static let windowMinutes = 5
    /// The last minute of a still run a settled window may reach; after it the user may have
    /// fallen asleep (spec 007, Settled window).
    static let lastWindowMinute = 15

    /// The heart rates above 0 of each still minute (by `MotionMinutes.minuteIndex`): a minute
    /// with at least `MotionMinutes.fewestRecordsPerMinute` of them, no step and fewer than
    /// `MotionMinutes.wakeActiveSeconds` active seconds (docs/research/awake-resting-hr.md,
    /// Answer). A step is a record whose step count is above the previous record's; a drop is a
    /// Strap reboot, not a step. The first record has none before it, so it's no step; after a
    /// gap, steps taken in it count against the first minute after. `records` must be oldest
    /// first, without repeats.
    static func stillMinutes(in records: [HistoryRecord]) -> [Int: [Int]] {
        let activeSeconds = MotionMinutes.activeSeconds(in: records)
        var heartRates: [Int: [Int]] = [:]
        var stepped = Set<Int>()
        var previousSteps: Int?
        for record in records {
            let minute = MotionMinutes.minuteIndex(record.timestamp.timeIntervalSince1970)
            if record.heartRate > 0 { heartRates[minute, default: []].append(record.heartRate) }
            if let previousSteps, record.steps > previousSteps { stepped.insert(minute) }
            previousSteps = record.steps
        }
        return heartRates.filter { minute, rates in
            rates.count >= MotionMinutes.fewestRecordsPerMinute && !stepped.contains(minute)
                && activeSeconds[minute, default: 0] < MotionMinutes.wakeActiveSeconds
        }
    }

    /// Runs of consecutive minutes, oldest first.
    static func stillRuns(among minutes: some Collection<Int>) -> [[Int]] {
        var runs: [[Int]] = []
        for minute in minutes.sorted() {
            if let last = runs.last?.last, last + 1 == minute {
                runs[runs.count - 1].append(minute)
            } else {
                runs.append([minute])
            }
        }
        return runs
    }

    /// Every `windowMinutes` consecutive minutes of `run` after its first `settlingMinutes` and
    /// within its first `lastWindowMinute`.
    static func settledWindows(of run: [Int]) -> [ArraySlice<Int>] {
        let usable = run.prefix(lastWindowMinute).dropFirst(settlingMinutes)
        guard usable.count >= windowMinutes else { return [] }
        return (usable.startIndex...(usable.endIndex - windowMinutes)).map {
            usable[$0..<($0 + windowMinutes)]
        }
    }
}

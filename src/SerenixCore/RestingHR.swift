import Foundation

/// The Resting HR of `day` (spec 007), bpm: the lowest mean heart rate over 5 settled still
/// minutes. Only records from the Day's local midnight to the next local midnight count, leaving
/// out those inside any Night's Sleep Period; their order and any repeats don't matter. Nil when
/// the rest have fewer than 480 worn minutes, or no settled window.
public func restingHR(
    of day: Day,
    records: [HistoryRecord],
    nights: [Night],
    in timeZone: TimeZone
) -> Double? {
    // A Night without a Sleep Period, or with one that ends before it starts, holds no record.
    let sleepPeriods = nights.compactMap { night -> Range<Date>? in
        guard let onset = night.sleepOnset, let wake = night.finalWake, onset < wake else {
            return nil
        }
        return onset..<wake
    }
    let unique = records.unique(in: day.span(in: timeZone))
        .filter { record in !sleepPeriods.contains { $0.contains(record.timestamp) } }
        .sorted { ($0.timestamp, $0.recordCounter) < ($1.timestamp, $1.recordCounter) }
    let worn = RestingHRMethod.wornMinutes(in: unique)
    guard worn.count >= RestingHRMethod.fewestWornMinutes else { return nil }
    let still = RestingHRMethod.stillMinutes(in: unique, worn: worn)
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
    /// Worn minutes a Day needs outside Sleep Periods to have a Resting HR: 8 hours (Speed et al.
    /// 2023's daytime wear; docs/research/awake-resting-hr.md, Answer).
    static let fewestWornMinutes = 480

    /// The heart rates above 0 of each worn minute (by `MotionMinutes.minuteIndex`): a minute with
    /// at least `MotionMinutes.fewestRecordsPerMinute` of them.
    static func wornMinutes(in records: [HistoryRecord]) -> [Int: [Int]] {
        var heartRates: [Int: [Int]] = [:]
        for record in records where record.heartRate > 0 {
            let minute = MotionMinutes.minuteIndex(record.timestamp.timeIntervalSince1970)
            heartRates[minute, default: []].append(record.heartRate)
        }
        return heartRates.filter { $0.value.count >= MotionMinutes.fewestRecordsPerMinute }
    }

    /// The `worn` minutes of `records` with no step. Wrist movement doesn't count: at a desk the
    /// Strap turns in most seconds of every minute (spec 007, Notes). A step is a record whose
    /// step count is above the previous record's; a drop is a Strap reboot, not a step. The first
    /// record has none before it, so it's no step; after a gap, steps taken in it count against
    /// the first minute after. `records` must be oldest first, without repeats.
    static func stillMinutes(in records: [HistoryRecord], worn: [Int: [Int]]) -> [Int: [Int]] {
        var stepped = Set<Int>()
        var previousSteps: Int?
        for record in records {
            if let previousSteps, record.steps > previousSteps {
                stepped.insert(MotionMinutes.minuteIndex(record.timestamp.timeIntervalSince1970))
            }
            previousSteps = record.steps
        }
        return worn.filter { !stepped.contains($0.key) }
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
